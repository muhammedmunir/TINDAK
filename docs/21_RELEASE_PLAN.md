# 21 — RELEASE PLAN

**Owner:** Technical Lead (Claude)
**Status:** BLOCKED — waiting for Product Pack approval
**Approval:** CEO approves every production release

> Scaffold only.

## Planned contents

- Branch flow: `feat/*` -> `develop` -> `main`. `main` stays releasable.
- Versioning scheme.
- Signing key handling. Keystores and `key.properties` are never committed.
- AAB build steps.
- Play Console track plan: internal -> closed -> production.
- Rollback procedure.

## Validation stages (Section 29)

| Stage | Users | Focus |
|---|---|---|
| Founder Alpha | CEO only | Crashes, parser mistakes, Share Intent reliability |
| Closed Alpha | 5–10 trusted | UX confusion, crashes, detection and action failures |
| Beta | 20–50 MY Android users | Do users remember to use Share -> TINDAK? |
| Wider | 100+ | D1/D7 retention, actions per user, AI fallback rate |

## Definition of V1 Done

A building AAB is not "done". The full checklist is in
`TINDAK_MASTER_PROJECT_PLAN.md` Section 41 and must be satisfied, ending with
CEO release approval.
