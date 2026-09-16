# 11 — DATABASE

**Owner:** Technical Lead (Claude)
**Approval:** CEO must approve the schema before the first production migration
is considered locked (master plan §21)
**Status:** LOCKED — CEO Architecture Lock, 2026-09-10

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
  -- PD-039: identical to the local limit. char_length counts code points,
  -- as SQLite's length() does, so nothing saved on a device can fail here.
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

### 2.5 `reputation_usage` — as built at M8b

**`security_scans` was not created, and V1 does not create it.** The design
above it in earlier drafts stored a URL, a host, a verdict and a provider id per
check. That is a browsing history under another name, and M8 turned out not to
need one: the quota is the only thing the server must remember, and a quota
needs a count, not a history.

What exists instead is the smallest table that enforces PD-028's 60 per user
per day:

```sql
create table public.reputation_usage (
  user_id uuid    not null references auth.users(id) on delete cascade,
  day     date    not null,
  checks  integer not null default 0,
  primary key (user_id, day)
);
```

Three columns, and **no URL, no host, no verdict, no provider id, no timestamp
of an individual check**. Nothing here says which links a person looked at, only
how many times they asked on a given day.

- **Server-side quota enforcement only.** The count is claimed inside
  `consume_reputation_check()`, which is `service_role`-only; the app never
  reads or writes this table and has no reason to.
- **RLS is enabled with zero policies.** No client can read this table — not
  another person's row, and not their own. The Edge Function reaches it as
  `service_role`, which is outside RLS.
- **Purged on a schedule**, `tindak-purge-reputation-usage` on pg_cron, daily at
  18:30 UTC. PD-028's "`security_scans` retention 30 days" now applies to this
  quota metadata, which is all that is kept.
- **No scan history is persisted anywhere**, on the server or the device. A
  result exists for as long as the screen showing it does.
- Not synced to the device.

Evidence: `20_TEST_PLAN.md` §9.4. Migration:
`supabase/migrations/20260916000001_reputation_quota.sql`.

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

**As built at M5a, schema version 1.** Source of truth is
`mobile/lib/core/database/tindak_database.dart`; its exact shape is pinned by
`mobile/test/core/database/schema_test.dart`, so an accidental change fails a
test instead of surfacing as a migration problem on a phone.

```sql
CREATE TABLE memories (
  id             TEXT    NOT NULL PRIMARY KEY,   -- client UUIDv4
  content        TEXT    NOT NULL,               -- original text, verbatim
  intake_source  TEXT    NOT NULL,               -- 'share' | 'paste'  (PD-033)
  source_app     TEXT,                           -- never trusted
  created_at     INTEGER NOT NULL,               -- epoch ms, UTC
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER,                        -- future tombstone; unused in M5a
  owner_user_id  TEXT,                           -- NULL = guest-owned
  sync_status    TEXT    NOT NULL,               -- always 'local_only' in M5a
  CHECK (sync_status IN ('local_only', 'pending', 'synced')),
  CHECK (intake_source IN ('share', 'paste')),
  CHECK (length(id) = 36),
  CHECK (owner_user_id IS NOT NULL OR sync_status = 'local_only'),
  CHECK (updated_at >= created_at),
  CHECK (length(content) <= 10000)               -- PD-039, code points
);
CREATE INDEX memories_visible_created_idx ON memories (deleted_at, created_at);

CREATE TABLE memory_entities (
  id                TEXT    NOT NULL PRIMARY KEY,
  memory_id         TEXT    NOT NULL REFERENCES memories (id) ON DELETE CASCADE,
  type              TEXT    NOT NULL,            -- not CHECK-constrained, see below
  raw_value         TEXT    NOT NULL,            -- from normalised text
  normalized_value  TEXT    NOT NULL,            -- E.164 / lowercased-host URL
  search_value      TEXT    NOT NULL,            -- local-only, derived
  confidence        REAL    NOT NULL,
  start_offset      INTEGER NOT NULL,
  end_offset        INTEGER NOT NULL,
  created_at        INTEGER NOT NULL,
  CHECK (confidence >= 0 AND confidence <= 1),
  CHECK (start_offset >= 0 AND end_offset > start_offset)
);
CREATE INDEX memory_entities_memory_idx ON memory_entities (memory_id);
CREATE INDEX memory_entities_search_idx ON memory_entities (search_value);
```

`PRAGMA foreign_keys = ON` is set before every open; SQLite leaves it off by
default, and without it deleting a memory would orphan its searchable entities.

### 3.0.1 Decisions made at the M5a schema checkpoint

| Decision | Why |
|---|---|
| `owner_user_id IS NOT NULL OR sync_status = 'local_only'` | The database itself, not app code, guarantees a guest row can never claim to be synced (PD-016). |
| `length(content) <= 10000` | PD-039: one content contract locally and in the cloud. SQLite `length()` and Postgres `char_length()` both count code points, so the two constraints agree. The repository refuses first with a clear message; the CHECK guarantees no other path can store more. Never truncated. |
| `intake_source` column | Records which explicit path the text came by (PD-033), for M5b and analytics later. |
| `entities.type` has no CHECK | SQLite cannot alter a CHECK in place. M6 adds money and date without rebuilding the table; unknown types are skipped on read. |
| No `user_id` on local entities | Ownership follows the memory. Postgres keeps it for RLS; locally it would be a second copy to keep consistent. |
| `search_value` column on entities | See §3.1. Derived, local-only, never synced. |
| No `sync_meta` table yet | It holds only M5b state. Adding a table is a trivial migration; adding columns to populated tables is the expensive kind, and none are deferred. |
| Database in `core/database/`, not `features/memory/` | Reminders (M7) and sync (M5b) share it. |
| File in the app's private support directory | Excluded from backup and device transfer by the M1 manifest (ADR-021). |
| `onUpgrade` throws | No migration exists yet. An unknown version jump is refused rather than guessed at, because guessing with a user's only copy of their data is what a migration must never do. |

**Why schema version stays 1 after the PD-039 constraint.** The content
`CHECK` was added in the M5a decision patch, before M5a merged and before any
release. No user device has a version 1 database, so there is nothing to
migrate. A development install created from the pre-patch M5a build lacks the
database `CHECK` — the repository still enforces the limit — and should be
reinstalled. Once any build ships, every schema change bumps the version with an
explicit migration (§6).

`reminders` arrives at M7. `reputation_usage` (§2.5) and `usage_events` have no
local table — neither is needed offline, and neither is a store of user content.

### 3.1 Search — as built (proposed amendment to ADR-015, ADR-030)

FTS5 was specified. **M5a uses `LIKE` instead**, and this is recorded as a
proposed amendment rather than silently accepted:

```text
memory matches when:
  content LIKE %query%                                   original text
  OR an entity's search_value LIKE %lowercased query%    entity values
  OR (query has ≥3 digits AND search_value LIKE %digits%) numbers however typed
```

`search_value` for a phone stored as `+60123456789` is
`0123456789 60123456789`, so `012-345 6789`, `0123456789`, `+60123456789` and
`3456789` all find it. `%`, `_` and `\` in a query are escaped and literal.

Why not FTS5:

- **Phone numbers.** FTS5's `unicode61` tokeniser splits `012-345 6789` into
  three tokens. A person searching `0123456789` would find nothing.
- **Partial words.** FTS5 matches token prefixes. `LIKE` matches anywhere,
  which is what a person expects typing part of a word in Malay or English.
- **Moving parts.** FTS5 needs a virtual table and three synchronisation
  triggers, and a trigger bug silently desynchronises search from the data.
- **Scale.** A personal memory list is hundreds to low thousands of rows. A
  linear scan at that size is well under a frame.

Revisit if real users reach sizes where search is measurably slow.

Ordered by `created_at desc, id desc`. No relevance ranking — recency is what a
user expects from a memory list, and it keeps search deterministic (PD-004).

### 3.1.1 Delete — as built

A `local_only` row is removed outright; its entities go by cascade. No
tombstone is written, because a row that never left the device has no other
copy to inform. A row with any other sync status is **refused**, not hard
deleted: hard deleting a synced row would let a later sync resurrect it. That
tombstone path is M5b's work (PD-021). Every read ignores rows with
`deleted_at` set, which the schema tests verify now.

### 3.2 `sync_meta` (M5b)

```sql
key TEXT PRIMARY KEY, value TEXT
```

Holds `pull_cursor`, `last_sync_at`, and `last_sync_error`. One row per key.
Not created at M5a.

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
that is the display form, not the storage form. ADR-023.

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

- Whether reminders that do not fire on a second device (§2.4) is acceptable
  for V1. Product Direction decides — tracked as O-4 in `90_DECISIONS.md`.

Closed: tombstone purge 90 days is approved as PD-028. PD-028's 30-day scan
retention applies to `reputation_usage` (§2.5), the only M8 persistence; the
`security_scans` table it was written for was never created.
