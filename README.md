# TINDAK

> Jumpa sesuatu. Tindak terus.

An action layer for useful information received or discovered on an Android phone.

**Status:** M0 — Product documentation. No application code yet.

---

## Core Loop

```text
SHARE → UNDERSTAND → ACT → REMEMBER → PROTECT
```

A user shares text into TINDAK from any app. TINDAK understands what it is
(phone, URL, money, date), offers the actions that make sense, and remembers it
for later.

## Stack

| Layer | Choice |
|---|---|
| Platform | Android only (V1) |
| Frontend | Flutter |
| Backend | Supabase (PostgreSQL, Auth, RLS, Edge Functions) |
| Source of truth | This repository |
| AI | Gemini API — selective fallback only |
| Notifications | Local notifications; FCM only if server-triggered push is needed |

## Non-Negotiable Rules

1. **Local-first understanding.** Not every input goes to AI. AI runs only when
   local confidence is low. (ADR-005, ADR-006)
2. **No secret API key in the Flutter client.** All external providers are
   reached through a Supabase Edge Function. (Section 17)
3. **RLS is a release blocker.** "RLS enabled" is not proof. Policies must be
   written, tested, bypass-attempted, and documented. (Section 22)
4. **Explicit Share Intent only.** No background clipboard monitoring, no
   background screen reading. (ADR-003, ADR-004)
5. **Explainable security.** No unsupported certainty such as `SCAM 98%`.
   (ADR-009)

Full rules: [`docs/91_AI_RULES.md`](docs/91_AI_RULES.md).

## Repository Layout

```text
TINDAK_MASTER_PROJECT_PLAN.md   Locked project direction
docs/                           Product + technical documentation
mobile/                         Flutter app (not created yet — M1)
supabase/                       Migrations + Edge Functions (not created yet — M5)
```

## Documentation

| File | Owner |
|---|---|
| `docs/00_PRODUCT_VISION.md` | Product Direction |
| `docs/01_PRD_V1.md` | Product Direction |
| `docs/02_PRODUCT_ROADMAP.md` | Product Direction |
| `docs/03_UX_FLOWS.md` | Product Direction |
| `docs/10_ARCHITECTURE.md` | Technical Lead |
| `docs/11_DATABASE.md` | Technical Lead |
| `docs/12_SECURITY.md` | Technical Lead |
| `docs/13_API.md` | Technical Lead |
| `docs/20_TEST_PLAN.md` | Technical Lead |
| `docs/21_RELEASE_PLAN.md` | Technical Lead |
| `docs/90_DECISIONS.md` | Shared governance |
| `docs/91_AI_RULES.md` | Shared governance |

The CEO approves all locked versions.

## Branches

```text
main      releasable only
develop   integration
feat/*    feature work
```

Commit convention: `feat:`, `fix:`, `test:`, `security:`, `refactor:`, `chore:`,
`docs:`. Prefer small reversible commits.

## Milestones

| # | Deliverable | Gate |
|---|---|---|
| M0 | Product documents | CEO approval |
| M1 | Flutter + GitHub foundation | Build passes |
| M2 | Android Share Intent | Real app share works |
| M3 | Phone + URL understanding | Parser tests pass |
| M4 | Action Engine | Real actions work |
| M5 | Supabase Memory | CRUD + RLS works |
| M6 | Money + Date | Parser tests pass |
| M7 | Reminder | Device notification works |
| M8 | Basic Protect | Security tests pass |
| M9 | AI fallback | Complex text works |
| M10 | Founder Alpha | CEO test passes |
| M11 | Closed Beta | Real-user validation |
| M12 | Play Store Release | CEO release approval |

## Current Blocker

Startup Step 1 (Product Pack) is not complete. `00`–`03` must be written and
approved before the Technical Lead can produce `10`–`21` (Step 2), and no
application code is written before Architecture Lock (Step 4).
