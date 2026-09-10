# 11 — DATABASE

**Owner:** Technical Lead (Claude)
**Approval:** CEO must approve the schema before the first production migration
is considered locked (master plan §21)
**Status:** PROPOSED

Two stores. The local SQLite database is the device's source of truth
(PD-005). The Postgres database in Supabase is the replica a signed-in user
opts into (PD-001, PD-016).

---

## 1. Shared design rules

1. **Client-generated UUIDv4 primary keys.** The same id identifies a row on
   the device and in the cloud, so migration and sync never re-key anything.
2. **`updated_at` is server-authoritative in Postgres.** Device clocks are not
   trusted for conflict resolution.
3. **Soft delete via `deleted_at`.** Tombstones exist only to propagate deletion
   (PD-021). Every read path filters `deleted_at is null`.
4. **`user_id` is denormalised onto child tables.** It costs one column and lets
   every RLS policy be a direct comparison instead of a join — cheaper to write,
   cheaper to run, much easier to prove correct.
5. **No shared content in `usage_events`.** Enforced in the database, not only
   in the client (§6).

---

## 2. Postgres — Supabase

### 2.1 `profiles`

```sql
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
```

Created by a trigger on `auth.users` insert. Holds nothing sensitive in V1.

### 2.2 `memories`

```sql
create table public.memories (
  id         uuid primary key,                       -- client-generated
  user_id    uuid not null references auth.users(id) on delete cascade,
  content    text not null,
  source_app text,                                   -- sending package, nullable
  created_at timestamptz not null default now(),     -- when the user saved it
  updated_at timestamptz not null default now(),     -- server-set, sync cursor
  deleted_at timestamptz,
  constraint memories_content_len check (char_length(content) <= 10000)
);

create index memories_user_updated_idx
  on public.memories (user_id, updated_at);

create index memories_user_created_idx
  on public.memories (user_id, created_at desc)
  where deleted_at is null;
```

Full-text search:

```sql
alter table public.memories
  add column content_tsv tsvector
  generated always as (to_tsvector('simple', content)) stored;

create index memories_content_tsv_idx
  on public.memories using gin (content_tsv);
```

`'simple'` and not `'english'`: input is Malay, English, or a mix of both. An
English stemmer would mangle Malay tokens and give worse results than no
stemming at all. Revisit only with real usage data.

### 2.3 `memory_entities`

```sql
create table public.memory_entities (
  id               uuid primary key,
  memory_id        uuid not null references public.memories(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  type             text not null check (type in ('phone','url','money','date')),
  raw_value        text not null,      -- exactly as it appeared
  normalized_value text not null,      -- see §4
  confidence       real not null check (confidence >= 0 and confidence <= 1),
  start_offset     int,
  end_offset       int,
  created_at       timestamptz not null default now()
);

create index memory_entities_memory_idx
  on public.memory_entities (memory_id);

create index memory_entities_user_value_idx
  on public.memory_entities (user_id, type, normalized_value);
```

Entities are derived data. They are re-derivable from `content`, so they are
never synced independently — they travel with their memory and are replaced
wholesale when a memory is written.

### 2.4 `reminders`

```sql
create table public.reminders (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  memory_id  uuid references public.memories(id) on delete set null,
  title      text not null,
  remind_at  timestamptz not null,
  status     text not null default 'scheduled'
             check (status in ('scheduled','fired','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index reminders_user_time_idx
  on public.reminders (user_id, remind_at)
  where deleted_at is null;
```

The cloud row is a record, not a scheduler. Firing is a local notification
(ADR-008); a reminder synced to a second device does not fire there in V1
because that device never scheduled it. **Stated as a known V1 limitation** —
raising it to Product Direction rather than silently building server push, which
ADR-007 excludes.

### 2.5 `security_scans`

```sql
create table public.security_scans (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  url        text not null,
  host       text not null,
  verdict    text not null check (verdict in ('low','caution','suspicious','high')),
  reasons    jsonb not null default '[]'::jsonb,
  provider   text,
  created_at timestamptz not null default now()
);

create index security_scans_user_created_idx
  on public.security_scans (user_id, created_at desc);
```

**PROPOSAL — 30-day retention**, purged by a scheduled job. A scan history is a
browsing history; keeping it forever creates a privacy liability with no product
value. Not synced to the device.

### 2.6 `usage_events`

```sql
create table public.usage_events (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  event       text not null check (event in (
                'onboarding_completed','share_received','entity_detected',
                'action_selected','memory_saved','reminder_created',
                'security_scan_requested','ai_fallback_used')),
  props       jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  created_at  timestamptz not null default now(),
  constraint usage_events_props_allowed check (public.usage_props_allowed(props))
);
```

The event name is an allowlist in a `check` constraint, so an unplanned event
cannot be introduced from the client without a migration.

`props` is constrained the same way — this is the database enforcing PD-022 and
the PRD §21 privacy rule, not a code review:

```sql
create or replace function public.usage_props_allowed(p jsonb)
returns boolean language sql immutable as $$
  select p is not null
     and jsonb_typeof(p) = 'object'
     and not exists (
       select 1 from jsonb_object_keys(p) k
       where k not in ('entity_type','action','risk','result','source')
     )
     and not exists (
       select 1 from jsonb_each_text(p) e
       where char_length(e.value) > 32
     );
$$;
```

Only five keys, each capped at 32 characters. Shared text, a URL, a phone
number or an amount cannot fit through this constraint even if a future bug
tries to send one. **PD-022 also means guest devices send no telemetry at all**
— there is no anonymous path to this table.

### 2.7 `updated_at` trigger

```sql
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
```

Attached before insert or update on `memories` and `reminders`. This is what
makes the sync cursor trustworthy — a client cannot backdate a row to hide it
from another device's pull.

---

## 3. Local — SQLite (Drift)

Same tables, same ids, same `deleted_at`, plus the columns that only exist on a
device.

```sql
-- memories (local)
id            TEXT PRIMARY KEY,
content       TEXT NOT NULL,
source_app    TEXT,
created_at    INTEGER NOT NULL,      -- epoch millis, UTC
updated_at    INTEGER NOT NULL,      -- local write time; server value after sync
deleted_at    INTEGER,

owner_user_id TEXT,                  -- NULL = guest-owned (§10.3 of ARCHITECTURE)
sync_status   TEXT NOT NULL          -- 'local_only' | 'pending' | 'synced'
              CHECK (sync_status IN ('local_only','pending','synced'))
```

`memory_entities` and `reminders` mirror this. `security_scans` and
`usage_events` have no local table — neither is needed offline.

### 3.1 Search

```sql
CREATE VIRTUAL TABLE memories_fts USING fts5(
  content,
  content='memories',
  content_rowid='rowid',
  tokenize='unicode61'
);
```

Kept in step with three triggers (insert, update, delete). `unicode61` for the
same reason Postgres uses `simple`.

A search runs two queries and unions the ids:

```text
1. memories_fts MATCH ?                      -> original text  (PRD §10)
2. memory_entities.normalized_value LIKE ?%  -> entity values  (PRD §10)
```

Both filtered by `deleted_at IS NULL` and by visible ownership. Ordered by
`created_at desc`. No relevance ranking in V1 — recency is what a user expects
from a memory list.

### 3.2 `sync_meta`

```sql
key TEXT PRIMARY KEY, value TEXT
```

Holds `pull_cursor`, `last_sync_at`, and `last_sync_error`. One row per key.

### 3.3 Which rows are visible

```text
signed out  ->  owner_user_id IS NULL
signed in   ->  owner_user_id IS NULL OR owner_user_id = <current uid>
```

One predicate in one repository method. That is the whole of PD-020's "unified
Memory experience" — the UI never asks where a row lives.

---

## 4. Normalized values

`normalized_value` is what search matches and what the cloud stores. Stable, so
the same entity written two ways is found by either.

| Type | Stored as | Example |
|---|---|---|
| phone | E.164 | `0123456789` → `+60123456789` |
| url | scheme + lowercased host + path | `HTTP://Example.COM/A` → `http://example.com/A` |
| money | **integer sen**, plus `MYR` | `RM1,500.00` → `150000` |
| date | ISO-8601 date | `25/09/2026` → `2026-09-25` |

Money is stored as an integer, never a float. `RM183.50` as a binary double is
not exactly 183.50, and money that fails to compare equal to itself is a bug
that surfaces months later. The master plan's conceptual JSON shows `183.50`;
that is the display form, not the storage form. **Proposed as ADR-023.**

---

## 5. Row Level Security

Every table has RLS enabled. Policies and the bypass tests that must pass are in
`12_SECURITY.md` §3 — the schema is not considered complete without them, and
per master plan §22, "RLS enabled" is not accepted as evidence.

---

## 6. Migrations

```text
supabase/migrations/
  20260101000000_initial_schema.sql
  20260101000100_rls_policies.sql
  20260101000200_usage_events_guard.sql
```

Forward-only, numbered, never edited after they have run anywhere real. The
local Drift schema has its own integer version with an explicit migration step
per bump; a schema change that touches both stores lands in one commit so the
two never drift apart.

The CEO approves this schema before the first production migration is applied.

---

## 7. Open items

- Tombstone purge window — 90 days proposed (`10_ARCHITECTURE.md` §8.1).
- `security_scans` retention — 30 days proposed (§2.5).
- Whether reminders that do not fire on a second device (§2.4) is acceptable
  for V1. Product Direction decides.
