# 90 — DECISIONS

**Owner:** Shared governance
**Status:** ARCHITECTURE LOCKED — 2026-09-10
ADR-001…ADR-032 Accepted · PD-001…PD-046 Accepted

Three registers, all binding:

- **ADR-001…ADR-012** — founding decisions from the master plan.
- **PD-001…PD-045** — product decisions. PD-001…PD-022 locked with Product Pack
  V1; PD-023…PD-029 from the Product Direction review of the Technical Pack;
  PD-030…PD-031 at Architecture Lock; PD-032…PD-045 from milestone reviews.
- **ADR-013…ADR-028** — architecture decisions from the Technical Pack.
  Product Direction passed them and the CEO locked them on 2026-09-10. They are
  binding for V1 unless superseded by a later CEO-approved decision.
- **ADR-029…ADR-031** — amendments accepted during implementation (ADR-003 at
  M2, ADR-015's search mechanism at M5a, ADR-022's sign-out at M5b).

An accepted decision is binding until the CEO explicitly changes it (AI Rule
14). Decisions are appended, never edited in place; to reverse one, add a new
decision that supersedes it and mark the old one `Superseded by`.

---

# Part 1 — Founding ADRs (Accepted)

| ID | Decision | Status |
|---|---|---|
| ADR-001 | Supabase is the primary backend | Accepted — clarified by ADR-013 |
| ADR-002 | Initial release is Android only | Accepted |
| ADR-003 | Input enters via explicit Android Share Intent | Accepted — **amended by ADR-029** |
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

## PD-023…PD-029 — added by Product Direction review of the Technical Pack

### PD-023 — Cloud controls stay visible to guests
A guest sees `Try AI` and `Security Check`. Tapping one leads to a sign-in
prompt, not a hidden or absent control — a user must not conclude that TINDAK
has no AI and no Protect. Basic local URL heuristics remain available to guests
without an account.

### PD-024 — Sign-in is not AI consent
Two separate gates, in order: `Guest → Try AI → Sign In → AI disclosure and
consent → AI processing`. Authenticating never implies permission to send
content to an AI provider, and a signed-in user who has never consented still
sees the consent screen.

### PD-025 — Dates without a year resolve to the next occurrence
This year if the date is still ahead, otherwise next year. The inference is
transparent and editable: the reminder confirmation shows the resolved year in
full, and the user can change it before the reminder is created. Internal flag
only — `yearInferred` never appears in the UI.

### PD-026 — A denied notification permission does not destroy the reminder
A reminder and a notification are different things. If permission is denied the
reminder is still saved, Memory Save is never blocked, the UI states that
notifications are off and offers to enable them, the prompt is not repeated on
every attempt, and TINDAK never claims an alert will fire when the OS will not
deliver one. Recovery is reachable from Settings.

### PD-027 — Bare domains are not detected in V1
A URL needs an explicit `http://`, `https://` or `www.` prefix. `kedai.my`
inside a Malay sentence is not a link. A false action is worse than a
conservative detector. Backlogged as *URL Detection Enhancement*, revisited only
with beta data.

### PD-028 — Initial operational configuration
Approved as tunable configuration, not immutable product constants.

| Setting | Value |
|---|---|
| Tombstone retention | 90 days |
| Maximum shared text | 10,000 characters |
| Maximum AI input | 2,000 characters |
| AI quota | 30 per user per day |
| AI burst | 5 per user per minute |
| AI timeout | 8s upstream / 12s client |
| External reputation quota | 60 per user per day |
| `security_scans` retention | 30 days |
| SQLCipher | deferred for V1 |

### PD-029 — IC and USSD protection are required safety requirements
A Malaysian IC number must never become a Call or WhatsApp candidate, and
untrusted phone text must be normalised and validated before it can reach a
`tel:` URI — `*` and `#` are refused. Both carry mandatory tests
(`20_TEST_PLAN.md` §2.2 and §7.1) that cannot be removed to make a build pass,
and a failure in either blocks release.

## PD-030…PD-031 — added at Architecture Lock

### PD-030 — Google Sign-In is deferred
V1 authentication baseline stays email OTP, six digits (ADR-020). Google
Sign-In is re-evaluated only after basic auth works and there is a concrete UX
reason to justify the extra dependency and per-variant configuration.

### PD-031 — Synced reminders are not cross-device alarms
V1 does not promise reminder scheduling across devices. The reminder record
syncs; the local notification is guaranteed only on the device where the
reminder was created. **Do not add FCM, a server scheduler, or device
orchestration to solve this in V1** — ADR-007 excludes it and the roadmap does
not carry it.

UX must not imply that syncing makes every device ring.

## PD-032 — added by the M2 review

### PD-032 — Invisible and bidirectional characters must not produce a deceptive action
Raw text may contain zero-width, invisible or bidirectional control characters.
While TINDAK only displays raw text (M2) these are inert. From M3 onward, when
text is normalised and turned into entities, a detector must never derive an
actionable value from a string whose visible form differs from its actual
content.

A phone number or URL that reads one way on screen and dials or opens another is
a scam mechanism. TINDAK's own Protect positioning (ADR-009) makes shipping one
unacceptable.

Required from M3: normalization removes these characters before detection, an
entity's actionable value comes from the normalised form rather than the raw
span, and safety tests cover it. Specification in `20_TEST_PLAN.md` section 1.1.

Raised by Product Direction in the M2 review. Not an M2 blocker, because M2 only
displays raw text and executes nothing.

## PD-033 — added by the M2 physical-device gate

### PD-033 — Two explicit intake paths: Share and Manual Paste
Physical testing found that WhatsApp's message context menu offers no Android
share for a plain text message — only Reply, Forward, Copy, Delete, Info and
Pin. The sharesheet is never reached, so TINDAK cannot appear. TINDAK's intent
filter is correct; the system resolver lists it first, and Chrome works.

WhatsApp matters too much to TINDAK's positioning to accept the gap.

V1 therefore supports **two** explicit, user-initiated intake paths:

```text
PATH 1   Share-capable app ─► Share ─► TINDAK
PATH 2   Any app with Copy ─► Copy  ─► TINDAK ─► Tampal
```

Both feed the same understanding pipeline. A detector never learns which path
the text arrived by.

**Manual Paste reads the clipboard only after the user presses the Paste
control.** Explicitly forbidden, all of it still forbidden by ADR-004:

- background clipboard monitoring;
- reading the clipboard at launch or on resume;
- polling;
- passive capture of any kind;
- persisting clipboard contents without a user action;
- any attempt to work around Android's clipboard privacy restrictions.

**Product copy changes.** No document or screen may tell a user to share a
WhatsApp text message to TINDAK, because they cannot.

| App | Guidance |
|---|---|
| WhatsApp | Copy → TINDAK → Tampal |
| Browsers and apps with Android share | Share → TINDAK |

An empty or non-text clipboard fails gracefully — a quiet message, not a
dramatic error.

### PD-034 — ACTION_PROCESS_TEXT is deferred
Declaring an `ACTION_PROCESS_TEXT` filter would put TINDAK in Android's
text-selection toolbar. It is not implemented in V1: there is no evidence it
solves WhatsApp, and its selection behaviour varies across OEMs and apps.

Backlog: *Explore Android `ACTION_PROCESS_TEXT` as an additional explicit
intake method after V1 validation.* Complexity is not added on a possibility.

## PD-035…PD-037 — added by the M4 Product Direction review

### PD-035 — Calling opens the dialer only
`Panggil` opens the system dialer pre-filled with the normalised number. TINDAK
never places a call, never requests `CALL_PHONE`, and the user always confirms
the call in the dialer. Locked for V1.

### PD-036 — WhatsApp is offered for Malaysian mobile numbers only
No WhatsApp control for a landline. Revisit only with evidence of a real use
case; do not generalise.

### PD-037 — Malay action labels
User-facing action labels are Malay for V1 consistency: `Panggil`, `Buka`.
`WhatsApp` is a brand name and stays unchanged. Internal identifiers are not
translated.

Approved failure copy: **"Tindakan ini tidak dapat dibuka pada peranti ini."** —
short, does not blame the user, and does not claim a cause TINDAK cannot know.

## PD-038…PD-040 — added by the M5a Product Direction review

### PD-038 — Memory search is deterministic local LIKE search
The V1 search baseline is local `LIKE`-based matching over the original text and
approved searchable entity values (ADR-030). A saved `Hubungi 012-345 6789` must
be found by `0123456789`; that requirement outranks the earlier choice of FTS5.
FTS5 is deferred and reconsidered only if real data or performance shows a
need. **Do not add FTS5 in parallel "for the future"** — it adds an index,
migrations and a consistency risk with no present requirement.

### PD-039 — Persisted Memory content is at most 10,000 characters
One contract for content, locally and in the cloud: a saved Memory holds at
most 10,000 characters. Oversized content is **refused explicitly at Save** and
is **never silently truncated** on save or on sync.

Copy: **"Teks terlalu panjang untuk disimpan. Had ialah 10,000 aksara."**

This governs what may be persisted, not what may be received and displayed —
intake display behaviour from M2 is unchanged.

Technical definition, recorded so every layer agrees: a character is a Unicode
code point. SQLite's `length()` and Postgres's `char_length()` count code
points; Dart's `String.length` counts UTF-16 units, where one emoji is two. The
limit is enforced by the repository and by a database `CHECK`, so bypassing the
UI or the repository cannot store more.

### PD-040 — Only concurrent Save activation may be suppressed
A Save tap that arrives while a Save is still in flight may be ignored. That is
concurrency protection, not deduplication. Two separate, completed explicit
saves still create two memories, and TINDAK performs **no content-based
duplicate suppression**. While a save is in flight, Simpan is disabled and shows
progress, so the user can see a second tap is not accepted.

### M5a UI copy — approved
All M5a copy as submitted, with one change: delete failure reads **"Item tidak
dapat dipadam. Cuba lagi."**, so a recoverable failure names the next step.

## PD-041…PD-045 — added by the M5b reconciliation review

### PD-041 — Sign-out is fail-safe
TINDAK must not complete sign-out while account-owned changes remain
unacknowledged by the cloud. Sign-out attempts a sync first. If it cannot
complete, the user stays signed in and sees:

> **Belum dapat log keluar**
> Ada perubahan yang belum disimpan ke cloud. Sambungkan internet dan cuba lagi
> supaya data anda tidak hilang.

**[Cuba Lagi] [Batal]**. There is **no "sign out anyway"** in V1. Deleting unsynced
data to honour PD-017 would trade one promise for silent data loss; blocking
keeps both.

### PD-042 — Saves while signed in sync automatically, after explicit Save
Pressing Simpan while signed in commits locally first and makes the memory
eligible for automatic cloud sync. This is transport after the user's
decision, not auto-save: the user still chooses what is kept (PD-003). A network
failure must never make the local Save fail; the memory waits as pending.

### PD-043 — Minimal Settings for Account and Cloud Sync
A minimal Settings screen holds exactly: **Akaun** (sign in, or the signed-in
email and sign out) and **Cloud Sync** (status, Sync Sekarang when relevant, and
resuming a deferred guest migration). Not a dashboard. Memory and search stay
unified — no Local/Cloud tabs.

### PD-044 — Guest migration needs explicit confirmation; declining is a no-op
After sign-in, when device-local guest memories exist:

> **Sync memori ke akaun?**
> Anda mempunyai **{count} item** yang disimpan pada peranti ini. Sync ke akaun
> supaya item ini boleh tersedia apabila anda menggunakan TINDAK dengan akaun
> anda.

**[Bukan Sekarang] [Sync]**. The count is dynamic. No prompt when the count is
zero. **Bukan Sekarang** performs no ownership change, no upload and no
background migration of guest rows.

### PD-045 — Shared devices: explicit migration assigns guest items to the signed-in account
TINDAK cannot know which person created a guest memory before any identity
existed, and does not invent one. Whoever is signed in and explicitly presses
Sync takes the device's guest items into that account. The prompt says "item
yang disimpan pada peranti ini", never "memori anda", so the consequence is
visible.

### M5b operating notes (Product Direction)
- One Supabase project is accepted for Founder Alpha. Security scripts that
  create and clean up test users may run there now, while it holds no real
  users. **Before closed beta, development and testing are separated from
  production.**
- The publishable key may ship in the client. Service-role keys, database
  credentials and private secrets never enter Flutter or Git history. Client
  values reach the app through build-time configuration, not hardcoded source.

---

# Part 3 — Architecture Decisions (Accepted at Architecture Lock, 2026-09-10)

## ADR-013 — Supabase is the primary *cloud* backend
**Decision:** Supabase remains the only backend service. The core experience —
Share → Understand → Act → local Memory — does not depend on connectivity or
authentication.
**Why:** PD-001 and PD-005 removed the network from the critical path. ADR-001
still holds; this states which layer it governs.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-014 — Local-first persistence
**Decision:** The device database is the source of truth for the device. Guest
memories live locally; cloud sync is opt-in after sign-in.
**Why:** PD-001, PD-005, PD-016.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-015 — Local store is SQLite via Drift
**Decision:** Drift over SQLite with FTS5 for local persistence and search.
**Why:** Real SQL and full-text search, runs in plain Dart unit tests without an
emulator, explicit versioned migrations, and a schema that maps almost 1:1 onto
Postgres — which keeps the sync code boring. Hive has no query engine or FTS;
Isar's upstream maintenance is unstable and this store holds the user's only
copy of guest data; sqflite is the same engine with worse testability.
**Detail:** `10_ARCHITECTURE.md` §7.2.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-016 — State management is Riverpod, without code generation
**Decision:** `flutter_riverpod`, plain providers, no `riverpod_generator`.
**Why:** Application logic stays testable without `WidgetTester` or a
`BuildContext`. Bloc costs an event/state pair per flow in a five-screen app.
`build_runner` is kept to one job — Drift.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-017 — Share Intent is implemented natively, with no package
**Decision:** An `ACTION_SEND` / `text/plain` intent filter plus a small Kotlin
`MethodChannel` handler covering cold start and warm resume.
**Why:** ADR-003 makes share intent the single entry point of the product — the
one thing that must never break. A package here adds no capability we lack and
costs control over cold-start behaviour, which is where share receivers fail.
AI Rule 6 requires a dependency to have a clear technical reason; this one does
not have one.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-018 — Navigation uses Navigator 1.0, with no routing package
**Decision:** A named route table. No `go_router` in V1.
**Why:** Five screens, no nested navigators, no web URLs, and the share entry
point arrives as an intent rather than a deep link. Revisit if deep links
appear.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-019 — Sync is last-write-wins on server time
**Decision:** Client-generated UUIDv4 ids; conflict resolved by the greater
server-set `updated_at`, whole row; deletion via `deleted_at` tombstones; pull
by cursor; **tombstones purged after 90 days**, with a full re-pull for a client
that has been away longer.
**Why:** PD-018 and PD-021. Deterministic and small. A simultaneous edit on two
devices is a lost update, accepted for V1 and already out of scope in the PRD.
**Detail:** `10_ARCHITECTURE.md` §8.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-020 — Authentication is Supabase email OTP
**Decision:** Six-digit email OTP. Google Sign-In deferred. **Supabase anonymous
sign-in is rejected.**
**Why:** No password to leak or reset, and the code is entered inside TINDAK, so
no deep link is needed (which keeps ADR-018 intact). Anonymous sign-in would
create a cloud user for every guest — the silent upload PD-016 forbids — and
would make the per-user quota meaningless, since a reinstall mints a new
identity.
**Detail:** `13_API.md` §1.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

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
**Status:** Accepted — CEO Architecture Lock, 2026-09-10. Reopened if Memory ever
holds credentials, identity documents or financial account details.

## ADR-022 — Sign-out deletes account-owned local rows
**Decision:** On sign-out, delete local rows where `owner_user_id` is not null,
clear the sync cursor and session, and cancel their scheduled notifications.
Guest-owned rows are untouched.
**Why:** PD-017 requires account data not to remain readable. Deletion has no
key to lose and nothing to un-forget; the cloud copy is intact and returns on
sign-in.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-023 — Money is stored as integer sen
**Decision:** `RM183.50` is stored as `18350` with currency `MYR`, never as a
floating-point number.
**Why:** `183.50` is not exactly representable as a binary double. Money that
fails to compare equal to itself is a defect that surfaces months later. The
master plan's conceptual JSON shows the display form, not the storage form.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-024 — Reminders use inexact local alarms
**Decision:** `flutter_local_notifications` with an inexact allow-while-idle
schedule. TINDAK does not request `SCHEDULE_EXACT_ALARM`.
**Why:** Exact alarms are a restricted permission on recent Android versions and
are meant for alarm-clock and calendar-event apps. A bill reminder tolerates a
few minutes of drift, and requesting a restricted permission we do not need is
both a Play review risk and a worse permission story for the user.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-025 — Authenticated access for protected server resources
**Decision (wording amended by Product Direction review):**

> Authenticated access is required for cloud features that consume protected or
> limited server resources, or that access account-owned data. Guest core
> functionality remains local-first and does not require authentication.

**Why:** The earlier wording — "all cloud-dependent features require sign-in" —
was too broad as a rule. It would have become a licence to put a login in front
of any feature merely because its implementation happened to touch the cloud.
The amended wording ties the requirement to the actual reason: a metered
third-party API billed to us, or someone else's data.

**In V1 this covers:** AI fallback and the external reputation lookup. An Edge
Function needs a JWT to attribute a call, enforce a quota, and stop an abuser;
an anonymous path would be a rate-limit hole with no owner.

**It does not cover:** anything local. Detection, actions, Memory, search,
reminders and local URL heuristics stay available to guests.

**Product behaviour:** PD-023 and PD-024 — the control stays visible, leads to
a sign-in prompt, and sign-in remains separate from AI consent.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10, with the amended
wording above.

## ADR-026 — Two-digit years are rejected
**Decision:** `25/09/26` is not detected as a date in V1.
**Why:** A reminder set to the wrong year fails silently and is discovered only
by missing the thing. PD-007 already establishes that TINDAK does not invent
time values; guessing a century is the same class of mistake. The PRD baseline
is four-digit years.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-027 — No telemetry from guest devices
**Decision:** Product telemetry is written only for signed-in users, into
`usage_events`. Guests send nothing. The allowed event names and property keys
are enforced by database constraints, not only by client code.
**Why:** PD-022. An anonymous telemetry path would be the new service PD-022
forbids, and the database-level allowlist means a future client bug cannot leak
shared content into analytics.
**Detail:** `11_DATABASE.md` §2.6.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10.

## ADR-028 — URL reputation provider is Google Web Risk, not Safe Browsing
**Decision:** Use the Web Risk **Lookup API** (`uris.search`) behind a
`ReputationProvider` interface. Do not use Safe Browsing.

**Why — verified against current official documentation, not assumption:**
Safe Browsing is free but its usage restrictions state it is "for non-commercial
use only (meaning 'not for sale or revenue generating purposes')" and direct
commercial users to Web Risk. The master plan §30 plans a paid Pro tier, which
puts TINDAK outside those terms. Safe Browsing v4 is also deprecated and ends
31 March 2027 — inside V1's life — and v5 carries the same restriction.

Web Risk is the commercial product for the same threat data: 100,000
`uris.search` calls per month free, then USD 0.50 per 1,000. With PD-028's cap
of 60 checks per user per day, the free tier covers Founder Alpha, Closed Alpha
and Beta without cost.

**Cost of being wrong here:** building V1 on Safe Browsing would have meant
either dropping monetization or migrating providers under pressure the moment
pricing shipped.

**Constraints:** the key lives only in Edge Function config; the function maps
the provider response onto TINDAK's own four verdicts and stable reason codes,
so replacing the provider touches neither client nor schema; the provider id is
stored on every `security_scans` row. Web Risk's Update API would leak less but
costs materially more and is recorded as a future privacy improvement, not V1.

**Detail:** `13_API.md` §5.
**Status:** Accepted — CEO Architecture Lock, 2026-09-10. Web Risk is the planned
V1 provider. **Google Cloud billing and API provisioning are deferred until
before M8** and do not block M1. The `ReputationProvider` abstraction is
mandatory so domain logic is never bound to Google.

## ADR-029 — Amends ADR-003: explicit intake, not share-only
**Decision:** ADR-003's principle was that TINDAK never captures content
passively. The mechanism it named — Android Share Intent — turned out not to
cover WhatsApp text messages (PD-033), so the principle is restated at the level
it actually meant:

> V1 supports explicit, user-initiated intake only: Android `ACTION_SEND`
> `text/plain`, and manual Paste. No passive or background capture.

**What does not change.** ADR-004 stands in full — no background clipboard
monitoring, no polling, no reading at launch or on resume, no passive capture.
The clipboard is read only in direct response to the user pressing Paste.

ADR-003's original text is not edited; this record supersedes its scope.

**Why not special-case WhatsApp instead:** a special case would put
source-awareness into the app. Two intake paths converging on one input type
keeps every detector, action and screen downstream ignorant of where text came
from.

**Status:** Accepted — CEO and Product Direction, 2026-09-10.

## ADR-031 — Amends ADR-022: sign-out is blocked until the account is safe to clear
**Decision:** ADR-022 deleted every account-owned row on sign-out on the
assumption that "the cloud copy is intact". That is false for a row still
pending — saved offline, or deleted offline. Sign-out now:

```text
account rows still pending?
  no  ─► purge account rows ─► clear sync state ─► end session
  yes ─► sync ─► still pending? ─► stay signed in, explain (PD-041)
                    │
                    no ─► purge ─► clear ─► end session
```

Local rows are purged **before** the session ends. If ending the session failed
after the purge, the user is left signed in with nothing to leak; the reverse
order could leave account data readable after sign-out (PD-017).

**Status:** Accepted — Product Direction M5b review (PD-041).

## ADR-030 — Amends ADR-015: Memory search uses LIKE, not FTS5
**Decision:** Local Memory search matches original text with
`LIKE %query%`, and entity values through a derived, lowercased
`search_value` column that holds the forms a person would type — for a phone,
both the national and international digits. Queries of three or more digits are
also matched as numbers. Wildcards in the query are escaped.

**Why:** FTS5's tokeniser splits `012-345 6789` into three tokens, so searching
`0123456789` — how Malaysians write a number — would find nothing. FTS5 also
matches only token prefixes, and needs a virtual table kept in step by triggers
that can silently desynchronise. A personal memory list is small enough that a
linear scan is well under a frame.

**What does not change:** Drift over SQLite (ADR-015) stands. Search stays
local, deterministic and non-AI (PD-004).

**Revisit:** if real usage reaches sizes where search is measurably slow.

**Detail:** `11_DATABASE.md` §3.1.
**Status:** Accepted — Product Direction and CEO, M5a review. Amends ADR-015's
search mechanism only; Drift over SQLite stands. See PD-038.

## ADR-032 — Sync implementation details (M5b)
**Decision:** Three technical refinements of ADR-019 and `13_API.md` §2 found
while building sync. None changes product behaviour.

1. **Push goes through `public.push_memory()`, not a table upsert.** It inserts
   a memory and its entities in one transaction, runs `SECURITY INVOKER` under
   the caller's RLS, takes `user_id` from `auth.uid()` only, and is idempotent.
   Two separate inserts would let another device pull a memory before its
   entities exist, and since memories are immutable it would never get them.
2. **Deleting an account item always leaves a tombstone,** even one the server
   has never acknowledged. Refines reconciliation §2.1: a push of that item may
   already be in flight, and a local hard delete would let the next pull bring
   it back. Sync never uploads the content of a tombstoned item; guest items
   are still deleted outright.
3. **Full re-pull after 80 days without a pull,** inside the 90-day purge window
   (PD-028), so the reset always happens before a tombstone can be purged.

**Detail:** `supabase/migrations/20260915000003_push_memory.sql`,
`mobile/lib/features/sync/`.
**Conditions (Product Direction):** `push_memory()` stays authenticated,
ownership-bound, transactional and unable to bypass RLS or immutability — it is
`SECURITY INVOKER` with a locked search path, asserted by S-1 in
`rls_memories.sql`. A tombstone carries no deleted content. The 80-day
reconciliation respects pending local changes and deletions and never touches
guest memories.
**Status:** Accepted — Product Direction M5b review (conditional pass).

### M5b known gaps accepted by Product Direction
- **Scheduled 90-day tombstone purge** — not an M5b blocker; must exist before
  closed beta.
- **Permanently rejected queued change** — accepted for alpha. Sync never
  retries in a loop (it runs only on its triggers); the change stays queued,
  Settings shows the failure, and the failure code is logged without content.
  Never silently deleted to allow sign-out.
- **Expired session** — account rows stay on the device but are unreadable
  through list, search and detail until the same account signs in again
  (PD-017). Guest memories stay usable.

### M5b copy baseline (Product Direction)
Sign-in, OTP, Settings, save and status copy as listed in the M5b review, and
the OTP email in `mobile/README.md`. Supabase errors are never shown to users.
Also approved: "Masukkan e-mel anda. Kami akan menghantar kod 6 digit.",
"Sahkan", "Hantar semula kod", "Tukar e-mel", "Kod baharu telah dihantar.",
"E-mel tidak sah.", "Terlalu banyak cubaan. Tunggu sebentar dan cuba lagi."

### M5b database access (Product Direction and CEO, 2026-09-15)
Direct production database access for Claude Code is **not approved**. The
original arrangement stands: Claude writes SQL, the CEO runs it in the Supabase
SQL Editor and returns only the result grid. A database password that entered a
chat transcript is reset immediately. No permission rule for Postgres is added.
**Status:** Superseded by the CEO override below.

### PD-046 — Authentication email goes through custom SMTP; Resend first
TINDAK V1 uses custom SMTP for Supabase authentication email. Resend is the
initial provider. Supabase's default sender is unsuitable: this Free-tier project
cannot customise authentication templates with it, and its sending limit is
unsuitable for testing and production.

Supabase Auth stays the identity system; Resend is email transport only. No
second authentication system, user store or application email subsystem.
ADR-020 stands: email OTP, exactly six digits, anonymous sign-in disabled.
Authentication email only in M5b — no marketing, newsletter or notification
email. Supabase is not upgraded solely for email. Credentials stay local and
git-ignored, never in Flutter, Git or logs.

**Before inviting anyone other than the CEO:** the sending domain must be
verified in Resend (SPF, DKIM, DMARC) and the sender switched from Resend's
test address, which delivers only to the Resend account owner.

### CEO OVERRIDE — TINDAK Supabase project administration (2026-09-15)
**Decision:** Claude Code may administer the **TINDAK Supabase project** for
development, deployment, migrations, authentication configuration, RLS and
security verification, database functions and M5b validation, using the
Supabase CLI, PostgreSQL tooling and the Management API where appropriate.
Supersedes the entry above. Product Direction accepts the override.

**Credentials**
- The database password exposed in a chat transcript is reset before use.
- Credentials never enter chat, Git, logs, test output or Flutter. They live
  only in `supabase/.env`, confirmed git-ignored with `git check-ignore` before
  use. `mobile/.env.client` holds client-safe values only.
- Least privilege where Supabase supports it: the project-scoped database
  connection first. An account-wide personal access token only when a task
  cannot be done otherwise.

**Safeguards before the first write:** verify the project ref is TINDAK's;
confirm every credential file is ignored; read-only connectivity and
configuration checks; review the pending SQL; touch no unrelated resource.

**Always requires CEO confirmation first:** anything destructive or
irreversible outside the approved migrations — dropping tables, deleting
production data or users, resetting the database, disabling RLS, rotating
credentials, billing, deleting the project. RLS and security controls are never
weakened to make a test pass.

**Scope:** M5b only. Security gate 32/32 PASS, then the 12 live scenarios, then
Product Direction final review. No M6.
**Status:** Accepted — CEO, with Product Direction acknowledgement.

**CEO waiver (2026-09-15):** the CEO chose not to reset the database password
that appeared in a chat transcript, and asked Claude to perform all Supabase
steps. Risk explained and accepted by the CEO. Claude placed the connection in
the git-ignored `supabase/.env`; the value is never printed or committed.
Revisit before closed beta, when production is separated from development.

---

# Part 4 — Open, awaiting decision

Nothing is blocking implementation.

| # | Topic | Outcome |
|---|---|---|
| O-1 | Architecture Lock | **APPROVED** — ADR-013…ADR-028 binding, 2026-09-10 |
| O-2 | Google Web Risk | **ACCEPTED** as the planned V1 provider; billing and provisioning deferred until before M8; abstraction mandatory |
| O-3 | Google Sign-In in V1 | **DEFERRED** — PD-030 |
| O-4 | Cross-device reminder alarms | **ACCEPTED as a V1 limitation** — PD-031 |

Carried to a later milestone, not open questions:

- Google Cloud billing and Web Risk provisioning — before M8.
- Reputation provider terms re-checked before M8 in case they change.

## Closed by the Product Direction review

| Was open | Outcome |
|---|---|
| Guests and cloud features (E-1) | ADR-025 amended; PD-023, PD-024 |
| Dates with no year (E-2) | PD-025 |
| Notification permission denied (E-3) | PD-026 |
| Bare domains as URLs | PD-027 |
| SQLCipher | Deferred, residual risk documented — ADR-021, `12_SECURITY.md` §4.1.1 |
| Tombstone purge, share cap, AI quota and timeouts, reputation quota, scan retention | PD-028 |
| URL reputation provider | Verified; Safe Browsing rejected on terms, Web Risk recommended — ADR-028 |
