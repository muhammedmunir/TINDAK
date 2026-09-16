-- TINDAK — atomic Memory push (M5b, step 5)
--
-- Run once in the Supabase SQL Editor, after 20260915000002_memories_rls.sql.
--
-- WHY A FUNCTION
--   A memory and its entities must reach the cloud together. Two separate
--   PostgREST inserts leave a window in which another device can pull the
--   memory before its entities exist — and because memories are immutable, that
--   device would never receive them. One function call is one transaction:
--   both arrive, or neither does.
--
-- WHY SECURITY INVOKER
--   The function runs as the caller, so every RLS policy in
--   20260915000002_memories_rls.sql still applies to every row it writes. It
--   grants no power the caller did not already have. user_id is never a
--   parameter: it is always auth.uid(), so a client cannot name another owner.
--
-- IDEMPOTENT
--   A push whose response was lost is simply sent again. An id that already
--   exists for this caller is left untouched and its server time returned.

create or replace function public.push_memory(
  p_id            uuid,
  p_content       text,
  p_intake_source text,
  p_source_app    text,
  p_created_at    timestamptz,
  p_entities      jsonb
)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller   uuid := (select auth.uid());
  inserted integer;
  server_ts timestamptz;
begin
  if caller is null then
    raise exception 'sign-in required' using errcode = '42501';
  end if;

  if p_entities is null or jsonb_typeof(p_entities) <> 'array' then
    raise exception 'entities must be an array' using errcode = '22023';
  end if;

  -- Bounds the work one call can cause. The understanding engine never finds
  -- anywhere near this many entities in 10,000 code points of real text.
  if jsonb_array_length(p_entities) > 200 then
    raise exception 'too many entities' using errcode = '22023';
  end if;

  insert into public.memories
    (id, user_id, content, intake_source, source_app, created_at)
  values
    -- A device clock set in the future cannot date a memory after the server
    -- has seen it.
    (p_id, caller, p_content, p_intake_source, p_source_app,
     least(coalesce(p_created_at, now()), now()))
  on conflict (id) do nothing;
  get diagnostics inserted = row_count;

  -- Entities are written only with the memory's first arrival. On a retry they
  -- are already there, from the same transaction that created the memory.
  if inserted = 1 then
    insert into public.memory_entities
      (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
       start_offset, end_offset)
    select
      (e ->> 'id')::uuid,
      p_id,
      caller,
      e ->> 'type',
      e ->> 'raw_value',
      e ->> 'normalized_value',
      (e ->> 'confidence')::real,
      (e ->> 'start_offset')::integer,
      (e ->> 'end_offset')::integer
    from jsonb_array_elements(p_entities) as e;
  end if;

  -- Read through RLS: an id that belongs to someone else is invisible here, so
  -- the call fails rather than acknowledging a row the caller does not own.
  select m.updated_at into server_ts
  from public.memories m
  where m.id = p_id and m.user_id = caller;

  if server_ts is null then
    raise exception 'memory id unavailable' using errcode = '42501';
  end if;

  return server_ts;
end;
$$;

-- Supabase grants EXECUTE on new public functions to anon and authenticated by
-- default. Only a signed-in user may push.
revoke all on function public.push_memory(uuid, text, text, text, timestamptz, jsonb)
  from public, anon;
grant execute on function public.push_memory(uuid, text, text, text, timestamptz, jsonb)
  to authenticated;
