-- TINDAK — cloud Memory schema (M5b, step 2)
--
-- Run once in the Supabase SQL Editor. Forward-only: never edit this file
-- after it has run anywhere real; add a new migration instead
-- (docs/11_DATABASE.md section 6).
--
-- Reconciled against the real M5a device schema in
-- docs/14_M5B_RECONCILIATION.md section 2.3:
--   * intake_source added (PD-033);
--   * no server-side full-text index — search is device-only (ADR-030, PD-038);
--   * entity offsets NOT NULL, matching the device;
--   * content limit identical to the device (PD-039).
--
-- Only memories and memory_entities are created. profiles, reminders,
-- security_scans and usage_events belong to later milestones and are not
-- created early.

-- ---------------------------------------------------------------------------
-- memories
-- ---------------------------------------------------------------------------

create table public.memories (
  -- Client-generated UUIDv4 from the device. Never re-keyed.
  id            uuid        primary key,
  user_id       uuid        not null references auth.users (id) on delete cascade,
  -- The user's original text, verbatim.
  content       text        not null,
  intake_source text        not null,
  source_app    text,
  -- When the user pressed Simpan on the device. Supplied by the client.
  created_at    timestamptz not null default now(),
  -- Server-set on every write by the trigger below. The sync cursor, and the
  -- only clock trusted for ordering (ADR-019).
  updated_at    timestamptz not null default now(),
  -- A tombstone (PD-021). Never shown, never restorable.
  deleted_at    timestamptz,

  -- PD-039: identical to the device. char_length counts code points, as
  -- SQLite's length() does.
  constraint memories_content_len check (char_length(content) <= 10000),
  constraint memories_intake_source check (intake_source in ('share', 'paste'))
);

create index memories_user_updated_idx
  on public.memories (user_id, updated_at);

-- ---------------------------------------------------------------------------
-- memory_entities
-- ---------------------------------------------------------------------------

create table public.memory_entities (
  id               uuid        primary key,
  memory_id        uuid        not null references public.memories (id) on delete cascade,
  -- Denormalised so every RLS policy is a direct comparison, not a join.
  user_id          uuid        not null references auth.users (id) on delete cascade,
  type             text        not null,
  raw_value        text        not null,
  normalized_value text        not null,
  confidence       real        not null,
  start_offset     integer     not null,
  end_offset       integer     not null,
  created_at       timestamptz not null default now(),

  constraint memory_entities_type check (type in ('phone', 'url', 'money', 'date')),
  constraint memory_entities_confidence check (confidence >= 0 and confidence <= 1),
  constraint memory_entities_span check (start_offset >= 0 and end_offset > start_offset)
);

create index memory_entities_memory_idx on public.memory_entities (memory_id);
create index memory_entities_user_idx on public.memory_entities (user_id);

-- ---------------------------------------------------------------------------
-- Server-authoritative timestamps and immutability
-- ---------------------------------------------------------------------------

-- On insert: the server owns updated_at, and a new row cannot arrive already
-- deleted — a memory created and deleted before it ever synced is removed on
-- the device and never sent (docs/14_M5B_RECONCILIATION.md section 2.1).
create or replace function public.memories_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.deleted_at is not null then
    raise exception 'a memory cannot be created already deleted'
      using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- On update: V1 memories are immutable (docs/14_M5B_RECONCILIATION.md
-- section 3.1). The only permitted change is becoming a tombstone, once.
-- Enforced here, in the database, so no client — including a modified one —
-- can rewrite someone's saved text or undo a deletion.
create or replace function public.memories_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id <> old.id
     or new.user_id <> old.user_id
     or new.content <> old.content
     or new.intake_source <> old.intake_source
     or new.source_app is distinct from old.source_app
     or new.created_at <> old.created_at then
    raise exception 'memories are immutable except for deletion'
      using errcode = '42501';
  end if;

  -- No Trash, no Restore (PD-006, PD-021): a tombstone stays a tombstone.
  if old.deleted_at is not null
     and new.deleted_at is distinct from old.deleted_at then
    raise exception 'a deleted memory cannot be restored'
      using errcode = '42501';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger memories_before_insert
  before insert on public.memories
  for each row execute function public.memories_before_insert();

create trigger memories_before_update
  before update on public.memories
  for each row execute function public.memories_before_update();
