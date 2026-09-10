# 12 — SECURITY

**Owner:** Technical Lead (Claude), acting as Security Reviewer
**Approval:** CEO — Architecture Lock
**Status:** PROPOSED

Guest-first and local-first (PD-001, PD-005) moved a real amount of user data
onto the device, where RLS cannot protect it. That shift is the reason this
document is longer than the master plan anticipated.

---

## 1. What we are protecting

| Asset | Where it lives | Worst case |
|---|---|---|
| Memory content — bills, addresses, phone numbers, private messages | device SQLite; Supabase when synced | disclosure |
| Account session token | device secure storage | account takeover |
| Gemini and reputation-provider API keys | Supabase Edge Function secrets | billing theft, quota exhaustion |
| Supabase service-role key | Supabase only, never shipped | total data compromise |
| Cross-user isolation | RLS policies | one user reads another's memories |
| Analytics stream | `usage_events` | leaking shared content through telemetry |

---

## 2. Threat model

| # | Threat | Control | Residual |
|---|---|---|---|
| T-1 | User B reads User A's cloud memories | RLS on every table, `auth.uid() = user_id`, tested by §3.3 | none if tests pass |
| T-2 | Client forges `user_id` on insert | `with check (auth.uid() = user_id)` on insert **and** update | none |
| T-3 | API key extracted from the APK | no secret key ever ships; all providers behind Edge Functions (master plan §17, AI Rule 9) | anon key is public by design and RLS-scoped |
| T-4 | Device lost or stolen | Android file-based encryption while locked; `allowBackup=false`; sign-out purge | unlocked device gives an attacker the app itself — see §4 |
| T-5 | App-data exfiltration via cloud backup | `allowBackup=false` + `dataExtractionRules` excluding the database | none |
| T-6 | Hostile app sends a huge or crafted share payload | 10,000-char cap, no HTML/JS rendering, text is never `eval`'d | none |
| T-7 | USSD or dialer injection through a detected "phone number" | strict sanitisation before building `tel:` (§7) | none |
| T-8 | Abuse of AI or reputation endpoints | JWT required, per-user quota, input cap, timeout | a signed-in abuser is rate-limited and identifiable |
| T-9 | Shared content leaking into telemetry | database-level `check` constraint (`11_DATABASE.md` §2.6) | none |
| T-10 | Shared content leaking into logs or crash reports | no content logging in release; no crash SDK in V1 | none |
| T-11 | Account data readable after sign-out | purge account-owned rows on sign-out (§5) | none |
| T-12 | Malicious link opened from TINDAK | scheme allowlist; manual Security Check; failure never reads as safe | user may still tap Open Anyway — by design |
| T-13 | Rooted device or device-level malware | out of scope for V1; see §4 | accepted, documented |

---

## 3. Row Level Security

RLS is a release blocker (master plan §22). It gates M5b, not M5a.

### 3.1 Enable

```sql
alter table public.profiles        enable row level security;
alter table public.memories        enable row level security;
alter table public.memory_entities enable row level security;
alter table public.reminders       enable row level security;
alter table public.security_scans  enable row level security;
alter table public.usage_events    enable row level security;
```

No table is left out. A table created later without RLS is a release blocker on
its own.

### 3.2 Policies

The same shape on every user-owned table:

```sql
create policy memories_select on public.memories
  for select using (auth.uid() = user_id);

create policy memories_insert on public.memories
  for insert with check (auth.uid() = user_id);

create policy memories_update on public.memories
  for update using (auth.uid() = user_id)
              with check (auth.uid() = user_id);

create policy memories_delete on public.memories
  for delete using (auth.uid() = user_id);
```

Three details that are easy to get wrong and are the reason T-2 exists:

- `update` needs **both** `using` and `with check`. With only `using`, a user
  can update their own row and set `user_id` to someone else's, handing the row
  away.
- `insert` has no `using` clause — `with check` is the whole control.
- `profiles` compares `auth.uid() = id`, not `user_id`.

`usage_events` gets insert and select for the owner only; no update, no delete.
Telemetry the user can rewrite is not telemetry.

### 3.3 Bypass tests — all must fail to gain access

"RLS enabled" is not evidence. These run against a local Supabase and their
output is recorded in `20_TEST_PLAN.md`.

| # | Attempt | Expected |
|---|---|---|
| B-1 | User A's JWT selects User B's memory by id | 0 rows |
| B-2 | Anon key with no JWT selects `memories` | 0 rows |
| B-3 | User A inserts a row with `user_id` = User B | rejected |
| B-4 | User A updates their own row, setting `user_id` = User B | rejected |
| B-5 | User A deletes User B's row by id | 0 rows affected |
| B-6 | User A reads `memory_entities` belonging to User B | 0 rows |
| B-7 | User A reads B's rows through a nested select on `memories` | 0 rows |
| B-8 | Expired JWT on any table | rejected |
| B-9 | `usage_events` insert with a content-bearing `props` | rejected by the check constraint |
| B-10 | `usage_events` insert with `user_id` = User B | rejected |
| B-11 | Direct PostgREST call bypassing the Flutter client entirely | same as B-1…B-10 |
| B-12 | Enumerate `auth.users` from the client | not exposed |

A release cannot proceed with any of these unresolved.

---

## 4. Local data protection

### 4.1 No SQLCipher in V1 — deferred, approved (PD-028, ADR-021)

The honest version: SQLCipher's key has to live on the same device as the
database. It is stored in Keystore-backed secure storage, and code running as
the app — or as root — can ask for it. Against the attackers that actually
reach a phone, it buys less than it appears to.

What genuinely helps, and is proposed instead:

```xml
android:allowBackup="false"
android:fullBackupContent="false"
android:dataExtractionRules="@xml/data_extraction_rules"
```

- Android file-based encryption already protects app storage while the device
  is locked.
- `allowBackup=false` stops the database being copied into the user's Google
  Drive backup or pulled over `adb backup` — the realistic exfiltration path,
  and the one that silently ships private memories off the device.
- Sign-out purge (§5) removes account-owned data at the moment it stops being
  the current user's.

### 4.1.1 Residual risk — accepted for V1

Stated plainly, because deferring SQLCipher was approved on the condition that
the risk is documented rather than glossed:

| Attacker | Reaches the database? | Note |
|---|---|---|
| Someone holding an **unlocked** device | **Yes** | They can also just open TINDAK. Encryption changes nothing here. |
| Someone holding a **locked** device | No | Android file-based encryption protects app storage while locked. |
| `adb backup` / cloud backup extraction | No | Blocked by `allowBackup=false` and the extraction rules. |
| Another app on a non-rooted device | No | Android app sandbox. |
| **Root or device-level malware** | **Yes** | And it would also reach a SQLCipher key held in Keystore-backed storage. |
| Forensic extraction of a powered-off device | Depends on the OEM and Android version | Outside what an app can control. |

What this means in product terms: TINDAK's local database is as protected as the
device's own lock screen, and no more. That is an appropriate baseline for the
data V1 holds — shared messages, bills, phone numbers, links.

**Revisit trigger.** If Memory ever holds credentials, identity documents, or
financial account details, this decision is reopened before that feature ships.
V1 scope excludes all three.

**Alternative, if the CEO wants it anyway:** SQLCipher via
`sqlcipher_flutter_libs`, key generated on first launch and held in
`flutter_secure_storage`. Costs a larger APK, a key-loss failure mode that
destroys the user's guest data with no recovery, and a slower cold start. My
recommendation is to defer it. Proposed as ADR-021.

### 4.2 Session storage

The Supabase session persists in `flutter_secure_storage` (Keystore-backed), not
the default SharedPreferences. Refresh tokens sitting in plaintext preferences
are the single most common Flutter auth mistake.

---

## 5. Sign-out

PRD §3 requires that account-owned data is not normally readable after sign-out.
"Not normally readable" is too soft to implement, so the concrete proposal:

```text
Sign out
   │
   ├─ delete every local row where owner_user_id IS NOT NULL
   ├─ clear the pull cursor and sync metadata
   ├─ clear the session from secure storage
   └─ cancel scheduled notifications belonging to those reminders

Guest rows (owner_user_id IS NULL) are untouched.
```

Deletion, not encryption. There is no key to lose and nothing to un-forget, and
the cloud copy is intact — signing back in re-pulls it.

One case needs UX copy: memories that a guest created and later chose to sync
(PD-016) become account-owned, so they leave the device on sign-out. The
confirmation dialog must say how many items will be removed from the device and
that they remain in the account. UX §13 already anticipates this.

**Proposed as ADR-022.**

---

## 6. Secrets

```text
Flutter  ──►  Supabase Edge Function  ──►  External provider
                    (holds the key)
```

Never:

```text
Flutter  ──►  secret key  ──►  External provider
```

| Value | Where | Shipped in APK |
|---|---|---|
| `SUPABASE_URL` | build config | yes — public |
| `SUPABASE_ANON_KEY` | build config | yes — public by design, RLS-scoped |
| `GEMINI_API_KEY` | `supabase secrets set` | **never** |
| `URL_REPUTATION_API_KEY` | `supabase secrets set` | **never** |
| service-role key | Supabase only | **never** — not even in Edge Function code that returns data to a client |

`.gitignore` already blocks `.env`, keystores, `key.properties` and
service-account JSON. `.env.example` documents the split. A secret that reaches
a commit is treated as compromised and rotated, not deleted from history and
forgotten.

---

## 7. Android intent hardening

Both controls in this section are **required safety requirements with mandatory
tests** (PD-029), not hardening that can be trimmed under schedule pressure.
The tests live in `20_TEST_PLAN.md` §2.2 and §7.1.

**Phone numbers into `tel:`.** A detected "phone number" is attacker-controlled
text — it arrived from whatever app did the share. Before it becomes a URI:

- strip everything except digits and a single leading `+`;
- reject anything containing `#` or `*` — this is what stopped `tel:` URIs
  triggering USSD codes such as a factory reset on some devices;
- reject if the result is not a valid Malaysian number per the detector rules;
- URL-encode, and pass through `url_launcher`, never a raw string concatenation.

**URL opening.** Allowlist `http` and `https` only. `javascript:`,
`intent:`, `file:`, `content:` and everything else is refused. TINDAK detects
only HTTP/HTTPS URLs (PRD §6), so anything else reaching the executor is a bug
or an attack.

**WhatsApp.** Built as `https://wa.me/<E.164 digits>` — no free text
interpolated into the link.

**The share activity is exported.** It has to be; that is how Android delivers
shares. Its only input is `EXTRA_TEXT`, treated as untrusted text, capped at
10,000 characters, rendered as plain text in a `Text` widget. No WebView
anywhere in V1.

**`android:usesCleartextTraffic="false"`.** Supabase and every provider are
HTTPS. A detected `http://` link opens in the browser, which is the browser's
decision, not ours.

---

## 8. AI privacy

Consent is required before the first cloud call (PD-011) and is recorded
locally. Declining leaves every local feature working.

- Only the shared text of the current item is sent. Never the Memory list, never
  other memories, never contacts.
- The Edge Function does not persist the prompt or the response. No transcript
  table exists in the schema, and none should be added without CEO approval.
- The consent screen states plainly that content may be sent to an AI provider
  (UX §20).
- Consent is revocable in Settings; revoking stops future calls.
- Guests cannot reach the AI path at all — see the escalation in
  `10_ARCHITECTURE.md` §15 E-1.

---

## 9. URL reputation privacy

Sending a URL to a third party tells that third party what the user is about to
open. This is why PD-012 makes the check manual and why the automatic version
was rejected — an automatic check would leak every shared URL to a vendor.

- Local heuristics run first, on device, with no network. They cover the cheap
  signals: punycode and mixed-script hosts, raw IP hosts, credentials in the
  URL, excessive subdomain depth, known URL-shorteners, a lookalike host with a
  brand name in the path.
- The external lookup happens only on the explicit tap.
- The first external check shows the same kind of disclosure as AI consent.
- `security_scans` rows expire after 30 days (`11_DATABASE.md` §2.5).
- Provider failure never renders as safe (UX §23).
- The recommended provider is **Google Web Risk**, not Safe Browsing — Safe
  Browsing's terms forbid revenue-generating use, and TINDAK plans a paid tier.
  Verified against current official documentation in `13_API.md` §5.
- Web Risk's Lookup API receives the full URL. Its Update API would keep a local
  hash list and leak far less, at materially higher complexity and cost; it is
  recorded as a future privacy improvement, not V1.

---

## 10. Edge Function controls

Both functions require a verified JWT. Neither accepts an anonymous call.

| Control | Proposal |
|---|---|
| Auth | `verify_jwt = true`; `user_id` taken from the token, never from the body |
| Input cap | 2,000 characters for AI; a single URL for reputation |
| Per-user quota | 30 AI calls/day, 60 reputation calls/day |
| Burst | 5 calls/minute per user |
| Timeout | 8s upstream, 12s client |
| Response | validated against a fixed JSON schema before it reaches the UI |
| Failure | returns a typed error; the UI keeps the shared content (UX §21) |

Approved as PD-028. Quota is counted in Postgres against the calling `user_id`,
so it cannot be reset by reinstalling the app. Rationale in `13_API.md` §4.

A guest has no JWT and therefore reaches neither function. Product Direction
approved showing the control with a sign-in prompt rather than hiding it, and
kept sign-in and AI consent as two separate gates (PD-023, PD-024).

---

## 11. Logging

No shared content, no memory content, no detected entity values, no tokens in
release logs. Detector debugging happens in unit tests, where the input is a
fixture and not a real person's message.

No crash-reporting SDK in V1 — adding one is a new external service (AI Rule 7)
and crash payloads are exactly where private strings escape.

---

## 12. Privacy checks before release

- Shared text never appears in `usage_events` — verified by B-9, not by reading
  the client code.
- No analytics for guests, at all (PD-022).
- Deleting a memory removes its entities and its cloud row, leaving only the
  tombstone.
- Uninstall removes local data; the guest-data disclosure in UX §12 is present.
- The app requests no permission before the feature that needs it (UX §27).
- The Play Data Safety declaration matches what the app actually sends.

---

## 13. Open items

- **Adopt Web Risk** as the reputation provider — needs CEO approval and a
  Google Cloud billing account before M8 (`13_API.md` §5.2).

Closed: SQLCipher deferred with residual risk documented (§4.1.1, PD-028);
quota and cap numbers approved (§10, PD-028); guests see cloud controls with a
sign-in prompt, with consent as a separate gate (PD-023, PD-024).
