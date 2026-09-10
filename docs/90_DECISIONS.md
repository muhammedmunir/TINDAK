# 90 — DECISIONS

**Owner:** Shared governance
**Status:** ADR-001…ADR-012 Accepted · PD-001…PD-022 Accepted · ADR-013…ADR-027 **Proposed**

Three registers:

- **ADR-001…ADR-012** — founding decisions from the master plan. Accepted.
- **PD-001…PD-022** — product decisions, locked with Product Pack V1 at CEO
  approval. Accepted.
- **ADR-013…ADR-027** — architecture decisions proposed in the Technical Pack.
  **Not accepted.** They become binding only at CEO Architecture Lock.

An accepted decision is binding until the CEO explicitly changes it (AI Rule
14). Decisions are appended, never edited in place; to reverse one, add a new
decision that supersedes it and mark the old one `Superseded by`.

---

# Part 1 — Founding ADRs (Accepted)

| ID | Decision | Status |
|---|---|---|
| ADR-001 | Supabase is the primary backend | Accepted — clarified by ADR-013 |
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

Full text of each is in `TINDAK_MASTER_PROJECT_PLAN.md` §35. ADR-001 is **not**
amended — ADR-013 clarifies which layer it governs.

---

# Part 2 — Product Decisions (Accepted with Product Pack V1)

| ID | Decision |
|---|---|
| PD-001 | **Guest-first.** No account required for core use. Cloud sync requires sign-in. |
| PD-002 | **Multi-entity.** All meaningful entities are retained; ranking for presentation is allowed, discarding is not. |
| PD-003 | **Manual Save.** Sharing is not consent to store. |
| PD-004 | **Search** covers original text plus normalized entity values. No semantic or vector search in V1. |
| PD-005 | **Offline core.** Local understanding, actions, Memory and reminders work without connectivity. |
| PD-006 | **Hard delete** from the user's perspective. No Trash, no Archive, no Restore in V1. |
| PD-007 | **No invented reminder time.** A date without a time asks the user to pick one. |
| PD-008 | **DD/MM/YYYY.** Malaysia-first; `03/04/2026` is 3 April 2026. |
| PD-009 | **Phone baseline:** Malaysian mobile, `+60`, common spacing and hyphens, Malaysian landlines. Short codes out of scope. |
| PD-010 | **AI limits** are a technical proposal, not a product decision. Delegated to the Technical Pack. |
| PD-011 | **Explicit AI consent** before the first cloud-AI processing. Declining must not disable local features. |
| PD-012 | **Manual Protect.** External reputation lookup happens only on an explicit tap. |
| PD-013 | **Full-screen Share Result** in V1, not an overlay over the source app. |
| PD-014 | **No force-close** after an external action. |
| PD-015 | **Unknown content** is shown with a clear message and remains saveable. |
| PD-016 | **Explicit guest migration.** No silent upload of local memories after sign-in. |
| PD-017 | **Sign-out privacy.** Account-owned data must not remain normally readable without re-authentication. |
| PD-018 | **No CRDT.** Simplest safe deterministic synchronization. |
| PD-019 | **Guest uninstall loss accepted**, with clear disclosure that does not block first use. |
| PD-020 | **Unified Memory UX.** No Local/Cloud tabs; the user never learns where a row lives. |
| PD-021 | **Tombstones permitted.** User-visible permanent deletion; internal tombstones allowed where needed for deterministic sync, with a documented purge policy. |
| PD-022 | **No external analytics vendor in V1.** Supabase may hold authenticated product telemetry. No private content, no sensitive entity values. Guest analytics must not introduce a new service. |

Source: `00_PRODUCT_VISION.md`, `01_PRD_V1.md`, `02_PRODUCT_ROADMAP.md`,
`03_UX_FLOWS.md`.

---

# Part 3 — Proposed ADRs (awaiting Architecture Lock)

## ADR-013 — Supabase is the primary *cloud* backend
**Decision:** Supabase remains the only backend service. The core experience —
Share → Understand → Act → local Memory — does not depend on connectivity or
authentication.
**Why:** PD-001 and PD-005 removed the network from the critical path. ADR-001
still holds; this states which layer it governs.
**Status:** Proposed.

## ADR-014 — Local-first persistence
**Decision:** The device database is the source of truth for the device. Guest
memories live locally; cloud sync is opt-in after sign-in.
**Why:** PD-001, PD-005, PD-016.
**Status:** Proposed.

## ADR-015 — Local store is SQLite via Drift
**Decision:** Drift over SQLite with FTS5 for local persistence and search.
**Why:** Real SQL and full-text search, runs in plain Dart unit tests without an
emulator, explicit versioned migrations, and a schema that maps almost 1:1 onto
Postgres — which keeps the sync code boring. Hive has no query engine or FTS;
Isar's upstream maintenance is unstable and this store holds the user's only
copy of guest data; sqflite is the same engine with worse testability.
**Detail:** `10_ARCHITECTURE.md` §7.2.
**Status:** Proposed.

## ADR-016 — State management is Riverpod, without code generation
**Decision:** `flutter_riverpod`, plain providers, no `riverpod_generator`.
**Why:** Application logic stays testable without `WidgetTester` or a
`BuildContext`. Bloc costs an event/state pair per flow in a five-screen app.
`build_runner` is kept to one job — Drift.
**Status:** Proposed.

## ADR-017 — Share Intent is implemented natively, with no package
**Decision:** An `ACTION_SEND` / `text/plain` intent filter plus a small Kotlin
`MethodChannel` handler covering cold start and warm resume.
**Why:** ADR-003 makes share intent the single entry point of the product — the
one thing that must never break. A package here adds no capability we lack and
costs control over cold-start behaviour, which is where share receivers fail.
AI Rule 6 requires a dependency to have a clear technical reason; this one does
not have one.
**Status:** Proposed.

## ADR-018 — Navigation uses Navigator 1.0, with no routing package
**Decision:** A named route table. No `go_router` in V1.
**Why:** Five screens, no nested navigators, no web URLs, and the share entry
point arrives as an intent rather than a deep link. Revisit if deep links
appear.
**Status:** Proposed.

## ADR-019 — Sync is last-write-wins on server time
**Decision:** Client-generated UUIDv4 ids; conflict resolved by the greater
server-set `updated_at`, whole row; deletion via `deleted_at` tombstones; pull
by cursor; **tombstones purged after 90 days**, with a full re-pull for a client
that has been away longer.
**Why:** PD-018 and PD-021. Deterministic and small. A simultaneous edit on two
devices is a lost update, accepted for V1 and already out of scope in the PRD.
**Detail:** `10_ARCHITECTURE.md` §8.
**Status:** Proposed.

## ADR-020 — Authentication is Supabase email OTP
**Decision:** Six-digit email OTP. Google Sign-In deferred. **Supabase anonymous
sign-in is rejected.**
**Why:** No password to leak or reset, and the code is entered inside TINDAK, so
no deep link is needed (which keeps ADR-018 intact). Anonymous sign-in would
create a cloud user for every guest — the silent upload PD-016 forbids — and
would make the per-user quota meaningless, since a reinstall mints a new
identity.
**Detail:** `13_API.md` §1.
**Status:** Proposed.

## ADR-021 — Local data protection without SQLCipher in V1
**Decision:** `allowBackup=false`, backup extraction rules excluding the
database, Android file-based encryption, and the sign-out purge. No SQLCipher
in V1.
**Why:** SQLCipher's key lives on the same device as the data, so it mainly
raises the cost of an attack it rarely stops, while adding a key-loss failure
mode that would destroy a guest's only copy of their data. `allowBackup=false`
blocks the realistic exfiltration path — the database being copied into cloud
backup. Residual risk on a rooted or unlocked device is accepted and documented.
**Detail:** `12_SECURITY.md` §4.1.
**Status:** Proposed. **CEO may overrule; the alternative is costed in that section.**

## ADR-022 — Sign-out deletes account-owned local rows
**Decision:** On sign-out, delete local rows where `owner_user_id` is not null,
clear the sync cursor and session, and cancel their scheduled notifications.
Guest-owned rows are untouched.
**Why:** PD-017 requires account data not to remain readable. Deletion has no
key to lose and nothing to un-forget; the cloud copy is intact and returns on
sign-in.
**Status:** Proposed.

## ADR-023 — Money is stored as integer sen
**Decision:** `RM183.50` is stored as `18350` with currency `MYR`, never as a
floating-point number.
**Why:** `183.50` is not exactly representable as a binary double. Money that
fails to compare equal to itself is a defect that surfaces months later. The
master plan's conceptual JSON shows the display form, not the storage form.
**Status:** Proposed.

## ADR-024 — Reminders use inexact local alarms
**Decision:** `flutter_local_notifications` with an inexact allow-while-idle
schedule. TINDAK does not request `SCHEDULE_EXACT_ALARM`.
**Why:** Exact alarms are a restricted permission on recent Android versions and
are meant for alarm-clock and calendar-event apps. A bill reminder tolerates a
few minutes of drift, and requesting a restricted permission we do not need is
both a Play review risk and a worse permission story for the user.
**Status:** Proposed.

## ADR-025 — Cloud-dependent features require sign-in
**Decision:** AI fallback and the external half of Security Check require an
authenticated session. Local URL heuristics and every local feature remain
available to guests.
**Why:** Both call metered third-party APIs billed to us. An Edge Function needs
a JWT to attribute a call, enforce a quota, and stop an abuser. An anonymous
path would be a rate-limit hole with no owner.
**Product impact:** `Try AI` (UX §19) and `Security Check` (UX §6) need a
signed-out state. **This needs a Product Direction ruling on wording and on
whether the control is hidden or shown with a sign-in prompt.**
**Status:** Proposed. Escalated as E-1.

## ADR-026 — Two-digit years are rejected
**Decision:** `25/09/26` is not detected as a date in V1.
**Why:** A reminder set to the wrong year fails silently and is discovered only
by missing the thing. PD-007 already establishes that TINDAK does not invent
time values; guessing a century is the same class of mistake. The PRD baseline
is four-digit years.
**Status:** Proposed.

## ADR-027 — No telemetry from guest devices
**Decision:** Product telemetry is written only for signed-in users, into
`usage_events`. Guests send nothing. The allowed event names and property keys
are enforced by database constraints, not only by client code.
**Why:** PD-022. An anonymous telemetry path would be the new service PD-022
forbids, and the database-level allowlist means a future client bug cannot leak
shared content into analytics.
**Detail:** `11_DATABASE.md` §2.6.
**Status:** Proposed.

---

# Part 4 — Open, awaiting decision

| Topic | Proposal on the table | Decider |
|---|---|---|
| Guests and cloud features (E-1) | ADR-025 — require sign-in | Product Direction, then CEO |
| Dates with no year (E-2) | Next occurrence, flagged `yearInferred` | Product Direction |
| Notification permission denied (E-3) | Save the reminder anyway, show an "off" state | Product Direction |
| Bare domains as URLs | Do not detect — too many false positives in Malay text | Product Direction |
| Reminders on a second device | They do not fire there in V1 — local notifications only | Product Direction |
| SQLCipher | Defer (ADR-021) | CEO |
| Tombstone purge window | 90 days | CEO |
| Share input cap | 10,000 characters | CEO |
| AI quota, caps, timeouts | `13_API.md` §4 | CEO |
| URL reputation provider | Safe Browsing Lookup API as leading candidate | CEO, before M8 |
| Google Sign-In in V1 | Defer | CEO |
