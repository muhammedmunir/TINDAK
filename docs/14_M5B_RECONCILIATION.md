# 14 — M5b RECONCILIATION

**Owner:** Technical Lead (Claude)
**Status:** APPROVED by Product Direction — D-1…D-5 decided as PD-041…PD-045
**Date:** 2026-09-15
**Inputs:** M5a as merged (`develop` at `7c5fb27`), `10_ARCHITECTURE.md` §8,
`11_DATABASE.md` §2–§3, `12_SECURITY.md` §3 and §5, `13_API.md` §1–§2,
PD-001…PD-040, ADR-013…ADR-030

The Technical Pack designed the cloud schema and sync before any local schema
existed. M5a is now real. This document checks the two against each other, and
against every behaviour the M5b gate names, **before** Supabase holds anyone's
data — because a sync error that reaches the cloud is copied to every device the
user owns.

---

## 1. Verified — no change needed

| Requirement | How the real M5a schema supports it |
|---|---|
| Guest rows stay local until explicit migration | `owner_user_id IS NULL` rows are guest-owned, and the database refuses `sync_status` other than `local_only` for them. A sync that reads only owned, pending rows **cannot** pick up a guest row. |
| Sign-in never silently uploads guest Memories | Follows from the row above: sign-in changes nothing in the database. Only the migration action sets `owner_user_id`. |
| **Bukan Sekarang** leaves guest Memories local | No write happens. Guest rows remain `owner_user_id IS NULL`. |
| Unified Memory and search after sign-in | One visibility predicate: `owner_user_id IS NULL OR owner_user_id = :uid` (`11_DATABASE.md` §3.3). Search already runs locally over all visible rows. |
| Account data structurally distinguishable from guest data | `owner_user_id` set vs null, enforced by a `CHECK`. |
| Identifiers created in M5a remain stable | Client UUIDv4, never re-keyed. Migration is `UPDATE owner_user_id, sync_status`, the same id pushed as-is. |
| Local and cloud 10,000 code-point limits match | SQLite `length(content) <= 10000` and Postgres `char_length(content) <= 10000` both count code points (PD-039). |
| No CRDT | Unchanged; see §3.1 — M5b becomes simpler than designed. |

---

## 2. Technical conflicts — proposed fixes, no product behaviour changes

### 2.1 The device cannot tell whether the server has ever seen a row

**Found:** M5a has `sync_status` (`local_only` / `pending` / `synced`) but no
record of whether a `pending` row has ever reached the server. `pending` means
both "created offline, never pushed" and "tombstoned after being synced".

**Why it matters:** deleting a never-pushed row can be a local hard delete; a
pushed row must become a tombstone (PD-021). Without knowing which, TINDAK
either leaves tombstones the server never needed, or hard deletes a row another
device already has — and that row comes back on the next pull.

**Proposed:** local schema **version 2** adds one nullable column,
`server_updated_at INTEGER` — the server's `updated_at` from the last successful
push or pull. `NULL` means the server has never acknowledged the row.

This is `ALTER TABLE ADD COLUMN`, not a table rebuild. It is the **first real
migration**, so it is tested by opening a real version 1 database file created
by the M5a code and upgrading it, not by creating a fresh version 2.

### 2.2 RLS hole on `memory_entities`

**Found:** the designed policy checks only `auth.uid() = user_id` on the entity
row. An attacker can insert an entity with **their own** `user_id` and a
**victim's** `memory_id`. RLS passes (their own user id) and the foreign key
passes (the memory exists).

**Impact:** limited but real. The victim cannot read the attacker's row, since
it carries the attacker's `user_id`. But the attacker can attach arbitrary rows
to someone else's memory, and learns whether a guessed memory id exists by
whether the foreign key accepts it.

**Proposed:** the insert and update policies also require the parent memory to
belong to the caller:

```sql
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.memories m
    where m.id = memory_id and m.user_id = auth.uid()
  )
)
```

Added to the bypass matrix as **B-13**: insert an entity for another user's
memory — must be refused.

### 2.3 Cloud schema is missing a column and carries one it does not need

| Column | Local | Cloud as designed | Proposed |
|---|---|---|---|
| `intake_source` | yes (PD-033) | **missing** | add, `CHECK (intake_source in ('share','paste'))` |
| `content_tsv` + GIN index | — | present | **drop** — search is local-only (ADR-030, PD-038); a server index nobody queries is storage and write cost for nothing |
| `search_value` on entities | yes | absent | stays local-only; recomputed on pull from `normalized_value` |
| entity `start_offset`, `end_offset` | `NOT NULL` | nullable | make `NOT NULL` in the cloud to match; a null would fail the local constraint on pull |

### 2.4 Timestamps

Local stores epoch milliseconds UTC; Postgres uses `timestamptz`. Converted at
the sync boundary only. `created_at` is the device's save time and is pushed as
given; `updated_at` stays server-set by trigger (ADR-019).

---

## 3. Simplifications the real product allows

### 3.1 Memories are immutable in V1 — conflict resolution nearly disappears

V1 has **no edit** for a saved memory. A memory is created once and can only be
deleted. So the only states a row moves through are:

```text
created ──► (synced) ──► tombstoned ──► purged after 90 days
```

Consequences:

- **No two-sided edit conflict can exist.** Last-write-wins (ADR-019) still
  governs, but in practice resolves only one case: a tombstone always has the
  later `updated_at` than the row it deletes, so **deletion wins**, on every
  device, deterministically.
- Entities never change after the first push, so "replace wholesale" never
  runs twice.
- Pull is "insert rows I do not have, apply tombstones for rows I do".

This is not a new decision — it is what the locked architecture reduces to for
immutable content. **If memory editing is ever added, this section no longer
holds** and conflict handling must be revisited before that feature ships.

---

## 4. Decisions needed — product behaviour, not technical

### D-1. Sign-out would destroy data that never reached the cloud — **serious**

ADR-022 deletes every account-owned row on sign-out and says "the cloud copy is
intact". **That is false for a row that is still `pending`.** A memory saved
while signed in but offline, or a deletion made offline, exists only on the
device. Signing out erases the memory permanently, or loses the deletion, which
then comes back on the next sign-in.

Options:

- **(a) Sync first, then sign out.** Sign-out attempts a push. If anything is
  still unsynced — for instance, offline — tell the user how many items are not
  yet in their account and let them choose to cancel or sign out anyway,
  acknowledging the loss. *Recommended.*
- (b) Block sign-out until everything is synced. Safe, but a user who is offline
  cannot sign out at all.
- (c) Keep unsynced account rows after sign-out. Violates PD-017.

### D-2. Are new saves made while signed in synced automatically?

PD-016 covers guest items existing **before** sign-in. It does not say what
happens to a memory saved **after** signing in. Syncing it automatically is
what "enable cloud sync" means to most users, but it is content leaving the
device without a per-item decision, so it needs to be stated.

Recommendation: yes — being signed in is the user's choice to sync. Each save
still requires pressing Simpan (PD-003).

### D-3. Where does "enable sync later" live after **Bukan Sekarang**?

PD-016 says a user who chose Bukan Sekarang "may enable sync later". That needs
a place in the app. The only candidate is a minimal Settings screen (UX §25:
Account, Cloud Sync) — which is also the only natural place for **sign in** and
**sign out**, since M1–M5a have no account entry point at all.

Needs a ruling on the minimum M5b Settings: proposed **Account** (sign in / sign
out) and **Cloud Sync** (count of items on this device only, with a Sync
action). Nothing else.

### D-4. Migration prompt wording

The gate specifies `Sync 40 saved items to your account?` with
`[Bukan Sekarang] [Sync]`. The title is English while the first button is
Malay, and every other screen since PD-037 is Malay. A Malay title and a Malay
or deliberate-English "Sync" label need Product Direction's call. The count is
generated dynamically either way.

### D-5. Guest items on a shared device

Guest rows belong to the device, not a person. If two people sign in on the
same phone at different times, whoever signs in first and chooses Sync takes
all guest items into their account. Probably acceptable for V1 — flagged so it
is a decision, not an accident.

---

## 5. What the CEO needs to provide or allow

### 5.0 Resolved by the CEO, 2026-09-15

| Item | Decision |
|---|---|
| Supabase project | Provided. Reachable, key valid, database empty at start of M5b. |
| Local Supabase / Docker | **Not used.** Migrations and security tests run on the online project. |
| How migrations run | Claude writes SQL files; the CEO pastes each into the SQL Editor. No database password or access token is shared. |
| Environments | **One Supabase project for everything** — development, testing and real users. Accepted with its consequence: every migration and security test runs against the only database, so the RLS test script is built to be safe there. |
| GitHub repository | `github.com/muhammedmunir/TINDAK`, **public**, pushed by the CEO. Git history scanned before the first push: no keys, tokens or project URL committed. |

Remaining from the original list:

| Item | Why | When |
|---|---|---|
| A Supabase project, and its URL and anon key | Auth and sync have nowhere to run otherwise. The CEO owns credentials (master plan §1). | Before implementation |
| Permission to start Docker Desktop and run the Supabase CLI via `npx` | RLS bypass tests (B-1…B-13) run against a local Supabase, never the real project. Docker is installed but not running. | Before implementation |
| Acceptance that Supabase's built-in email sender is for alpha only | Its default SMTP is heavily rate-limited. Fine for Founder Alpha; a custom SMTP provider is needed before closed beta. | Before closed beta |
| Awareness that M5b adds the `INTERNET` permission | The first network permission TINDAK requests. The Play Data Safety declaration changes with it. | At M5b release |

`flutter_secure_storage` arrives with M5b for the session (ADR-020,
`12_SECURITY.md` §4.2). No other new dependency beyond `supabase_flutter`.

---

## 6. Proposed M5b order

Progress as of 2026-09-15 (after PD-041…PD-045):

- **Done in code, tested locally:** steps 1, 2, 4–7. Three migrations as SQL
  files; email OTP sign-in; sync engine; guest migration prompt; minimal
  Settings; fail-safe sign-out. 498 automated tests pass. Implementation details
  proposed as ADR-032.
- **Emulator:** the v1→v2 upgrade ran on a real M5a install with data intact;
  Home and Settings render with cloud configuration.
- **Waiting on the CEO:** running the three migrations and the RLS test script,
  the Supabase OTP email template, and a real sign-in with a code from email.
  Step 3 and step 8 cannot finish without these.

Original order:

1. Local schema v2 (`server_updated_at`) with an upgrade test from a real v1 file.
2. Supabase migrations: schema as reconciled in §2.3, RLS with the §2.2 fix,
   tombstone purge job.
3. RLS bypass matrix B-1…B-13 against local Supabase, results recorded in
   `20_TEST_PLAN.md`.
4. Email OTP sign-in, session in secure storage.
5. Sync engine: push pending, pull since cursor, tombstones, resume after
   offline.
6. Guest migration prompt and minimal Settings (per D-3, D-4).
7. Sign-out per D-1.
8. Emulator and physical-device verification.

Nothing in this order starts before §4 is answered, because D-1 and D-3 change
what steps 6 and 7 build.
