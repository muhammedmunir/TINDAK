# 16 — M7 PLAN: Reminder

**Owner:** Technical Lead (Claude)
**Status:** PROPOSED — awaiting Product Direction review. No code written.
**Baseline:** `develop @ c65b430`
**Inputs:** M7 Product Direction Brief (2026-09-16), ADR-008, ADR-018, ADR-021,
ADR-024, ADR-031, PD-003, PD-007, PD-017, PD-021, PD-025, PD-026, PD-031,
`10_ARCHITECTURE.md` §15.2–§15.3 and §16, `11_DATABASE.md` §2.4, `03_UX_FLOWS.md`
§8

---

## 1. Reconciliation — the brief against what is built

| Brief requirement | State on `develop` | Work needed |
|---|---|---|
| Only an explicit Ingatkan creates a reminder | `ActionKind.remind` exists and does nothing (M6b) | replace the placeholder |
| A date with no time asks for one | PD-007, UX §8 | time picker, no default |
| Past date and time refused | nothing yet | validation plus copy (B-3) |
| Permission asked in context; refusal keeps the reminder | PD-026, UX §15.3 | permission gateway, notification state in Settings |
| Local-first, survives restart and reboot | ADR-008 | scheduler adapter, reboot receiver, reconciler |
| No exact-alarm permission | ADR-024 | inexact allow-while-idle only |
| At most one active reminder per Memory | nothing yet | partial unique index (§4.1) |
| Creating a reminder saves an unsaved Memory | save is explicit (PD-003) | implicit save inside one transaction (§4.6) |
| Deleting a Memory cancels its reminder | delete exists; no reminders yet | cascade plus OS cancel (§4.7) |
| Sign-out cancels account reminders on the device | ADR-031 purges memories | extend the purge (§4.8) |
| Guest → account migration keeps reminders | `migrateGuestRows` moves memories | move reminders with them (§4.9) |
| A synced reminder does not fire on a second device | PD-031, `11_DATABASE.md` §2.4, open item O-4 | **needs a ruling — B-5** |
| Offline throughout | scheduling is local; no network involved | nothing |
| No recurring, snooze, FCM, cross-device, calendar, AI or natural-language time | — | scope lock, enforced by the action-kind guard test |

**Two new dependencies will be needed at implementation:**
`flutter_local_notifications` (ADR-008) and `timezone` (`10_ARCHITECTURE.md`
§12 lists both, so neither is a new decision). Nothing is added during planning.

**A local schema change will be needed:** version 3 adds a `reminders` table.
The cloud table is already designed (`11_DATABASE.md` §2.4) but is only written
if B-5 says reminders sync.

---

## 2. Gate split

- **M7a — Domain and persistence.** Schema v3, the reminder model and
  repository, the one-active-reminder rule, implicit save, delete and sign-out
  coupling, guest migration, the scheduler **interface** with a fake
  implementation, and the reconciler. No plugin, no permission, no Android
  manifest change. Everything testable on the Dart VM.
- **M7b — Android delivery and UX.** The plugin adapter, the notification
  permission, the boot receiver, the time picker and confirmation screen, the
  notification tap route, Settings state, and emulator and device verification.

Splitting here means the rules that can lose a user's reminder are tested
without an emulator, and the Android work is a thin, visible adapter.

---

## 3. What M7 must not become

No repeating reminders, no snooze, no server push or FCM, no cross-device
firing, no calendar integration, no AI, no natural-language time
(`esok`, `pukul 3`), no exact alarms, no full-screen intents, no foreground
service.

---

## 4. Technical proposal

### 4.1 Local schema, version 3

```text
reminders
  id                TEXT PK        client UUIDv4
  memory_id         TEXT NOT NULL  → memories(id) ON DELETE CASCADE
  owner_user_id     TEXT NULL      null = guest, mirrors memories
  remind_at         INTEGER        epoch ms, the resolved instant
  local_date        TEXT           'YYYY-MM-DD' as the user chose it
  local_time        TEXT           'HH:MM' as the user chose it
  time_zone         TEXT           IANA zone at creation, e.g. Asia/Kuala_Lumpur
  status            TEXT           scheduled | fired | cancelled
  notification_id   INTEGER UNIQUE device-local Android id, never synced
  created_at        INTEGER
  updated_at        INTEGER
  deleted_at        INTEGER NULL
  sync_status       TEXT           local_only | pending | synced
  server_updated_at INTEGER NULL
```

- **One active reminder per Memory** is a partial unique index on `memory_id`
  where `status = 'scheduled' AND deleted_at IS NULL`. A rule the database
  enforces cannot be broken by a race between two taps.
- `local_date`, `local_time` and `time_zone` are kept **alongside** the instant
  because they answer a question the instant cannot: what the user actually
  chose. That is what makes the timezone decision in B-2 implementable either
  way, and it costs three columns.
- `notification_id` is an Android integer id and is **device-local**. It is
  never synced: two devices would otherwise fight over the same value.
- The same ownership and sync columns as `memories`, so a reminder can follow
  its Memory through guest migration, sync and sign-out without new machinery.

Migration v2 → v3 is `CREATE TABLE` plus the index. No existing table changes,
so no rebuild and no risk to saved Memories.

### 4.2 Scheduling, without exact alarms

`flutter_local_notifications.zonedSchedule` with
`AndroidScheduleMode.inexactAllowWhileIdle` (ADR-024). No
`SCHEDULE_EXACT_ALARM`, no `USE_EXACT_ALARM`. Android may deliver a few minutes
late, and Doze may delay it further; a bill reminder tolerates that, and the UI
never promises to the minute.

The plugin sits behind an interface:

```text
ReminderScheduler
  schedule(id, at, payload) -> bool
  cancel(id)
  pending() -> list of ids
```

The domain layer talks only to that interface, so every rule below is tested
with a fake scheduler and a pinned clock, with no emulator.

### 4.3 Surviving restart and reboot

Two independent mechanisms, because either alone has a hole:

1. **The plugin's boot receiver** (`RECEIVE_BOOT_COMPLETED` plus the
   plugin's `ScheduledNotificationBootReceiver`) restores alarms Android drops
   at reboot.
2. **A reconciler on every app start and resume**, which compares the database
   with `pending()`:
   - a `scheduled` row with no OS alarm is rescheduled;
   - an OS alarm with no row is cancelled;
   - a `scheduled` row whose time has passed is marked `fired` (§4.11).

The database is the source of truth; the OS scheduler is a cache of it. Force
stop, a plugin upgrade, a failed reboot receiver and a restored backup all end
up in the same state.

### 4.4 Notification permission, Android 13+

Asked **at the moment the user creates their first reminder**, never at launch.
If refused (PD-026): the reminder is still created, Memory Save is never
blocked, the confirmation says plainly that notifications are off and offers to
enable them, the prompt is not repeated on every attempt, and TINDAK never
claims an alert will fire. Recovery lives in Settings next to Akaun and Cloud
Sync. Whether such a reminder is still called "scheduled" is B-1.

### 4.5 Writing to two systems that cannot share a transaction

SQLite and the Android scheduler cannot commit together, so the order is fixed
and the gap is made recoverable:

```text
insert row (status scheduled)  ─► commit  ─► schedule with the OS
        │                                          │
        │                                    failure: leave the row,
        │                                    reconciler retries
   failure: nothing scheduled, nothing shown
```

The row is written first. A reminder that exists without an alarm is repaired
by the reconciler; an alarm without a row is cancelled by it. The reverse order
could fire an alarm for a reminder the user never got.

### 4.6 Creating a reminder on an unsaved result

Ingatkan on a share or paste result saves the Memory first, in the same
transaction as the reminder. This is not a weakening of PD-003: the user pressed
a button that only makes sense for something kept, so the intent is explicit.
The confirmation should say the item was saved too — copy in B-6.

### 4.7 Delete and cancel

Deleting a Memory cancels its reminder: the row goes by foreign-key cascade for
a guest item, or is tombstoned with the Memory for an account item, and the OS
alarm is cancelled in both cases. A tombstoned reminder is never rescheduled by
the reconciler. Cancelling a reminder on its own leaves the Memory untouched.

### 4.8 Sign-out

ADR-031's purge extends: cancel the OS alarms for account-owned reminders, then
purge those rows with the account's memories, before the session ends. Guest
reminders are untouched. If reminders sync (B-5), the same "nothing pending"
rule applies to them as to memories.

### 4.9 Guest → account migration

`migrateGuestRows` also moves reminders whose Memory moved: owner set, status
untouched, `notification_id` untouched. Nothing is rescheduled, because it is
the same device and the alarm is already there.

### 4.10 Tapping a notification

The payload is the memory id and nothing else — no content, no phone number.
Tapping opens that Memory's detail screen. Two entry paths: a warm tap through
the plugin callback, and a cold start through
`getNotificationAppLaunchDetails()`. Both push the existing `/memory` route, so
Navigator 1.0 stands (ADR-018) and no deep link or app link is introduced.

### 4.11 Timezone and clock changes

Because the row keeps both the instant and the chosen wall-clock time, the
reconciler can detect that the device's zone has changed since creation and act
on whichever rule Product Direction picks in B-2. A device clock moved forward
is handled by the reconciler's "passed" rule; a clock moved backward leaves the
alarm where it is.

### 4.12 Duplicate alarms

Three guards: the partial unique index (§4.1), a stable `notification_id` per
reminder so rescheduling replaces rather than adds, and the existing in-flight
guard in `ActionRunner` so a double tap is one action.

### 4.13 Test strategy

- **VM tests, no emulator:** a `FakeScheduler` recording schedule and cancel
  calls, plus `FixedClock`. Covers one-active-reminder, implicit save, delete
  and cancel coupling, sign-out purge, migration, reconciler repair in both
  directions, past-time refusal, permission-refused path, and the notification
  payload carrying no content.
- **Emulator:** real delivery with a reminder a minute or two ahead, permission
  granted and denied, reboot (`adb reboot`) and force stop, notification tap
  from cold start, and timezone change (`adb shell setprop persist.sys.timezone`).
- **Device (CEO):** one real overnight reminder, because Doze behaviour is not
  faithfully reproduced on an emulator.

---

## 5. Ambiguities for Product Direction

Implementation does not start until these are answered.

**B-1 — What is a reminder whose notification permission was refused?**
PD-026 says it is kept. Options: (a) status stays `scheduled`, and the UI says
notifications are off wherever it appears; (b) a separate visible state such as
"Peringatan disimpan, notifikasi dimatikan". **Recommendation: (a)** with the
Settings recovery, so there is one status vocabulary.

**B-2 — Timezone change after a reminder is created.** A reminder set for
09:00 on 25 September in Kuala Lumpur, with the user then in Jakarta: does it
fire at the original instant (08:00 local there) or at 09:00 local? Options:
(a) **fixed instant** — simple, matches "the moment I chose"; (b) **wall clock**
— fires at 09:00 wherever the user is, matching how people think about "9am
tomorrow". **Recommendation: (b)**, since a bill reminder is a time of day, not
an instant; the schema supports either.

**B-3 — Refusing a past time.** The brief rejects past date and time. Needed:
the exact words, and whether the picker should prevent the choice or refuse it
afterwards. **Recommendation:** prevent — today's past hours are simply not
selectable, so there is nothing to refuse and no error to write.

**B-4 — Is a fired reminder still visible?** Once it fires, does the Memory
show "Peringatan telah berlalu", or does the reminder disappear from the
detail screen? **Recommendation:** show it as past; a disappearing reminder
looks like a bug.

**B-5 — Do reminders sync at all in M7?** This is the open item O-4 that
Product Direction has not yet ruled. Options: (a) **device-local only in M7** —
no cloud table, no migration, no RLS work, and nothing that can mislead a user
into thinking a second device will alert them; (b) **sync as a record** per
`11_DATABASE.md` §2.4, knowing it cannot fire elsewhere in V1.
**Recommendation: (a) for M7**, with (b) revisited when a second device is
actually supported. It removes an entire cloud surface from this milestone.

**B-6 — Copy needed.** The confirmation screen (UX §8 has an English sketch),
the notification title and body, the notifications-off explanation, the implicit
save wording, and the cancel action. **Recommendation for the notification
itself:** title `Peringatan TINDAK`, body the Memory's first line **only if**
Product Direction accepts that it appears on the lock screen; otherwise a
generic body and the content behind the tap. This is a privacy decision, not a
technical one.

**B-7 — A second reminder on the same Memory.** With one active reminder
allowed: does Ingatkan on a Memory that already has one **replace** it, or is
it refused? **Recommendation: replace**, after showing the existing time, since
refusing leaves the user to hunt for a cancel button first.

---

## 6. Order of work, once approved

1. **M7a:** schema v3 and its migration test, reminder model and repository,
   one-active-reminder rule, implicit save, delete, cancel, sign-out and
   migration coupling, scheduler interface, reconciler, full VM test suite.
   Report and stop.
2. **M7b:** plugin adapter, permission gateway, boot receiver, time picker and
   confirmation, notification tap route, Settings state, emulator and device
   verification. Report and stop for the M7 gate.

New dependencies arrive only in M7b, and only the two the architecture already
names.
