-- TINDAK — Row Level Security for Memory (M5b, step 2)
--
-- Run once in the Supabase SQL Editor, after 20260915000001_memories.sql.
--
-- RLS is a release blocker (master plan section 22). "RLS enabled" is not
-- evidence: supabase/tests/rls_memories.sql attempts every bypass and must
-- report PASS for all of them before M5b can pass its gate.
--
-- Design, docs/12_SECURITY.md section 3, with the fix from
-- docs/14_M5B_RECONCILIATION.md section 2.2.

alter table public.memories        enable row level security;
alter table public.memory_entities enable row level security;

-- ---------------------------------------------------------------------------
-- Grants — least privilege, before policies narrow them further
-- ---------------------------------------------------------------------------

-- Anonymous callers get nothing at all. A guest never talks to the cloud
-- (PD-001), so there is no reason for the anon role to reach these tables.
revoke all on table public.memories        from anon;
revoke all on table public.memory_entities from anon;

-- Signed-in users: read, create, and tombstone. No DELETE grant — the client
-- never hard deletes in the cloud. Deletion is a tombstone (PD-021); rows
-- leave the table only through the server-side purge after 90 days (PD-028)
-- or when the account itself is deleted.
revoke all on table public.memories from authenticated;
grant select, insert, update on table public.memories to authenticated;

-- Entities are derived and immutable once written: read and create only.
revoke all on table public.memory_entities from authenticated;
grant select, insert on table public.memory_entities to authenticated;

-- ---------------------------------------------------------------------------
-- memories
-- ---------------------------------------------------------------------------

-- (select auth.uid()) rather than auth.uid(): evaluated once per statement
-- instead of once per row.

create policy memories_select_own on public.memories
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy memories_insert_own on public.memories
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- Both USING and WITH CHECK. With USING alone, a user could update their own
-- row and set user_id to someone else's, handing the row away (T-2).
create policy memories_update_own on public.memories
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Deliberately no DELETE policy.

-- ---------------------------------------------------------------------------
-- memory_entities
-- ---------------------------------------------------------------------------

create policy memory_entities_select_own on public.memory_entities
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- The caller must own the entity row AND the memory it belongs to.
-- Checking user_id alone would let someone attach an entity carrying their own
-- user id to another user's memory, and learn from the foreign key whether a
-- guessed memory id exists (B-13). The subquery is itself filtered by the
-- memories select policy, so it can only ever see the caller's own memories.
create policy memory_entities_insert_own on public.memory_entities
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.memories m
      where m.id = memory_id
        and m.user_id = (select auth.uid())
        and m.deleted_at is null
    )
  );

-- Deliberately no UPDATE or DELETE policy.
