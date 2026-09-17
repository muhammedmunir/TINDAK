-- TINDAK — RLS bypass tests for Memory (M5b)
--
-- HOW TO RUN
--   Only through supabase/tests/run-rls-matrix.ps1. Do not paste this file into
--   the SQL Editor: the two user ids below are placeholders the harness fills
--   in, and the block refuses to run without real test users behind them.
--   Every row of the result must read PASS. Record the run in
--   docs/20_TEST_PLAN.md section 9 under a dated heading; a run that was not
--   recorded did not happen.
--
-- NEVER WRITES TO auth.* (EAR-BLOCKER-01)
--   An earlier version inserted its test users straight into auth.users. On
--   2026-09-16 a direct write like that left a row GoTrue could not read and
--   broke sign-in for the whole project. Test users are now created and deleted
--   only by the harness, through the Auth Admin API. This file reads auth.users
--   once, to confirm the ids it was given are those throwaway users, and never
--   inserts, updates or deletes anything in the auth schema.
--
-- SCOPE OF WHAT IT TOUCHES
--   Refuses to start unless both ids belong to rls-test-*@tindak.invalid users
--   that own no data yet. It creates rows only for those two users, removes
--   them from public.memories at the end (entities follow by cascade), and
--   never reads or modifies any other user's data. If anything fails part-way,
--   the block rolls back; the harness still deletes the two users.
--
-- WHY POSITIVE CONTROLS
--   A policy that refuses everything would "pass" every bypass test. P-*
--   checks prove the legitimate paths still work, so a PASS on B-* means the
--   policy is precise, not merely closed.
--
-- Covers docs/12_SECURITY.md section 3.3 for the M5b tables, B-13 from
-- docs/14_M5B_RECONCILIATION.md section 2.2, the immutability, no-restore
-- and 10,000 code-point rules, and the push_memory function (P-7, P-8, B-15,
-- B-2c, I-7). Run after all three migrations. B-8 (expired JWT) and B-11 (direct PostgREST)
-- need a real HTTP request and are tested separately.

drop table if exists pg_temp.rls_results;
create temp table rls_results (
  seq      serial primary key,
  id       text not null,
  check_   text not null,
  expected text not null,
  observed text not null,
  result   text not null
);

do $rls$
declare
  -- Filled in by run-rls-matrix.ps1 with users it created via the Auth Admin API.
  a        uuid := '__RLS_TEST_USER_A__'::uuid;
  b        uuid := '__RLS_TEST_USER_B__'::uuid;
  a_mem    uuid := gen_random_uuid();
  a_tomb   uuid := gen_random_uuid();
  a_push   uuid := gen_random_uuid();
  a_bad    uuid := gen_random_uuid();
  b_mem    uuid := gen_random_uuid();
  n        integer;
  denied   boolean;
  ts_before timestamptz;
  ts_after  timestamptz;
begin
  -- -------------------------------------------------------------------------
  -- Guard: refuse to touch anyone who is not a harness-created test user
  -- -------------------------------------------------------------------------
  if a = b then
    raise exception 'RLS fixture refused: the two test users must be different';
  end if;

  select count(*) into n
  from auth.users u
  where u.id in (a, b)
    and u.email like 'rls-test-%@tindak.invalid';
  if n <> 2 then
    raise exception 'RLS fixture refused: ids are not two rls-test-*@tindak.invalid users';
  end if;

  select count(*) into n from public.memories where user_id in (a, b);
  if n <> 0 then
    raise exception 'RLS fixture refused: test users already own memories';
  end if;

  -- -------------------------------------------------------------------------
  -- Setup, as the owner role (RLS does not apply to it)
  -- -------------------------------------------------------------------------
  insert into public.memories (id, user_id, content, intake_source)
  values (b_mem, b, 'B private memory 012-3456789', 'share');

  insert into public.memory_entities
    (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
     start_offset, end_offset)
  values
    (gen_random_uuid(), b_mem, b, 'phone', '012-3456789', '+60123456789',
     0.95, 17, 28);

  -- =========================================================================
  -- Positive controls — acting as A
  -- =========================================================================
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', a::text, true);

  -- P-1 A creates their own memory
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (a_mem, a, 'A own memory 019-8765432', 'paste');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-1', 'A creates own memory', 'allowed',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'FAIL' else 'PASS' end);

  -- P-2 A attaches an entity to their own memory
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memory_entities
      (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
       start_offset, end_offset)
    values
      (gen_random_uuid(), a_mem, a, 'phone', '019-8765432', '+60198765432',
       0.95, 13, 24);
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-2', 'A adds entity to own memory', 'allowed',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'FAIL' else 'PASS' end);

  -- P-3 A reads their own memory and entity
  perform set_config('role', 'authenticated', true);
  select count(*) into n
  from public.memories m
  join public.memory_entities e on e.memory_id = m.id
  where m.id = a_mem;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-3', 'A reads own memory with entity', '1 row', n || ' row(s)',
     case when n = 1 then 'PASS' else 'FAIL' end);

  -- P-4 A tombstones their own memory, and the server sets updated_at
  insert into public.memories (id, user_id, content, intake_source, updated_at)
  values (a_tomb, a, 'A memory to delete', 'share', '2000-01-01');
  select updated_at into ts_before from public.memories where id = a_tomb;

  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    -- The client also tries to backdate updated_at on the update.
    update public.memories set deleted_at = now(), updated_at = '2000-01-01'
    where id = a_tomb;
    get diagnostics n = row_count;
  exception when others then denied := true; n := 0;
  end;
  execute 'reset role';
  select updated_at into ts_after from public.memories where id = a_tomb;
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-4', 'A tombstones own memory', 'allowed, 1 row',
     case when denied then 'denied' else n || ' row(s)' end,
     case when not denied and n = 1 then 'PASS' else 'FAIL' end);

  -- P-5 updated_at is server-set on insert AND update, never client-set.
  -- This whole script is one transaction, where now() is constant, so the two
  -- server times are equal by design; what matters is that neither is the
  -- client's 2000-01-01.
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-5', 'client-supplied updated_at is ignored', 'server time, not 2000',
     'insert ' || ts_before::text || ', update ' || ts_after::text,
     case when ts_before > '2020-01-01' and ts_after > '2020-01-01'
          then 'PASS' else 'FAIL' end);

  -- P-6 exactly 10,000 code points is accepted (PD-039)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (gen_random_uuid(), a, repeat('😀', 10000), 'paste');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-6', '10,000 emoji (code points) accepted', 'allowed',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'FAIL' else 'PASS' end);

  -- P-7 A pushes a memory with an entity through push_memory
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    ts_after := public.push_memory(
      a_push, 'A pushed 012-3456789', 'share', null, now(),
      jsonb_build_array(jsonb_build_object(
        'id', gen_random_uuid(), 'type', 'phone', 'raw_value', '012-3456789',
        'normalized_value', '+60123456789', 'confidence', 0.95,
        'start_offset', 9, 'end_offset', 20)));
  exception when others then denied := true;
  end;
  execute 'reset role';
  select count(*) into n from public.memory_entities
  where memory_id = a_push and user_id = a;
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-7', 'A pushes memory + entity via push_memory', 'allowed, 1 entity',
     case when denied then 'denied' else 'allowed, ' || n || ' entity' end,
     case when not denied and n = 1 and ts_after is not null
          then 'PASS' else 'FAIL' end);

  -- P-8 the same push again is idempotent
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    ts_before := public.push_memory(
      a_push, 'A pushed 012-3456789', 'share', null, now(),
      jsonb_build_array(jsonb_build_object(
        'id', gen_random_uuid(), 'type', 'phone', 'raw_value', '012-3456789',
        'normalized_value', '+60123456789', 'confidence', 0.95,
        'start_offset', 9, 'end_offset', 20)));
  exception when others then denied := true;
  end;
  execute 'reset role';
  select count(*) into n from public.memory_entities where memory_id = a_push;
  insert into rls_results (id, check_, expected, observed, result) values
    ('P-8', 'repeated push is idempotent', 'allowed, same time, 1 entity',
     case when denied then 'denied' else 'allowed, ' || n || ' entity' end,
     case when not denied and n = 1 and ts_before = ts_after
          then 'PASS' else 'FAIL' end);

  -- =========================================================================
  -- Bypass attempts — acting as A against B
  -- =========================================================================

  -- B-15 push_memory with B's memory id, trying to attach entities to it
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    perform public.push_memory(
      b_mem, 'hijack', 'share', null, now(),
      jsonb_build_array(jsonb_build_object(
        'id', gen_random_uuid(), 'type', 'url', 'raw_value', 'x',
        'normalized_value', 'https://evil.example', 'confidence', 0.99,
        'start_offset', 0, 'end_offset', 1)));
  exception when others then denied := true;
  end;
  execute 'reset role';
  select count(*) into n from public.memory_entities where memory_id = b_mem;
  insert into rls_results (id, check_, expected, observed, result)
  select 'B-15', 'A pushes using B memory id', 'denied, B unchanged',
         case when denied then 'denied' else 'allowed' end
           || ', ' || n || ' entity on B',
         case when denied and n = 1 and m.content = 'B private memory 012-3456789'
              then 'PASS' else 'FAIL' end
  from public.memories m where m.id = b_mem;

  -- B-1 read B's memory by id
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.memories where id = b_mem;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-1', 'A reads B memory by id', '0 rows', n || ' row(s)',
     case when n = 0 then 'PASS' else 'FAIL' end);

  -- B-3 insert a memory owned by B
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (gen_random_uuid(), b, 'forged into B', 'share');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-3', 'A inserts memory as B', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-4 hand own memory to B by changing user_id
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    update public.memories set user_id = b where id = a_mem;
    get diagnostics n = row_count;
    if n = 0 then denied := true; end if;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-4', 'A reassigns own memory to B', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-5 hard delete B's memory
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    delete from public.memories where id = b_mem;
    get diagnostics n = row_count;
    if n = 0 then denied := true; end if;
  exception when others then denied := true;
  end;
  execute 'reset role';
  select count(*) into n from public.memories where id = b_mem;
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-5', 'A deletes B memory', 'denied, row intact',
     case when denied then 'denied' else 'allowed' end || ', ' || n || ' row(s) remain',
     case when denied and n = 1 then 'PASS' else 'FAIL' end);

  -- B-5b hard delete own memory (tombstones only, PD-021)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    delete from public.memories where id = a_mem;
    get diagnostics n = row_count;
    if n = 0 then denied := true; end if;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-5b', 'A hard deletes own memory', 'denied (tombstone only)',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-6 read B's entities
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.memory_entities where memory_id = b_mem;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-6', 'A reads B entities', '0 rows', n || ' row(s)',
     case when n = 0 then 'PASS' else 'FAIL' end);

  -- B-7 reach B's rows through a join
  perform set_config('role', 'authenticated', true);
  select count(*) into n
  from public.memories m
  join public.memory_entities e on e.memory_id = m.id
  where m.user_id = b;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-7', 'A reaches B rows via join', '0 rows', n || ' row(s)',
     case when n = 0 then 'PASS' else 'FAIL' end);

  -- B-12 enumerate auth.users
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    select count(*) into n from auth.users;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-12', 'A enumerates auth.users', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-13 attach an entity to B's memory, carrying A's own user_id
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memory_entities
      (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
       start_offset, end_offset)
    values
      (gen_random_uuid(), b_mem, a, 'url', 'x', 'https://evil.example',
       0.99, 0, 1);
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-13', 'A attaches entity to B memory', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-13b attach an entity to own memory but claim it is B's
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memory_entities
      (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
       start_offset, end_offset)
    values
      (gen_random_uuid(), a_mem, b, 'url', 'x', 'https://evil.example',
       0.99, 0, 1);
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-13b', 'A adds entity to own memory as B', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-14 tombstone B's memory
  perform set_config('role', 'authenticated', true);
  begin
    update public.memories set deleted_at = now() where id = b_mem;
    get diagnostics n = row_count;
  exception when others then n := 0;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result)
  select 'B-14', 'A tombstones B memory', '0 rows, B intact',
         n || ' row(s) updated',
         case when n = 0 and m.deleted_at is null then 'PASS' else 'FAIL' end
  from public.memories m where m.id = b_mem;

  -- =========================================================================
  -- Integrity rules — acting as A on A's own data
  -- =========================================================================

  -- I-1 rewrite own saved text (V1 memories are immutable)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    update public.memories set content = 'rewritten' where id = a_mem;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-1', 'A rewrites own memory text', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-2 restore own tombstone (no Restore, PD-006)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    update public.memories set deleted_at = null where id = a_tomb;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-2', 'A restores own tombstone', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-3 10,001 code points (PD-039)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (gen_random_uuid(), a, repeat('😀', 10001), 'paste');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-3', '10,001 code points refused', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-4 create a memory already deleted
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source, deleted_at)
    values (gen_random_uuid(), a, 'born dead', 'share', now());
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-4', 'A creates an already-deleted memory', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-5 attach an entity to own tombstoned memory
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memory_entities
      (id, memory_id, user_id, type, raw_value, normalized_value, confidence,
       start_offset, end_offset)
    values
      (gen_random_uuid(), a_tomb, a, 'url', 'x', 'https://x.example',
       0.99, 0, 1);
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-5', 'A adds entity to own tombstone', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-6 unknown intake source
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (gen_random_uuid(), a, 'x', 'clipboard_monitor');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-6', 'unknown intake_source refused', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- I-7 a push with one invalid entity leaves nothing behind (atomic)
  perform set_config('role', 'authenticated', true);
  denied := false;
  begin
    perform public.push_memory(
      a_bad, 'half a push', 'paste', null, now(),
      jsonb_build_array(jsonb_build_object(
        'id', gen_random_uuid(), 'type', 'phone', 'raw_value', 'x',
        'normalized_value', '+60123456789', 'confidence', 0.9,
        'start_offset', 5, 'end_offset', 2)));
  exception when others then denied := true;
  end;
  execute 'reset role';
  select count(*) into n from public.memories where id = a_bad;
  insert into rls_results (id, check_, expected, observed, result) values
    ('I-7', 'push with invalid entity is all-or-nothing', 'denied, 0 rows',
     case when denied then 'denied' else 'allowed' end || ', ' || n || ' row(s)',
     case when denied and n = 0 then 'PASS' else 'FAIL' end);

  -- =========================================================================
  -- Anonymous — no JWT at all
  -- =========================================================================

  -- B-2 anon reads memories
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  denied := false;
  begin
    select count(*) into n from public.memories;
    if n = 0 then denied := true; end if;
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-2', 'anon reads memories', 'denied or 0 rows',
     case when denied then 'denied' else n || ' row(s)' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-2b anon inserts a memory
  perform set_config('role', 'anon', true);
  denied := false;
  begin
    insert into public.memories (id, user_id, content, intake_source)
    values (gen_random_uuid(), a, 'anon write', 'share');
  exception when others then denied := true;
  end;
  execute 'reset role';
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-2b', 'anon inserts memory', 'denied',
     case when denied then 'denied' else 'allowed' end,
     case when denied then 'PASS' else 'FAIL' end);

  -- B-2c anon calls push_memory
  perform set_config('role', 'anon', true);
  denied := false;
  begin
    perform public.push_memory(
      gen_random_uuid(), 'anon push', 'share', null, now(), '[]'::jsonb);
  exception when others then denied := true;
  end;
  execute 'reset role';
  -- Denied is not enough on its own: the function also refuses a null caller.
  -- The grant itself must be absent.
  insert into rls_results (id, check_, expected, observed, result) values
    ('B-2c', 'anon calls push_memory', 'denied, no EXECUTE grant',
     case when denied then 'denied' else 'allowed' end || ', grant '
       || case when has_function_privilege('anon',
            'public.push_memory(uuid, text, text, text, timestamptz, jsonb)',
            'execute') then 'present' else 'absent' end,
     case when denied and not has_function_privilege('anon',
            'public.push_memory(uuid, text, text, text, timestamptz, jsonb)',
            'execute') then 'PASS' else 'FAIL' end);

  -- S-1 push_memory cannot bypass RLS: SECURITY INVOKER, search_path locked
  insert into rls_results (id, check_, expected, observed, result)
  select 'S-1', 'push_memory is invoker-rights, search_path locked',
         'invoker, search_path=""',
         case when p.prosecdef then 'DEFINER' else 'invoker' end || ', '
           || coalesce(array_to_string(p.proconfig, ';'), 'no config'),
         case when not p.prosecdef
               and p.proconfig @> array['search_path=""']
              then 'PASS' else 'FAIL' end
  from pg_proc p
  join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public' and p.proname = 'push_memory';

  -- -------------------------------------------------------------------------
  -- Cleanup: the test users' application rows only. The users themselves are
  -- deleted afterwards by the harness through the Auth Admin API (Z-2).
  -- -------------------------------------------------------------------------
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  delete from public.memories where user_id in (a, b);

  select count(*) into n from public.memories where user_id in (a, b);
  select n + count(*) into n from public.memory_entities where user_id in (a, b);
  insert into rls_results (id, check_, expected, observed, result) values
    ('Z-1', 'test data removed', '0 rows left', n || ' row(s)',
     case when n = 0 then 'PASS' else 'FAIL' end);
end
$rls$;

select id, check_ as "check", expected, observed, result
from rls_results
order by seq;
