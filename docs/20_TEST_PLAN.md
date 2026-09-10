# 20 — TEST PLAN

**Owner:** Technical Lead (Claude)
**Approval:** CEO — Architecture Lock
**Status:** PROPOSED

Testing is part of implementation (master plan §26). Tests are never deleted to
make a build pass (AI Rule 10).

This document also carries the **detector specifications**, because a parser
rule and its test cases are the same artefact — the table is the specification.

---

## 1. Shape

| Layer | Kind | Runs on |
|---|---|---|
| normalizer, detectors, resolver, security scorer | unit, pure Dart | Dart VM, no device |
| repository, sync engine | unit with in-memory SQLite | Dart VM |
| share → understand → act → save | integration | emulator or device |
| RLS | SQL and REST against local Supabase | CI + recorded results |
| critical flows | manual | CEO's physical Android device |

`Understanding` and `ActionResolver` import no Flutter and touch no I/O
(`10_ARCHITECTURE.md` §3), which is why the largest and most failure-prone part
of the product runs in milliseconds with no emulator.

The clock is injected (`core/clock`). Date tests that depend on "today" pin the
clock; a parser whose tests break in January is not tested.

---

## 2. PROPOSAL — Phone detector specification

Normalisation, in order: strip spaces, hyphens, parentheses and dots; convert a
leading `+60`, `0060` or `60` to `0`.

Accept, after normalisation:

| Class | Pattern | Digits |
|---|---|---|
| Mobile | `01[0-9]` + subscriber | 10 total, or 11 for `011` and `015` |
| Landline Klang Valley | `03` + 8 | 10 |
| Landline other peninsular | `0[45679]` + 7 | 9 |
| Landline Sabah / Sarawak | `08[2-9]` + 6–7 | 9–10 |

`normalized_value` is E.164: `0123456789` → `+60123456789`.

### 2.1 Must detect

```text
0123456789          012-3456789         012-345 6789
+60123456789        +60 12-345 6789     011-12345678
0341234567          03-1234 5678        04-123 4567
082-123456          019 8765432         60123456789
```

### 2.2 Must NOT detect — REQUIRED safety tests (PD-029)

```text
901231-14-5678      Malaysian IC — 12 digits, would otherwise look like a phone
012345678901234     digit run longer than any valid number
RM1234567890        preceded by a currency marker
2026091012345678    order or reference number
1300-88-1234        toll-free short code — out of scope (PRD §5)
999                 emergency short code
```

**The IC case is the one that matters.** A Malaysian identity card number is
twelve digits, often hyphenated, and appears in exactly the messages people will
share. Detecting one as a phone number would put an IC number one tap away from
being dialled. Guard: reject any candidate that sits inside a longer digit run,
and reject the `\d{6}-\d{2}-\d{4}` shape outright.

Product Direction classified this as a required safety requirement, not an
optional enhancement (PD-029). These assertions cannot be removed or skipped to
make a build pass (AI Rule 10), and a release with any of them failing is
blocked.

Additional IC forms that must not be detected:

```text
900101-03-1234      hyphenated
900101 03 1234      spaced
900101031234        unseparated, 12 digits
```

### 2.3 Confidence

| Situation | Confidence |
|---|---|
| explicit `+60`, or separators in the right places | 0.95 |
| bare digits matching a valid prefix and length | 0.80 |
| valid length but ambiguous prefix | 0.60 |

---

## 3. PROPOSAL — Money detector specification

`RM` or `MYR`, optional space, digits with optional `,` thousands groups,
optional `.` with one or two decimals. Stored as integer sen
(`11_DATABASE.md` §4).

### 3.1 Must detect

| Input | Sen |
|---|---|
| `RM25` | 2500 |
| `RM25.50` | 2550 |
| `RM 183.50` | 18350 |
| `RM1,500.00` | 150000 |
| `MYR99` | 9900 |
| `rm25.50` | 2550 |
| `RM1,234,567.89` | 123456789 |

### 3.2 Must NOT detect

```text
1,500           no currency marker
RM              marker with no amount
RM25.555        three decimals — not a currency amount
ROOM25          RM must not match inside a word
RM-25           no negative amounts in V1
```

---

## 4. PROPOSAL — Date detector specification

Ambiguous numeric dates are **DD/MM/YYYY** (PD-008), so `03/04/2026` is
3 April 2026.

Month names in English and Malay, full and abbreviated:

```text
Januari Februari Mac April Mei Jun Julai Ogos September Oktober November Disember
Jan Feb Mac Apr Mei Jun Jul Ogo Sep Okt Nov Dis
January February March ... December  /  Jan Feb Mar ... Dec
```

`Mac` and `Mei` are the traps: Malay `Mac` is March, and `Mei` is May, but
English `Mar` and `May` share the slot. Both spellings map to the same month, so
this is a table, not a language detector.

### 4.1 Must detect

```text
25/09/2026        25-09-2026        25.09.2026
25 September 2026 25 Sep 2026       25 Ogos 2026
25 Disember 2026  1 Mac 2026
```

### 4.2 Must NOT detect

```text
32/09/2026        invalid day
25/13/2026        invalid month
2026              a bare year is not a date
0341234567        a phone number is not a date
```

### 4.3 Two-digit years — rejected (ADR-026)

`25/09/26` is **rejected** in V1. A reminder set to the wrong year is a silent
failure the user only discovers by missing something, and PD-007 already
establishes that TINDAK does not invent time values. The PRD baseline is
four-digit years; this keeps the code aligned with it. Proposed as ADR-026.

### 4.4 Dates with no year — approved (PD-025)

`25 September`, with no year, is the form in the vision document's own flagship
example. Resolve to the **next occurrence** — this year if the date is still
ahead, otherwise next year — and flag the entity `yearInferred`. The reminder
screen shows the resolved year in full and lets the user change it before the
reminder is created (PD-007, PD-025), so an inference error is visible before it
matters. `yearInferred` is internal; it never appears in the UI as jargon.

Test cases pin the clock:

| Today | Input | Resolves to |
|---|---|---|
| 2026-09-10 | `25 September` | 2026-09-25 |
| 2026-09-10 | `3 Mac` | 2027-03-03 |
| 2026-12-31 | `1 Januari` | 2027-01-01 |

Escalated as E-2 in `10_ARCHITECTURE.md` §15.

---

## 5. PROPOSAL — URL detector specification

Detect `http://` and `https://`, and `www.`-prefixed hosts which are normalised
to `https://`.

**Bare domains are not detected** (PD-027, approved). `Jumpa saya di kedai.my
esok` would otherwise produce a URL, and Malay text is full of tokens that look
like a domain. Cost: a shared bare domain is missed. Benefit: no false links in
ordinary sentences — a false action is worse than a conservative detector.

Backlogged as *URL Detection Enhancement*, to be revisited only if beta data
shows users are actually sharing bare domains.

### 5.1 Must detect

```text
https://example.com          http://example.com/a/b?c=d
https://example.com.my       www.example.com
https://sub.example.com:8443/x
```

### 5.2 Must NOT detect

```text
example.com                  bare domain (see above)
kedai.my                     bare domain inside a sentence
25.09.2026                   a date is not a host
javascript:alert(1)          not an http(s) scheme
```

`normalized_value` lowercases the scheme and host but preserves path case —
paths are case-sensitive and a lowercased path is a different resource.

---

## 6. Multi-entity and overlap

| Input | Expected |
|---|---|
| `Bayar bil TNB RM183.50 sebelum 25 September` | money + date, both retained (PD-002) |
| `Hubungi 012-3456789 atau https://example.com` | phone + url |
| `https://example.com/012-3456789` | url only — the phone span is inside the URL span |
| `Invois 25/09/2026 sebanyak RM99` | date + money |
| `Tiada apa-apa di sini` | no entities → nothing-detected state (PRD §18) |

The third row is the overlap rule (`10_ARCHITECTURE.md` §5) and is the one that
regresses when a detector is edited.

---

## 7. Action resolver

Pure mapping, so the tests are exhaustive: every entity type against its exact
action list from PRD §5–§8, plus Save always present, plus the empty result
returning Save and — when consent and session allow — Try AI.

### 7.1 Action executor safety — REQUIRED tests (PD-029)

The executor builds URIs from text that arrived from another app. These
assertions are release-blocking (`12_SECURITY.md` §7):

| Input | Expected |
|---|---|
| `012-345 6789` | `tel:+60123456789` |
| `+60 12-345 6789` | `tel:+60123456789` |
| `012345#6789` | **refused** — `#` cannot reach a `tel:` URI |
| `*21*0123456789#` | **refused** — USSD shape |
| `012345*6789` | **refused** — `*` cannot reach a `tel:` URI |
| `javascript:alert(1)` as a URL action | **refused** — scheme not allowed |
| `file:///data/data/...` as a URL action | **refused** |
| `intent://...` as a URL action | **refused** |
| `http://example.com` | opened |
| `https://example.com` | opened |
| WhatsApp action on a valid number | `https://wa.me/60123456789`, no free text interpolated |

`#` and `*` in a `tel:` URI are how USSD codes were triggered from links on some
Android devices. The detector should never produce such a candidate; the
executor refuses it anyway, because two independent checks are what stops one
regression from becoming a dialled USSD code.

### 7.2 Guest gating — REQUIRED tests (PD-023, PD-024)

| State | Action | Expected |
|---|---|---|
| guest | `Security Check` | local heuristics shown, then sign-in prompt for the online check; control is **visible**, never hidden |
| guest | `Try AI` | sign-in prompt; no network call made |
| signed in, no AI consent | `Try AI` | consent screen, not an AI call |
| signed in, consent declined | any local feature | still works (PD-011) |
| signed in, consent given | `Try AI` | AI call proceeds |

Sign-in must not be treated as consent, and consent must not be treated as
sign-in.

---

## 8. Memory and sync

| Case | Expected |
|---|---|
| Save while signed out | row written, `owner_user_id` null, `sync_status` `local_only` |
| Search matches original text | FTS hit |
| Search matches an entity value | entity hit, e.g. `183.50` or `+60123456789` |
| Delete | row invisible to list and search, tombstone remains |
| Sign in, choose Sync | guest rows become account-owned and pending; ids unchanged |
| Sign in, choose Not Now | nothing uploaded (PD-016) |
| Sign out | account-owned rows gone, guest rows intact (`12_SECURITY.md` §5) |
| Two devices, edit same row | later server `updated_at` wins, deterministically |
| Delete on A, sync on B | row disappears on B |
| Sync interrupted mid-push | resumes; no duplicates, because ids are client-generated |
| Offline save then reconnect | pushes on the next trigger |

---

## 9. RLS

The bypass matrix B-1 … B-12 in `12_SECURITY.md` §3.3. Executed against a local
Supabase with two real users, results pasted into this document under a dated
heading. A run that was not recorded did not happen.

**M5b does not pass its gate until every row of that matrix is recorded as
failing to gain access.**

---

## 10. Integration

```text
Share text/plain ─► Share Result renders ─► action resolves ─► Save ─► Memory
```

Covered: phone, URL, money, date, multi-entity, nothing-detected, offline,
reminder-without-time asking for a time, and Save from the nothing-detected
screen.

Plus the behaviours Product Direction fixed in review:

| Case | Expected |
|---|---|
| Notification permission denied, then create a reminder | reminder is **saved**; "notifications are off" state shown with an enable path; Memory Save never blocked (PD-026) |
| Second reminder after denial | no repeated permission prompt |
| Reminder created while notifications are off | UI never claims an alert will fire |
| `25 September` shared after that date has passed | reminder confirmation shows next year, year editable (PD-025) |
| Guest taps a cloud control | sign-in prompt, control visible (PD-023) |

---

## 11. Device testing — CEO

Founder Alpha is at least 50 manual scenarios (master plan §29). Minimum
coverage:

- Share from WhatsApp, Chrome, Gmail, SMS, and a notes app.
- Share while TINDAK is closed, open, and already showing a share result.
- Call and WhatsApp on a real Malaysian number.
- Reminder that actually fires, including with the screen off.
- Airplane mode across the whole local flow.
- Sign in, sync, sign out, sign back in.
- Uninstall and reinstall — guest data is gone, synced data returns.
- Notification permission denied.
- A very long share (near the 10,000-character cap).

---

## 12. CI

```yaml
# proposal — not created until M1
on: [push, pull_request]
jobs:
  verify:
    steps:
      - flutter analyze          # zero warnings
      - flutter test             # unit + widget
      - flutter build apk --debug
```

No production deploy from CI (master plan §25). RLS tests run against a local
Supabase in a separate job once M5b exists.

---

## 13. Coverage expectation

Not a global percentage — a percentage target rewards testing whatever is
easiest. Instead: **every case listed in §2 through §6 exists as an assertion**,
positive and negative alike. A detector change that does not add a row to those
tables is either not a behaviour change or is missing its test.

---

## 14. Open items

None outstanding in this document. Bare-domain detection (§5), two-digit years
(§4.3) and no-year inference (§4.4) were all decided in Product Direction
review and are recorded as PD-025, PD-027 and ADR-026.

The RLS results table in §9 stays empty until M5b runs it. An empty table is not
a pass.
