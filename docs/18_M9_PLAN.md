# 18 — M9 PLAN: AI Fallback

**Owner:** Technical Lead (Claude)
**Status:** APPROVED WITH DECISIONS at the M9 plan gate, 2026-09-16 — see
`90_DECISIONS.md`, PD-048 and ADR-033, which answer Q-1…Q-7 in §25 and add the
value/span consistency rule. **M9a is built**; evidence in `20_TEST_PLAN.md`
§9.5. M9b (a real provider) is not authorised and is subject to PD-048.

Where this document and the gate decisions differ, the decisions win: the
secondary CTA proposed in §2 was dropped (Q-2), consent is **not** cleared on
sign-out (Q-3), and agreement between the model's value and TINDAK's own
derivation is required, not merely recommended.
**Baseline:** `develop @ d3dd17b`
**Inputs:** M9 Product Direction Brief (2026-09-16), ADR-005, ADR-006, ADR-011,
ADR-025, ADR-028, PD-002, PD-007, PD-010, PD-011, PD-022, PD-023, PD-024,
PD-025, PD-028, PD-032, PD-047, `10_ARCHITECTURE.md` §3 and §9, `11_DATABASE.md`
§2.5, `12_SECURITY.md` §6 and §11, `13_API.md` §4, `03_UX_FLOWS.md`

---

## 0. The one thing to read first

Research for §16 of the brief turned up a finding that decides M9b, so it goes
at the top rather than buried on page nine.

**Google's Gemini API has a genuine free tier that needs no billing account** —
unlike Web Risk, which is what PD-047 ran aground on. But its terms say, of the
unpaid tier:

> "To help with quality and improve our products, human reviewers may read,
> annotate, and process your API input and output."

and of the paid tier:

> "Google doesn't use your prompts … or responses to improve our products."

TINDAK's input is somebody's WhatsApp message: a bill, an appointment, a phone
number, a bank amount. Sending that to a tier where **human reviewers may read
it and it may train a model** is not a cost decision, it is a product decision,
and it cuts against the thing TINDAK is for.

So M9 has a genuine fork, and Product Direction owns it, not me — it is
**Q-1** in §25. The plan below is written so that the fork can be decided late:
M9a needs no provider at all, and the provider sits behind an abstraction whose
disabled state is a first-class, shipped behaviour (brief §25). If the answer is
"no budget and no training on user content", TINDAK ships M9a and the AI button
says *AI tidak tersedia buat masa ini* — the same shape PD-047 left Protect in,
and not a failure.

---

## 1. Reconciliation — the brief against what is built

| Brief requirement | State on `develop @ d3dd17b` | Work needed |
|---|---|---|
| AI is fallback, never the default pipeline | ADR-006; `UnderstandingEngine` is pure local Dart and nothing calls a model | a second, explicit path off the result screen |
| `[Cuba dengan AI]` on an explicit tap | `IntakeResultScreen` already renders "belum dapat mengenal pasti" (PRD §18) | a CTA beside that message |
| Guest sees the CTA, tapping asks for sign-in | PD-023, and M8 already does exactly this for Protect | reuse the pattern, not the code path |
| Sign-in is not AI consent | PD-024; M8's `OnlineCheckDisclosure` deliberately says it is **not** the AI consent | a second, separate consent record |
| 2,000 code points | `UnderstandingEngine.maxInputLength` is 10,000 **UTF-16 units** on raw input | a different cap, on a different unit, at a different stage — see §5 |
| Structured output only | nothing parses model output today | request/response contract, §6 |
| Allow-listed entity types | `EntityType` already has exactly four values | reuse the enum; the type system becomes the allow-list |
| Existing actions stay the authority | `ActionResolver` + `ActionUriBuilder` refuse anything but their own shapes | reuse unchanged; never bypassed |
| AI never creates a reminder silently | M7's `ReminderSheet` already refuses to invent a time (PD-007) | route AI dates into that same sheet |
| No prompt/response storage | no AI table exists, and M8 set the precedent of not creating one | quota counters only |
| Server-side key, quota, timeouts | `url-check` + `reputation_usage` are a working template | a second function, a second counter, §15 and §18 |
| Provider disable-able server-side | PD-047 already proved this path in production | same shape, deliberately |

**M9a needs no cloud, no schema change, no package and no credential.** M9b
needs one Edge Function, one migration for quota counters, and a provider
decision from Q-1.

---

## 2. Trigger — when `[Cuba dengan AI]` appears (brief item 1, 2)

The brief says the CTA appears when local understanding produced an unknown
result **or** was not sufficient. The first half is a fact TINDAK already knows.
The second half is not, and this is worth being careful about: a rule for "the
local engine probably missed something" is a second detector, written with no
evidence, whose false positives spend the user's quota and send their message to
a third party. Building one would quietly undo ADR-006.

So the proposal is to use the fact TINDAK has, and let the user supply the
judgement TINDAK does not have:

```text
UnderstandingResult.entities.isEmpty
        │
        ├── yes ──► the existing "belum dapat mengenal pasti" message,
        │           with [Cuba dengan AI] directly beneath it — prominent
        │
        └── no  ──► entities and their actions render exactly as today,
                    with a quiet secondary link at the bottom of the list
```

Secondary-link copy, proposed:

> **Ada maklumat lain dalam teks ini? Cuba dengan AI**

Both are taps. Neither fires on render, on resume, on save, or on detection.
There is no automatic fallback, no retry-with-AI on a low-confidence result, and
no "AI mode" to leave switched on. `Call 012-3456789` is understood locally and
**no AI call is possible on that screen without the user pressing the link**.

Where the CTA does *not* appear at all in M9a:

- Memory detail (a saved memory was already understood once; re-processing it is
  a separate product decision);
- Home, Settings, Search;
- anywhere a share arrives while TINDAK is closed — the CTA lives on the result
  screen, which the user is already looking at.

**Q-2** in §25 asks Product Direction to confirm the secondary link, or to drop
it and ship zero-entity only.

---

## 3. Gates — auth, then consent (brief item 3)

One function answers "may anything be sent, and if not, why not", and it is
asked **before** any text is prepared, let alone sent. This is the shape M8
proved (`SecurityChecker.onlineBlocker`), and it is reused deliberately:

```dart
enum AiBlocker { notConfigured, signInRequired, consentRequired }

Future<AiBlocker?> blocker();   // null means every gate is open
```

Order, and why:

```text
1. provider configured?   no ──► notConfigured   "AI tidak tersedia buat masa ini."
2. signed in?             no ──► signInRequired  sign-in prompt (PD-023)
3. consent accepted?      no ──► consentRequired the one-time disclosure (PD-011)
4. within 2,000 points?   no ──► tooLong         refused locally, nothing sent
                          ↓
                      the request
```

`notConfigured` is checked first so that a build with no AI never asks a guest
to sign in for something that would not work anyway — a sign-in prompt is a
promise, and TINDAK should not make one it cannot keep.

Sign-in is not consent (PD-024): a user who signs in at step 2 still meets the
disclosure at step 3, in the same tap sequence, and may still say Batal.

Declining either leaves the screen exactly as it was — the text, the local
result, Simpan, and every existing action (PD-011).

---

## 4. Consent — wording, storage, and reset (brief item 4)

The brief's copy is approved as-is and lives in one `AiCopy` class, the same way
`SecurityCopy` holds every word Protect shows:

> **Bantu fahami dengan AI**
>
> TINDAK akan menghantar teks yang anda pilih kepada perkhidmatan AI untuk
> membantu mengenal pasti maklumat dan tindakan yang berkaitan. Jangan hantar
> maklumat yang anda tidak mahu diproses oleh perkhidmatan AI.
>
> **[Batal] [Teruskan]**

Storage mirrors `OnlineCheckDisclosure`: one row in the local `sync_meta` table,
key `ai.consent_accepted`, written **only** on Teruskan.

```text
Batal     → nothing written, nothing sent, sheet appears again next time
Teruskan  → row written, then and only then may a request be built
```

It is a separate key from `protect.online_disclosure_accepted`, and neither
implies the other. Agreeing to send a link to a reputation service is not
agreeing to send the whole message to a model, and M8's code comment already
says so.

Three semantics that need Product Direction, because they are policy, not
engineering:

- **Reset on sign-out.** Recommended **yes**. ADR-022 already clears
  account-owned local state on sign-out; a phone that changes hands between
  accounts should not carry the previous person's agreement. The cost is one
  extra tap for a user who signs out and back in.
- **Withdrawal.** Recommended: a Settings row showing the current state with a
  **Tarik balik** action, which deletes the key. PD-011 requires consent to be
  meaningful, and consent that cannot be withdrawn is not.
- **Not synced.** It is a choice about this device, like M8's. A second device
  asks again.

These are **Q-3** in §25.

---

## 5. The 2,000 limit — which 2,000, measured how (brief item 5)

Three details here are easy to get wrong, and each has a real failure mode.

**Code points, not code units.** Dart's `String.length` counts UTF-16 code
units, so a single emoji counts as two and a message full of them would be
refused at roughly half the stated limit. The brief says *code points*, so the
measure is `text.runes.length`. This gets a test with astral-plane characters.

**The normalised text, not the raw text.** `ContentNormalizer` strips invisible
and bidirectional characters (PD-032). Measuring before it runs would let
padding with zero-width spaces change the answer; measuring after it means the
number counts exactly the characters that would be transmitted.

**Refuse, never truncate.** The brief is explicit and this plan does not soften
it. Over the limit, the CTA is disabled with the approved line:

> **Teks terlalu panjang untuk diproses dengan AI. Had ialah 2,000 aksara.**

Nothing is sent. Simpan still works to the 10,000-character Memory limit, and
every local action still works, because none of them were ever AI-dependent.

The check exists in two places, on purpose: the client so the user is told
before anything happens, and the Edge Function so the server does not depend on
a client's honesty. The Edge Function's answer is the one that binds.

| | Understanding cap (existing) | AI cap (new) |
|---|---|---|
| Value | 10,000 | 2,000 |
| Unit | UTF-16 code units | Unicode code points |
| Measured on | raw input | normalised text |
| Over the limit | analyse the first 10,000, keep the rest displayable and saveable | refuse; send nothing |

---

## 6. The domain model (brief items 6, 7, 8)

The whole M9a design rests on one idea: **the model's output is untrusted input,
exactly like the shared text it came from.** It is parsed, grounded, validated,
and only then allowed to become a `DetectedEntity`. It never arrives as one.

```dart
/// What leaves the device. One field. Nothing else. (brief §15)
final class AiRequest { final String text; }

sealed class AiOutcome {}
final class AiCandidates extends AiOutcome { List<AiCandidate> items; }
final class AiNothingFound extends AiOutcome {}
final class AiUnavailable extends AiOutcome { AiFailure reason; }

enum AiFailure { offline, timeout, quotaDaily, quotaBurst,
                 notAuthenticated, unreadable, unavailable }

/// A claim, not a fact.
final class AiCandidate {
  final EntityType type;   // the allow-list *is* the enum — §7
  final String span;       // verbatim substring of the normalised text
  final String value;      // TINDAK's canonical form, to be re-validated
}
```

`EntityType` is reused, not extended. That is the allow-list enforced by the
compiler: there is no way to express `person`, `flight` or `bank_account` in
this model without a deliberate enum change that shows up in review and breaks
the existing exhaustive `switch`es in `ActionResolver`, `ActionUriBuilder` and
`EntityRow`. A model that returns `"type": "task"` produces an unparseable
candidate, which is dropped.

### 6.1 Span grounding — the anti-hallucination control

Every candidate must carry `span`, and **`span` must occur verbatim in the
normalised text**. TINDAK locates it with `indexOf`; if it is not there, the
candidate is dropped before anything else happens.

This is the single most valuable control in M9a, and it is cheap:

- a fabricated phone number that appears nowhere in the message cannot survive;
- a URL the model invented, or one it lifted from its own instructions, cannot
  survive;
- it yields real `start`/`end` offsets, which `DetectedEntity` requires anyway;
- it makes the highlight the user sees provably part of their own text.

The `value` is separate because it is often *not* in the text: `lusa petang`
grounds on that span while its value is an ISO date. Grounding proves the model
was reading the user's message; validation (§8) proves the value is one TINDAK
can act on. Both must pass.

### 6.2 Response envelope

The provider is asked for JSON against a schema, and the Edge Function returns
TINDAK's own envelope with stable codes, never provider prose:

```json
{ "outcome": "candidates",
  "candidates": [ { "type": "date",  "span": "Jumaat depan", "value": "2026-09-18" },
                  { "type": "money", "span": "RM180",        "value": "MYR18000" } ] }
```

`outcome` is one of `candidates`, `nothing_found`, `quota_daily`,
`quota_burst`, `unavailable`, `unauthenticated`, `invalid_request`. There is no
free text field anywhere in the contract, and no confidence number (§10).

Gemini's structured-output documentation is explicit that schema conformance is
syntactic only — *"always validate values in your application"* and expect
*"schema-compliant but semantically incorrect outputs"*. That is precisely what
§8 is for.

---

## 7. The entity allow-list (brief item 9)

Four types, the same four TINDAK already knows how to act on:

| Type | AI earns its place by | Local engine already handles |
|---|---|---|
| `date` | relative and colloquial forms — `Jumaat depan`, `lusa`, `hujung bulan` | explicit numeric and month-name dates |
| `money` | written amounts — `seribu lima ratus ringgit`, `180 hengget` | `RM`/`MYR` prefixed forms |
| `phone` | numbers written in words or unusual spacing | every Malaysian format in `20_TEST_PLAN.md` §2 |
| `url` | a link written without a scheme in an awkward context | `http://`, `https://`, `www.` |

New types are a separate milestone with their own Product Direction brief, as
the brief requires. Adding one touches the enum, four exhaustive switches, the
action resolver, the URI builder and the test matrix — which is the point: it
cannot be done quietly.

A note on `url`: PD-027 deliberately does not detect bare domains, and M9 must
not become a back door to that decision. An AI `url` candidate whose span has no
scheme and no `www.` is **dropped** in M9a, so `kedai.my` in a sentence stays
undetected whichever path the user takes. **Q-4**.

---

## 8. Validation, per type (brief items 8, 11)

Two layers, and the second one never trusts the first. The Edge Function
validates so a malformed provider response never reaches a phone; the client
validates again so a compromised or changed server still cannot inject an
entity.

Applied to every candidate, in order:

1. `type` parses to a known `EntityType`; otherwise drop.
2. `span` is non-empty and occurs in the normalised text; otherwise drop.
3. neither `span` nor `value` contains a Unicode format character — the same
   `ContentNormalizer.containsFormatCharacter` guard the local engine applies
   twice already (PD-032); otherwise drop.
4. the per-type rule below passes; otherwise drop.
5. the candidate is converted to a `DetectedEntity` with the grounded offsets
   and a fixed confidence (§10).

| Type | Rule |
|---|---|
| `phone` | `value` matches the E.164 shape `ActionUriBuilder` already enforces, `^\+60[1-9]\d{7,9}$`; the span is additionally re-checked against the IC-shape rejection in `PhoneDetector`, so PD-029's guarantee holds on this path too |
| `url` | `Uri.tryParse` succeeds, scheme is `http`/`https`, host is non-empty, contains a dot, and has no empty label — the same predicate as `ActionUriBuilder._openUrl`; plus the PD-027 scheme rule in §7 |
| `money` | `MoneyValue.parse(value)` returns non-null — i.e. exactly `MYR<whole sen>`, non-negative (ADR-023) |
| `date` | `DateValue.parse(value)` returns non-null, which already round-trips through the calendar so `31/02` and a non-leap `29/02` are impossible; plus a sanity window of `now − 1 year … now + 5 years` |

Overlap between candidates, and between a candidate and a local entity, is
resolved by the **existing** `UnderstandingEngine._resolveOverlaps` rules — not
a second set. Where a local entity and an AI candidate cover the same span, the
local one wins, because it is deterministic and reproducible.

Malformed response handling:

- **envelope** fails schema → the whole response is discarded, `AiFailure.unreadable`,
  copy: *AI tidak dapat memproses teks ini. Cuba lagi kemudian.*
- **individual candidate** fails any step → dropped silently; the rest stand.
- **all candidates dropped** → the zero-entity state in §11, not an error. The
  user is told nothing supported was found, which is the truth.

---

## 9. Date and time — a real conflict with PD-007 (brief item 10)

The brief's example output is `18 September 2026, 3:00 PTG`, and its flow shows
the user reviewing a **date/time**. But M6 built `DateValue` with no time of day
at all, and PD-007 says a date without a time asks the user to pick one; M7's
`ReminderSheet` enforces that by keeping **Tetapkan** disabled until a time is
chosen.

There is a real distinction underneath: PD-007 forbids TINDAK *inventing* a
time. A time the model **read out of the user's own message** — `pukul 3
petang`, grounded on that span — is not invented. But acting on it would still
change M7's behaviour, so it is not mine to assume.

Two options, for **Q-5**:

- **(a) Recommended for M9a — date only.** The AI allow-list carries `date`,
  identical to the local type. An AI date opens the existing `ReminderSheet`
  with the time picker empty, exactly as a local date does. Zero change to M7,
  zero risk to PD-007, and `hari Jumaat depan` is still the thing the user could
  not get before.
- **(b) Date plus a grounded time hint.** The candidate carries an optional
  `timeHint`, valid only when its own span appears in the text. The sheet opens
  **pre-filled but still requiring confirmation**, and the pre-filled time is
  shown in full before Tetapkan is pressed. More useful; needs PD-007 amended to
  say "read, never invented, always confirmed", and needs M7's disabled-button
  rule relaxed for this one case.

Whichever is chosen, everything downstream is unchanged: past times are refused
by `ReminderRepository`'s existing `isAfter(_clock.now())` check, PD-025's
year-inference display still applies, and **no reminder is ever created by the
AI path itself** — the user presses Ingatkan, then Tetapkan.

---

## 10. What the user sees (brief items 12, 13)

No percentage, no score, no `AI confidence: 94%`. The result reads like the rest
of TINDAK:

```text
AI menemui:

Tarikh
18 September 2026                    [Ingatkan]

Jumlah
RM180.00                             [Salin]
```

Internally every accepted candidate is given one fixed confidence value so the
existing ranking and overlap rules have something to work with. It is a constant
and it is never displayed — the same discipline as ADR-009, where Protect shows
reasons and refuses to show a number. Proposed value: below every local
detector's minimum, so a local entity always outranks an AI candidate on a tie.

Zero entities is a normal, valid outcome and gets its own line rather than a
hallucinated result:

> **AI tidak menemui tindakan yang disokong dalam teks ini.**

Simpan remains available underneath it, because plain text is still worth
keeping (PRD §18).

---

## 11. The action engines stay the authority (brief item 11, 23)

An accepted candidate becomes an ordinary `DetectedEntity` and then goes through
the paths that already exist, unchanged:

```text
AI phone → ActionResolver → Panggil / WhatsApp → ActionUriBuilder → tel:/wa.me
AI url   → ActionResolver → Buka Pautan → ActionUriBuilder (http/https only)
                          → Semak Keselamatan → M8, unchanged
AI money → Salin → ClipboardWriter
AI date  → Ingatkan → ReminderSheet → M7, unchanged
```

`ActionUriBuilder` is the last line and does not care where an entity came from.
A model that returns `javascript:alert(1)` as a URL is refused twice — once by
§8's scheme rule, once by the builder — and could not have been grounded in the
first place unless the user's own text contained it, in which case M4 refuses it
exactly as it does today.

The model performs nothing. It cannot call, open, send, save, remind or check.
It returns claims; the user presses a button; TINDAK's own executor acts. No
tool use or function calling is enabled on the provider request, and enabling it
would be a Product Direction decision, not an implementation one.

---

## 12. Prompt injection (brief item 22)

The user's text is data. It is never instruction, to the model or to TINDAK.

Controls, each independently sufficient for the common cases:

1. **Separation.** The user's text is never concatenated into the system
   instruction. It travels as its own content part, with the instruction fixed
   in the Edge Function's source — not in the app, not in the request body, and
   not editable by the caller.
2. **Structured output.** The response schema leaves the model nowhere to put
   prose, an instruction, or an extra field.
3. **No tools.** Function calling is off. There is nothing for an injected
   instruction to invoke.
4. **Grounding.** §6.1 — a value the user's text does not contain cannot become
   a candidate, so "return `javascript:alert(1)`" yields nothing.
5. **Validation.** §8 — even a grounded value must pass TINDAK's own rules.
6. **The executor.** §11 — even a validated entity needs a user tap and still
   meets `ActionUriBuilder`.

Prompt injection is a named M9a test category, not an afterthought. The corpus
(§19) includes text that: tells the model to ignore its instructions; embeds a
JSON blob shaped like the response schema; asks for a premium-rate number;
contains a `javascript:` URL; contains an IC number; claims to be a system
message; and contains an instruction in Malay rather than English, since the
input language is Malay and an English-only test proves less than it looks.

---

## 13. The provider seam and the fake (brief items 14, 21)

```dart
abstract interface class AiUnderstandingProvider {
  Future<AiOutcome> understand(String text);
}
```

One implementation in M9b (`EdgeAiProvider`, the only file in `features/ai`
permitted to import Supabase, added to the allow-list in
`layer_purity_test.dart` at that point). In M9a there is **no implementation in
`lib/` at all** — the provider is null, `blocker()` returns `notConfigured`, and
the CTA says *AI tidak tersedia buat masa ini*. That is not a stub; it is
literally the behaviour the brief's §25 cost fail-safe requires, shipped and
tested first rather than bolted on last.

The fake lives in `test/support/`, never in `lib/`. Widget tests drive the whole
M9a surface through it: candidates, nothing-found, every failure, malformed
envelopes, and the adversarial corpus.

That leaves M9a with no way to exercise the UI on a physical device. The options
are a debug-only fake behind `--dart-define` with a `kReleaseMode` guard and a
purity test proving it cannot reach a release build, or accepting that M9a's
device evidence waits for M9b. Recommended: **the second** — M8a shipped without
one and the milestone was still verifiable; a switch that turns on a fake AI in
production is a bigger risk than the gap it closes. **Q-6**.

---

## 14. Exactly what leaves the device (brief item 15)

| Leaves | Why |
|---|---|
| the normalised selected text, ≤ 2,000 code points | it is the thing being understood |
| the Supabase access token, in the `Authorization` header | the function must know whose quota to spend |

Nothing else. Not the memory list, not other memories, not the email, not the
device id, not the phone's locale, not location, not contacts, not the Protect
history (which does not exist), not any surrounding text the user did not
select. The request body is one field, and the Edge Function rejects a body with
any other key — the same rule `url-check` already enforces and that was verified
live in `20_TEST_PLAN.md` §9.4.

The user id is taken from the verified token, never from the body.

---

## 15. Edge Function design for M9b (brief items 15, 17, 18, 19, 20, 21)

`supabase/functions/ai-understand/index.ts`, built on the `url-check` template
because that template has now been tested in production:

```text
POST /functions/v1/ai-understand
  ├─ method is POST                        else 400 invalid_request
  ├─ Bearer token present, auth.getUser()  else 401 unauthenticated
  ├─ body has exactly one key, "text"      else 400 invalid_request
  ├─ text is a string, 1…2000 code points  else 400 invalid_request
  ├─ provider key present?                 else 200 unavailable   ← before quota
  ├─ consume_ai_request(user, 30, 5)       else 429 quota_daily | quota_burst
  ├─ provider call, structured output, AbortController 8s
  ├─ validate the response against the schema; drop bad candidates
  └─ reply with TINDAK's envelope, status codes only in logs
```

The key-before-quota ordering is deliberate and is the lesson PD-047 paid for: a
provider that was never configured must not spend the user's daily allowance.
That property gets its own test.

**Key handling.** The provider key exists in exactly one place — the function's
secrets, set with `supabase secrets set` and never printed, never in
`supabase/.env` beyond the local operator copy, never in `AppConfig`, never in
the APK. `AppConfig`'s doc comment already names a Gemini key as an example of
what must never appear there; this plan keeps that true.

**Disabling the provider** is unsetting one secret, with no redeploy and no app
release. Verified as a real behaviour, not a theory — that is exactly how Web
Risk was switched off at the M8 gate.

---

## 16. Quota — 30/day and 5/minute, atomically (brief item 17)

PD-028's numbers, enforced in Postgres against the token's user, so reinstalling
does not reset them.

```sql
create table public.ai_usage (
  user_id  uuid    not null references auth.users(id) on delete cascade,
  day      date    not null,
  requests integer not null default 0,
  primary key (user_id, day)
);

create table public.ai_usage_minute (
  user_id  uuid        not null references auth.users(id) on delete cascade,
  minute   timestamptz not null,
  requests integer     not null default 0,
  primary key (user_id, minute)
);
```

Both carry RLS **enabled with zero policies**, like `reputation_usage`: no
client has any business reading them, and the function reaches them as
`service_role`. Both are purged on pg_cron — the minute table aggressively,
since a row older than an hour is dead weight.

One function claims both counters **inside a single transaction**, so a burst
refusal cannot spend a daily unit:

```sql
create function public.consume_ai_request(p_user uuid, p_day_limit int,
                                          p_burst_limit int)
returns text            -- 'granted' | 'quota_daily' | 'quota_burst'
language plpgsql security invoker set search_path = ''
```

`security invoker`, locked `search_path`, `execute` revoked from `public` and
`anon` and `authenticated` — the shape `push_memory` and
`consume_reputation_check` already use and that the RLS matrix already tests.
Proving it atomic is the same experiment that proved M8's: N concurrent
attempts against a limit of N−5, counting grants and refusals.

**When quota is exhausted, nothing local stops.** The copy is the brief's:

> **Had penggunaan AI hari ini telah dicapai. Cuba lagi esok.**
> **Terlalu banyak permintaan. Cuba lagi sebentar.**

No retry, no backoff, no queue. A burst refusal is a "wait a moment", and TINDAK
saying that once is better than TINDAK silently retrying and spending the daily
allowance on a user who has stopped looking.

---

## 17. Timeouts (brief item 18)

The brief's 8s connect / 12s total maps onto the shape M8 already uses:

| Layer | Budget | Mechanism |
|---|---|---|
| Edge Function → provider | 8s | `AbortController`, as in `url-check` |
| App → Edge Function | 12s | `.timeout(Duration(seconds: 12))` |

The client's window is deliberately longer so the function's own answer wins the
race and the user gets a specific reason rather than a generic one. There is no
infinite spinner: the button shows progress, and at 12s it resolves to

> **AI tidak dapat dihubungi sekarang. Cuba lagi kemudian.**

with the text, the local result and every local action untouched.

---

## 18. Failure is never destructive (brief item 19)

Offline, timeout, quota, expired session, malformed response, provider
unavailable, server error — all of them land on the same rule, which is C-1 from
M8 restated for AI: **a check that could not run changes nothing.**

The Share Result screen does not close, the received text does not disappear,
local entities do not vanish, Simpan still works, and the user can try again.
There is no state in which pressing `[Cuba dengan AI]` can leave the user worse
off than not pressing it. This is a test group, not a hope.

---

## 19. Data, logging and analytics (brief items 16, 20, 21)

**No AI table beyond the two quota counters.** No prompts, no responses, no
extracted entities, no conversations, no "AI History" screen. An AI result
becomes persistent only by the routes that already exist: the user presses
Simpan, or creates a reminder. M8 set this precedent by not creating
`security_scans`, and M9 follows it.

Logs — in the function and in the app:

| Allowed | Never |
|---|---|
| request id, HTTP status, latency, error category | the selected text |
| candidate **count**, dropped-candidate **count** by reason code | any candidate value or span |
| `ai_fallback_requested/completed/unavailable` as events | prompt, model response, phone, URL, amount |

`DetectedEntity.toString()` already excludes its values for exactly this reason,
and `AiCandidate.toString()` will do the same. The provider's error bodies can
quote the request, so only status codes are logged — the rule `url-check`
already follows.

---

## 20. Scope lock

Not in M9, and enforced by tests rather than by intention:

image, screenshot, OCR, PDF, document upload, audio, voice, camera, QR,
background content, background analysis, weekly summaries, Pencegah Lupa,
recommendations, AI-generated notifications, autonomous actions, semantic
Memory search, chat, agents, tool use, streaming, and any second AI entry point
outside the result screen.

Multimodal capability in the chosen provider is not a reason to accept an image
in M9 — the brief is explicit and this plan does not reinterpret it.

---

## 21. Test strategy (brief item 22)

Everything below is M9a and runs with no network and no provider.

| Group | Pins |
|---|---|
| Trigger | CTA present on zero entities; secondary link present otherwise; **zero provider calls on render, resume, save, or detection** |
| Gates | guest → sign-in prompt, nothing sent; no consent → disclosure, nothing sent; Batal → nothing sent and nothing stored; Teruskan → exactly one call, and not asked again; not configured → the unavailable line, nothing sent |
| Consent store | separate key from Protect's; Protect's agreement does not imply AI's, and vice versa |
| Length | 2,000 exactly passes; 2,001 refused; emoji counted as one code point each; measured after normalisation; refusal sends nothing |
| Grounding | a candidate whose span is absent is dropped; offsets map back onto the normalised text |
| Validation | one accept and one reject per type, per rule in §8, including the IC-shape rejection and the PD-027 bare-domain rule |
| Envelope | malformed JSON, wrong types, unknown `outcome`, unknown entity type, 100 candidates, empty candidate list |
| Zero entities | the approved line, Simpan still offered, no fabricated result |
| Failures | each `AiFailure` → its own copy, local state untouched, no reminder created, nothing lost |
| Actions | AI phone/url/money/date reach the *same* resolver, builder, clipboard, reminder sheet; `javascript:` refused twice |
| Injection | the corpus in §12, asserting **no candidate escapes**, no action is resolved, and nothing is launched |
| Scope guards | `features/ai` imports no `url_launcher`, no `Clipboard`, no `dart:io`, no Supabase in M9a; creates no reminder directly; the fake provider exists only under `test/` |

Server-side tests (M9b): the `url-check` matrix repeated for `ai-understand` —
auth, body shape, size, quota atomicity, key-before-quota, timeout, logging.

---

## 22. Milestone split (brief item 23)

**M9a — contract and fake provider.** Everything in §2–§14 and §21. No
credential, no Edge Function, no external request, no provider decision needed.
Gate evidence is automated plus emulator screens driven by the fake.

**M9b — real provider.** Q-1 answered first, then the Edge Function, the
migration, the secret, quota, timeouts, server validation, content-safe logging,
live validation, and the cost fail-safe exercised deliberately by unsetting the
secret and confirming the app says *tidak tersedia*.

M9b does not start until M9a passes its gate, and M9b does not start until Q-1
is answered, because the answer changes whether there is a provider at all.

---

## 23. Conflicts with existing decisions (brief item 24)

| Decision | Status under this plan |
|---|---|
| ADR-006 — AI is fallback, not the default engine | **upheld**; §2 refuses to build a heuristic that would route around the local engine |
| PD-007 / PD-025 — no invented reminder time | **conflict, unresolved** — §9, Q-5. Option (a) leaves it untouched |
| PD-011 — explicit AI consent, declining disables nothing | **upheld**; §3, §4 |
| PD-023 / PD-024 — guests see the control; sign-in is not consent | **upheld**; §3 |
| PD-027 — bare domains are not detected | **at risk**; §7 closes the back door, Q-4 confirms |
| PD-028 — 2,000 input, 30/day, 5/min, 8s/12s | **implemented as written**; §5, §16, §17 |
| PD-029 — IC never becomes a callable number | **upheld on the new path too**; §8 re-checks the IC shape |
| PD-032 — no format characters in an actionable value | **upheld**; §8 step 3 |
| ADR-009 — explainable, no score | **upheld**; §10 shows no number |
| ADR-022 — sign-out clears account-owned local state | **extended** to the consent key, Q-3 |
| PD-022 — no private content in telemetry | **upheld**; §19 |

Two new ADRs are proposed, to be written with the implementation rather than
now:

- **ADR-033 — Model output is untrusted input.** Span-grounded against the
  user's own text, validated by TINDAK's own per-type rules, and converted to a
  domain entity only after both. The model is an extraction engine with no
  authority.
- **ADR-034 — The AI provider's data-use tier is a product constraint, not a
  procurement detail.** Whatever Q-1 decides is recorded here, so a later
  provider swap cannot quietly move user content onto a training tier.

---

## 24. Provider research, as of 2026-09-16 (brief item 16)

Checked against official documentation, not assumption, and deliberately not
against the 2025 note that said "Gemini 1.5 Flash". That model is not the
current generation and the plan does not carry it forward.

| | Gemini API — unpaid tier | Gemini API — paid tier | Claude API |
|---|---|---|---|
| Works with no billing account | **yes** | no | no — prepaid credits required |
| Cost at TINDAK's alpha volume | RM0 | small, but needs a card | small, but needs a card |
| Google/Anthropic trains on the content | **yes** | no | no, by default |
| Human reviewers may read it | **yes** | no | no |
| Structured JSON output | yes, schema-constrained | yes | yes |
| Current model family | 3.x Flash / Flash-Lite; free-tier limits are published in AI Studio per project, not in the docs, and Google has changed them without notice | same | Haiku 4.5 at $1/$5 per Mtok is the cheapest current fit |

Reading of it: **the free tier is technically sufficient and contractually
wrong** for this product. Every other axis favours it, and the one axis it fails
is the one TINDAK exists to defend.

No account was created, no key was issued, and no request was sent to any
provider during this planning. Exact free-tier limits are per-project and
visible only in AI Studio, so they are confirmed at M9b rather than quoted here
from a blog.

Recommendation, for Q-1: **do not ship on a tier that trains on user content.**
Ship M9a, leave the provider unconfigured with the honest *tidak tersedia*
message, and enable a paid, no-training tier when there is a budget — the same
posture PD-047 took, arrived at independently.

Sources:
[Gemini API terms](https://ai.google.dev/gemini-api/terms),
[Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing),
[Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits),
[Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output),
[Claude pricing](https://claude.com/pricing),
[Anthropic — is my data used for training](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training).

---

## 25. Questions for Product Direction (brief item 25)

| # | Question | Recommendation |
|---|---|---|
| **Q-1** | The free AI tier allows human review and training on user content; the no-training tier needs a payment method. Which way? | **Neither yet.** Ship M9a; leave the provider unconfigured until there is a budget for a no-training tier. §24 |
| **Q-2** | Does the CTA appear only on a zero-entity result, or also as a secondary link when entities were found? | Both, with the secondary link quiet. §2 |
| **Q-3** | Is AI consent cleared on sign-out, and is there a **Tarik balik** control in Settings? | Yes to both. §4 |
| **Q-4** | Confirm an AI `url` candidate with no scheme and no `www.` is dropped, so PD-027 is not reopened. | Drop it. §7 |
| **Q-5** | Does M9a carry a time of day from the text into the reminder sheet, or dates only? | **Dates only** in M9a; revisit with alpha data. §9 |
| **Q-6** | Does M9a ship a debug-only fake provider so the UI can be exercised on a device, or does device evidence wait for M9b? | Wait for M9b. §13 |
| **Q-7** | Confirm the two new copy lines not in the brief: the secondary CTA and the malformed-response line. | As drafted in §2 and §8 |

Nothing in §1–§24 is implemented until these are answered, along with the plan
itself.
