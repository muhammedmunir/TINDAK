# 90 — ARCHITECTURE DECISION RECORDS

**Owner:** Shared governance
**Status:** ADR-001 to ADR-012 Accepted
**Source:** `TINDAK_MASTER_PROJECT_PLAN.md` Section 35

An accepted ADR is binding until the CEO explicitly changes it (AI Rule 14).
New decisions are appended, never edited in place. To reverse a decision, add a
new ADR that supersedes the old one and mark the old one `Superseded by ADR-nnn`.

---

## Index

| ID | Decision | Status |
|---|---|---|
| ADR-001 | Supabase is the primary backend | Accepted |
| ADR-002 | Initial release is Android only | Accepted |
| ADR-003 | Input enters via explicit Android Share Intent | Accepted |
| ADR-004 | No background clipboard monitoring | Accepted |
| ADR-005 | Local-first understanding | Accepted |
| ADR-006 | AI is fallback, not default engine | Accepted |
| ADR-007 | Firebase not required for initial MVP backend | Accepted |
| ADR-008 | Local notifications preferred for initial reminders | Accepted |
| ADR-009 | Security results must be explainable | Accepted |
| ADR-010 | Claude is Architect + Security Reviewer + Coding Agent | Accepted |
| ADR-011 | ChatGPT is Product Direction | Accepted |
| ADR-012 | CEO retains final approval authority | Accepted |

---

## ADR-001 — Primary Backend
**Decision:** Supabase is the primary backend.
**Status:** Accepted.

## ADR-002 — Platform
**Decision:** Initial release is Android only.
**Status:** Accepted.

## ADR-003 — Input
**Decision:** User content enters TINDAK through explicit Android Share Intent.
**Status:** Accepted.

## ADR-004 — Clipboard
**Decision:** No background clipboard monitoring.
**Status:** Accepted.

## ADR-005 — Understanding
**Decision:** TINDAK uses local-first understanding.
**Status:** Accepted.

## ADR-006 — AI
**Decision:** AI is fallback, not the default processing engine.
**Status:** Accepted.

## ADR-007 — Firebase
**Decision:** Firebase is not required for the initial MVP backend.
**Status:** Accepted.

## ADR-008 — Notifications
**Decision:** Local notifications are preferred for initial reminders.
**Status:** Accepted.

## ADR-009 — Security
**Decision:** Security results must be explainable and must not claim
unsupported certainty.
**Status:** Accepted.

## ADR-010 — Technical Authority
**Decision:** Claude acts as System Architect, Security Reviewer, and Coding
Agent.
**Status:** Accepted.

## ADR-011 — Product Authority
**Decision:** ChatGPT acts as Product Direction.
**Status:** Accepted.

## ADR-012 — Final Authority
**Decision:** CEO retains final approval authority.
**Status:** Accepted.

---

## Open — Awaiting Decision

These are known decisions that are NOT yet made. The Technical Lead will propose
options in the Technical Pack (Startup Step 2); the CEO decides.

| Topic | Why it is open | Blocked by |
|---|---|---|
| Authentication flow | Must protect cloud data without killing activation (Section 13) | Product Pack |
| Database schema | Claude designs; CEO must approve before first production migration is locked (Section 21) | Product Pack |
| State management | Package choice needs a technical reason (AI Rule 6) | Architecture doc |
| URL reputation provider | Cost, privacy, and rate limits unknown | V0.6 scope |
| Offline / caching strategy | Depends on Memory model | Architecture doc |
