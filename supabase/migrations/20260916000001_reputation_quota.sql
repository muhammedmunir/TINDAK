-- TINDAK — online reputation quota (M8b)
--
-- Run once in the Supabase SQL Editor, after the M5b migrations.
--
-- WHAT THIS STORES, AND WHY IT IS SO LITTLE
--   A daily count per user, and nothing else. Not the URL, not the host, not
--   the verdict: a list of the links someone checked is a browsing history,
--   and Protect does not need one to do its job (M8 gate, C-3).
--
--   The count exists for one identified purpose — enforcing the 60-per-day
--   limit (PD-028) somewhere the app cannot reset by reinstalling. Rows older
--   than 30 days serve no purpose and are deleted.
--
-- No `security_scans` table is created. The original design in
-- docs/11_DATABASE.md section 2.5 stored the full URL; nothing in M8 needs it,
-- so it is not built.

create table public.reputation_usage (
  user_id uuid    not null references auth.users (id) on delete cascade,
  day     date    not null default (now() at time zone 'utc')::date,
  checks  integer not null default 0,

  primary key (user_id, day),
  constraint reputation_usage_checks_positive check (checks >= 0)
);

-- ---------------------------------------------------------------------------
-- No client ever touches this table
-- ---------------------------------------------------------------------------

alter table public.reputation_usage enable row level security;

-- Deliberately no policies: with RLS on and no policy, neither anon nor
-- authenticated can read or write a single row. The Edge Function reaches it
-- only through the function below, as the service role.
revoke all on table public.reputation_usage from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Counting, atomically
-- ---------------------------------------------------------------------------

-- Returns true when this call is within the limit, false when it is not, and
-- increments only when it returns true.
--
-- The insert and the check happen in **one statement**, so two requests
-- arriving together cannot both read 59 and both proceed: the second one waits
-- on the row lock and sees 60. A read-then-write in application code is where
-- that race normally lives.
create or replace function public.consume_reputation_check(
  p_user  uuid,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed boolean;
begin
  if p_user is null or p_limit is null or p_limit < 0 then
    raise exception 'invalid arguments' using errcode = '22023';
  end if;

  insert into public.reputation_usage as u (user_id, day, checks)
  values (p_user, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day) do update
    set checks = u.checks + 1
    where u.checks < p_limit
  returning true into allowed;

  -- No row came back: the update was refused because the day is used up.
  return coalesce(allowed, false);
end;
$$;

-- Only the service role, from inside the Edge Function. Supabase grants
-- EXECUTE on new public functions to anon and authenticated by default, which
-- would let a client mint or exhaust its own quota.
revoke all on function public.consume_reputation_check(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.consume_reputation_check(uuid, integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- Retention: 30 days, enforced by the database and not by a promise in a doc
-- ---------------------------------------------------------------------------

create or replace function public.purge_reputation_usage()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.reputation_usage
  where day < ((now() at time zone 'utc')::date - 30);
$$;

revoke all on function public.purge_reputation_usage() from public, anon, authenticated;

create extension if not exists pg_cron;

-- Daily at 18:30 UTC (02:30 in Malaysia), a quiet hour either way.
select cron.schedule(
  'tindak-purge-reputation-usage',
  '30 18 * * *',
  $$select public.purge_reputation_usage()$$
);
