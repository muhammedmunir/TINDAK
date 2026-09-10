# 10 — ARCHITECTURE

**Owner:** Technical Lead (Claude)
**Approval:** CEO — locked 2026-09-10
**Status:** LOCKED — CEO Architecture Lock, 2026-09-10
**Inputs:** `00_PRODUCT_VISION.md`, `01_PRD_V1.md`, `02_PRODUCT_ROADMAP.md`, `03_UX_FLOWS.md`, PD-001…PD-022, ADR-001…ADR-012

---

## 1. Scope of this document

How TINDAK V1 is built: the runtime layers, the module structure,
the understanding and action engines, the persistence and sync model, and every
dependency with its justification.

It does not restate product requirements and does not add features. Every
decision here is locked as an ADR in `90_DECISIONS.md` and is binding until the
CEO changes it (AI Rule 14).

---

## 2. Forces that shape the design

| Product decision | Architectural consequence |
|---|---|
| PD-001 guest-first | Auth cannot sit on the critical path. No Supabase call in the core loop. |
| PD-005 offline core | Local persistence is a first-class store, not a cache. |
| PD-002 multi-entity | The result type is a list, never a single entity. |
| PD-003 manual Save | Understanding must run without writing anything. |
| PD-006 + PD-021 delete | Deletion needs tombstones to propagate between devices. |
| PD-018 no CRDT | Deterministic last-write-wins, per row. |
| PD-020 unified Memory | One repository interface; local/cloud split invisible to UI. |
| PD-012 manual Protect | No network call on URL detection. |
| PD-011 AI consent | The AI path is opt-in and isolated behind one gateway. |

---

## 3. Layers

```text
                    ┌──────────────────────────┐
                    │        UI (Flutter)      │
                    │  screens, widgets, state │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────┴─────────────┐
                    │      Application         │
                    │  use cases, controllers  │
                    └────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────┴────────┐    ┌──────────┴─────────┐    ┌─────────┴────────┐
│  Understanding │    │      Actions       │    │      Memory      │
│   pure Dart    │    │  resolver + exec   │    │    repository    │
└───────┬────────┘    └──────────┬─────────┘    └─────────┬────────┘
        │                        │                        │
        │                 platform channels        ┌──────┴──────┐
        │                 (tel, WhatsApp,          │             │
        │                  browser, notif)    ┌────┴────┐   ┌────┴────┐
        │                                    │  Local  │   │  Cloud  │
   ┌────┴────┐                               │ SQLite  │   │Supabase │
   │   AI    │                               └─────────┘   └─────────┘
   │ gateway │                                     │             │
   └────┬────┘                                     └──────┬──────┘
        │                                                 │
        └──────────► Supabase Edge Functions ◄────────────┘
                     (AI, URL reputation)
```

**Rule:** `Understanding` and `Actions` (resolution, not execution) are pure
Dart with no Flutter and no I/O imports. They are unit-testable on the Dart VM
without a device or emulator. This is what makes the test plan cheap.

---

## 4. Module structure

Refines Section 20 of the master plan. Two folders are added that the plan did
not anticipate — `auth/` and `sync/` — because PD-001 and PD-016 introduced
work that did not previously exist.

```text
mobile/lib/
├── app/                    entry point, theme, root widget, route table
├── core/
│   ├── result/             Result<T> with a sealed Failure
│   ├── failure/            typed failures
│   ├── clock/              injectable clock (date detection is time-sensitive)
│   ├── config/             build-time config via --dart-define, public values only
│   └── logging/            no shared content in release logs
├── features/
│   ├── home/               home and empty state (PRD §19)
│   ├── share/              intent receiver, Share Result screen
│   ├── understanding/
│   │   ├── model/          NormalizedContent, DetectedEntity, UnderstandingResult
│   │   ├── normalizer/
│   │   ├── detectors/      phone, url, money, date
│   │   └── engine/         UnderstandingEngine
│   ├── actions/
│   │   ├── model/          ActionDescriptor
│   │   ├── resolver/       pure: entity -> available actions
│   │   └── executor/       impure: launches Android intents
│   ├── memory/             repository, local DAO, cloud DAO, screens
│   ├── reminders/
│   ├── security/           local URL heuristics + reputation client
│   ├── ai/                 consent gate + AI gateway client
│   ├── auth/               sign-in, session, guest migration
│   ├── sync/               sync engine, cursor, conflict rule
│   └── settings/
└── shared/                 reusable widgets, formatters
```

---

## 5. Understanding Engine

Section 10 of the master plan forbids one long `if/else` regex chain. The shape:

```text
raw shared text
      │
      ▼
ContentNormalizer          trim, unify whitespace, normalise unicode
      │                    (does NOT lowercase — case matters for URLs)
      ▼
UnderstandingEngine        holds a List<EntityDetector>
      │
      ├─► PhoneDetector    ─┐
      ├─► UrlDetector       │ each runs independently over the same
      ├─► MoneyDetector     │ normalized content and returns 0..n entities
      └─► DateDetector     ─┘
      │
      ▼
overlap resolution         drop entities fully contained inside a
      │                    higher-confidence entity of another type
      ▼
UnderstandingResult        entities: List<DetectedEntity>  (PD-002)
                           primary: DetectedEntity?        (ranking only)
```

```dart
abstract interface class EntityDetector {
  EntityType get type;
  List<DetectedEntity> detect(NormalizedContent content);
}
```

`DetectedEntity` carries `type`, `rawValue`, `normalizedValue`, `confidence`,
and the character range `[start, end)` in the normalized text. The range is what
makes overlap resolution possible and lets the UI highlight matches later.

**Overlap rule.** A URL contains digits that look like a phone number and dots
that look like a date. The engine resolves by span: if entity A's span is fully
inside entity B's span and B has higher confidence, A is dropped. Equal-length
overlaps keep the higher confidence, ties broken by a fixed detector priority
(`url > phone > money > date`). Deterministic, no heuristics.

**Ranking, not discarding.** `primary` exists only to decide which action the UI
emphasises. Every meaningful entity is retained (PD-002).

**Performance.** Detection is synchronous on the UI isolate. Input is capped
(§9) and the detectors are linear regex scans, so the budget is well under one
frame. No isolate is introduced until a measurement says otherwise.

---

## 6. Action Engine

Split in two, because half of it is testable and half of it is not.

```text
ActionResolver   pure      UnderstandingResult -> List<ActionDescriptor>
ActionExecutor   impure    ActionDescriptor    -> Android intent
```

| Entity | Actions (PRD §5–§8) |
|---|---|
| phone | Call, WhatsApp, Save |
| url | Open, Security Check, Save |
| money | Copy, Save |
| date | Reminder, Save |
| none | Save, and Try AI when consent + session allow |

Save is always present, including on the nothing-detected screen (PRD §18).

`ActionExecutor` is the only place that touches `url_launcher`. It refuses any
scheme other than `tel:`, `https:`, `http:`, and the WhatsApp deep link, and it
sanitises the phone number first — see `12_SECURITY.md` §7.

---

## 7. Persistence

### 7.1 Local is the source of truth for the device

```text
Share ─► Understand ─► [Save] ─► Local SQLite ─► (if signed in) sync ─► Supabase
```

The core loop never awaits the network. Supabase is a replica the user opts
into (ADR-013, ADR-014 proposed below).

### 7.2 Local persistence technology: Drift (SQLite) — ADR-015

| Option | Verdict |
|---|---|
| **Drift** (SQLite + FTS5) | **Recommended.** Real SQL, FTS5 full-text search, runs in plain Dart unit tests via `sqlite3` with no emulator, schema migrations are explicit and versioned, and the schema maps almost 1:1 onto the Postgres schema — which keeps the sync code boring. |
| Hive | No query engine and no full-text search. Memory search (PRD §10) would become an in-memory scan over every row. Rejected. |
| Isar | Fast with built-in full-text index, but upstream maintenance has been unstable and the project depends on a community fork. Too much risk for the store that holds the user's only copy of guest data. Rejected. |
| sqflite | Works, but untyped SQL strings and no first-class migration tooling. Drift is a thin layer over the same engine with materially better testability. Rejected. |

Cost: `drift`, `drift_dev`, `build_runner`, `sqlite3_flutter_libs`.

### 7.3 Ownership and provenance

Every local row carries ownership from M5a, before authentication exists. This
is the constraint raised earlier: without it, M5b cannot separate guest data
from account data at sign-out (PD-017).

```text
owner_user_id   NULL      -> guest-owned, stays on device, survives sign-out
                <uuid>    -> account-owned, purged from device on sign-out

sync_status     local_only | pending | synced
```

Row IDs are **client-generated UUIDv4**, assigned at Save time, never
reassigned. Migration at sign-in (PD-016) is then a metadata update
(`owner_user_id = uid`, `sync_status = pending`) and a push — not a copy, not a
re-key, no duplicate risk if it is interrupted.

---

## 8. Sync (M5b)

### 8.1 Last-write-wins on server time — ADR-019

```text
PUSH   rows where sync_status = 'pending'  ──► upsert into Supabase
PULL   rows where updated_at > cursor      ◄── ordered by updated_at
```

- Conflict rule: the row with the greater `updated_at` wins, whole row. The
  server sets `updated_at` on write, so clocks on devices cannot skew it.
- Cursor: the largest `updated_at` seen in the last successful pull, stored in
  `sync_meta`. Overlap by one second on each pull and de-duplicate by id, so a
  row written during a pull is not skipped.
- Deletion: `deleted_at` is set, the row is a tombstone. It is never shown, never
  searchable, never restorable (PD-021).
- Tombstone purge: **90 days** (approved, PD-028), server-side. A client that has not
  synced for longer than the purge window cannot trust incremental pull, so it
  drops all account-owned local rows and does a full re-pull. Guest-owned rows
  are untouched.
- Trigger points: after sign-in, on Save/Delete while signed in, on app resume,
  and on manual pull-to-refresh. No background service, no periodic worker.

This is the simplest strategy that is still deterministic (PD-018). Two devices
editing the same memory in the same second is a lost update — accepted for V1
and stated in the PRD as out of scope.

---

## 9. Share Intent

### 9.1 Implemented natively, no package — ADR-017

The Android side is an `intent-filter` for `ACTION_SEND` / `text/plain` plus
roughly forty lines of Kotlin that read `Intent.EXTRA_TEXT` and hand it to Dart
over a `MethodChannel`, covering both cold start and warm resume.

`receive_sharing_intent` would do this too, but ADR-003 makes share intent the
single entry point of the whole product — the one thing that must never break.
A dependency here buys little and costs control over the exact behaviour on cold
start, which is where share receivers usually fail. AI Rule 6 says a dependency
needs a clear technical reason; this one does not have one.

### 9.2 Input cap

**10,000 characters** (approved, PD-028). Longer input is truncated for understanding,
with the untruncated text still shown and saveable. Any app on the device can
send an arbitrarily large string; the cap keeps regex scanning and the local
write bounded. See `12_SECURITY.md` §5.

### 9.3 Launch mode

Share Result is a full-screen route in the single existing Android activity
(PD-013). `launchMode="singleTask"` with the intent delivered through
`onNewIntent`, so a second share while TINDAK is open replaces the result
instead of stacking activities. TINDAK never finishes itself after an external
action (PD-014).

---

## 10. State management

**Riverpod (`flutter_riverpod`), no code generation — ADR-016.**

Providers are plain Dart objects, so application-layer logic is testable without
`WidgetTester` and without a `BuildContext`. Bloc would add an event/state class
pair per flow for a five-screen app; `provider` alone gives weaker compile-time
safety and no easy override for tests. Code generation is skipped to keep
`build_runner` doing one job only (Drift).

---

## 11. Navigation

**Navigator 1.0 with a named route table. No routing package — ADR-018.**

Five screens, no nested navigators, no web URLs, and the share entry point
arrives as an Android intent rather than a deep link. `go_router` would earn its
place if deep links or nested shells appear; today it would be a dependency
without a reason (AI Rule 6). Revisit if V1.5 adds deep links.

---

## 12. Dependencies

Every entry needs a reason (AI Rule 6). Nothing else ships in V1.

| Package | Purpose | Why this one |
|---|---|---|
| `flutter_riverpod` | state | §10 |
| `drift`, `sqlite3_flutter_libs` | local store | §7.2 |
| `supabase_flutter` | cloud backend, auth | ADR-001 |
| `flutter_local_notifications` | reminders | ADR-008; the only maintained option |
| `timezone` | correct local fire time across DST/timezone change | required by the above for scheduled notifications |
| `url_launcher` | Call, WhatsApp, Open URL | standard platform bridge |
| `flutter_secure_storage` | Supabase session + any local key material | Keystore-backed; the default session store is plain SharedPreferences |
| `uuid` | client-generated row ids | §7.3 |
| `intl` | date and currency formatting for `ms_MY` | avoids hand-rolled formatting |

Dev-only: `flutter_test`, `drift_dev`, `build_runner`, `flutter_lints`.

Not adopted: `receive_sharing_intent` (§9.1), `go_router` (§11), any analytics
SDK (PD-022), any HTTP client beyond what `supabase_flutter` provides, any
dependency injection framework, any code-generation package beyond Drift's.

---

## 13. Offline behaviour

| Operation | Offline |
|---|---|
| Receive share | works |
| Normalize + detect (phone, url, money, date) | works |
| Call, WhatsApp, Open URL, Copy | works — handled by other apps |
| Save, list, search, delete Memory | works — local |
| Create and fire reminder | works — local notification |
| Cloud sync | queued, retried on next trigger |
| AI fallback, external Security Check | unavailable, explained per UX §18 |

Cloud-only failures never present as a generic network error on operations that
succeed locally (UX §18).

---

## 14. Error handling

Application and domain layers return `Result<T, Failure>`; exceptions are not
used for expected outcomes. `Failure` is a sealed type, so the UI must handle
every case and the three questions in UX §26 can be answered per case.

---

## 15. Guests and cloud features — resolved

E-1, E-2 and E-3 were escalated to Product Direction and have been decided.
The approved behaviour is recorded as PD-023…PD-026 and is binding on the
implementation.

### 15.1 Guests reach cloud features through sign-in, not through a hidden button

AI fallback and external URL reputation run in Supabase Edge Functions, and an
Edge Function needs a JWT to attribute a call and enforce a quota. A guest has
no JWT, so a guest cannot complete either. The control is still shown — hiding
it would teach the user that TINDAK has no AI and no Protect (PD-023).

```text
Guest taps [Security Check]        Guest taps [Try AI]
        │                                  │
   local heuristics run              nothing runs yet
        │                                  │
   "Sign in to run an online         "Sign in to use cloud AI
    security check. TINDAK can        understanding."
    still perform basic checks
    on this device."                       │
        │                                  │
   [Not Now]  [Sign In]              [Not Now]  [Sign In]
```

**Sign-in is not AI consent** (PD-024). They are two separate gates, in order:

```text
Guest ─► Try AI ─► Sign In ─► AI disclosure + consent ─► AI processing
```

A signed-in user who has never consented still sees the consent screen. A user
who declines consent keeps every local feature (PD-011).

Local URL heuristics (`12_SECURITY.md` §9) run for guests, offline, and during
a provider outage. Only the external lookup requires an account.

### 15.2 Dates with no year

Resolve to the next occurrence — this year if the date is still ahead,
otherwise next year — and flag the entity `yearInferred` (PD-025).

The flag never reaches the user as jargon. The reminder confirmation shows the
resolved date in full, and the year is editable before the reminder is created:

```text
Create Reminder

25 September 2027
Time: [ Select time ]

[Cancel] [Create]
```

The user is already on this screen choosing a time (PD-007), so a wrong
inference is visible before it can cause a missed reminder.

### 15.3 Notification permission denied

A reminder and a notification are two different things (PD-026). If the runtime
permission is denied:

- the reminder is still saved;
- Memory Save is never blocked;
- the UI states plainly that notifications are off and offers to enable them;
- the permission prompt is not repeated on every attempt;
- TINDAK never claims an alert will fire when the OS will not deliver one.

```text
Reminder saved

Notifications are off.
TINDAK can't alert you until notifications
are enabled.

[Not Now] [Enable Notifications]
```

Recovery is also reachable from Settings.

### 15.4 Bare domains are not detected in V1

`kedai.my` inside a Malay sentence is not treated as a URL (PD-027). A URL needs
an explicit `http://`, `https://`, or a `www.` prefix. A false action is worse
than a conservative detector; the gap is backlogged as *URL Detection
Enhancement* and revisited with beta data. Specification in `20_TEST_PLAN.md`
§5.

---

## 16. Open items carried to Architecture Lock

Operational configuration is approved as PD-028: tombstone purge 90 days, share
cap 10,000 characters, AI input 2,000 characters, AI 30/day and 5/minute,
timeouts 8s/12s, reputation 60/day, `security_scans` retention 30 days,
SQLCipher deferred.

Remaining:

- **URL reputation provider** — verified against current official
  documentation; see `13_API.md` §5. Safe Browsing is **not usable** by TINDAK.
  Web Risk Lookup API is the recommendation and needs CEO approval.
- Whether Google Sign-In lands in V1 or later (`13_API.md` §1.1).
- Reminders synced to a second device do not fire there in V1
  (`11_DATABASE.md` §2.4) — Product Direction has not yet ruled.
