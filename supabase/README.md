# TINDAK — Supabase

Cloud schema, Row Level Security and security tests for M5b.

## Environment

One Supabase project serves every environment (CEO decision, M5b). There is no
local Supabase and no Docker. Consequences, accepted knowingly:

- Migrations run against the only database. Review each file before running it.
- Security tests run on the live project. `tests/rls_memories.sql` is written to
  be safe there: throwaway users, cleaned up at the end, rolled back on any
  failure, and it never touches other users' rows.

## Credentials

The project URL and publishable key are public by design and scoped by RLS.
They still **never enter this repository** — the app receives them at build
time through `--dart-define` (`mobile/README.md`).

Never commit, paste into an issue, or put in the Flutter app: the secret or
service-role key, the database password, or a personal access token.

## Running a migration

Supabase Dashboard → **SQL Editor** → paste the whole file → **Run**.

Run in filename order, each exactly once:

| File | Creates |
|---|---|
| `migrations/20260915000001_memories.sql` | `memories`, `memory_entities`, server-time and immutability triggers |
| `migrations/20260915000002_memories_rls.sql` | RLS, least-privilege grants, policies |
| `migrations/20260915000003_push_memory.sql` | `push_memory()` — a memory and its entities in one transaction, running under the caller's RLS |

A migration that has run is never edited. A change is a new, later file.

## Running the security tests

After all three migrations, paste `tests/rls_memories.sql` into the SQL Editor and
run it. The result grid lists every check; **every row must read PASS**.

Record the grid in `docs/20_TEST_PLAN.md` §9 under a dated heading. M5b does not
pass its gate until that record exists.

If the script stops with a permission error on `auth.users`, the SQL Editor role
cannot create test users on this project. Report it rather than weakening a
policy to make the test run.
