# 11 — DATABASE

**Owner:** Technical Lead (Claude)
**Status:** BLOCKED — waiting for Product Pack approval
**Approval:** CEO must approve the schema before the first production migration
is considered locked (Section 21)

> Scaffold only.

## Planned contents

- Schema proposal covering at least: `profiles`, `memories`, `memory_entities`,
  `reminders`, `security_scans`, `usage_events`. The Technical Lead may simplify
  the initial schema if the simplification is justified.
- Column types, constraints, and indexes.
- Search strategy for memory search.
- Migration layout under `supabase/migrations/`.
- Retention and deletion behaviour.
- RLS policy definitions per table — see `12_SECURITY.md` for the test plan.

## Hard requirement

User A must never be able to read, write, or delete User B's memories. This is a
release blocker (Section 22).
