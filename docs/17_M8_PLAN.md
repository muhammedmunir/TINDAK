# 17 — M8 PLAN: Protect

**Owner:** Technical Lead (Claude)
**Status:** BUILT — M8a closed, M8b built and validated. **Live Google Web Risk
integration is deferred by PD-047** (billing barrier); the provider abstraction,
Edge Function, quota and disclosure are all in place and the function answers
`unavailable` with no key. Evidence: `20_TEST_PLAN.md` §9.3 and §9.4.
**Baseline:** `develop @ 6069c3d`
**Inputs:** M8 Product Direction Brief (2026-09-16), ADR-009, ADR-018, ADR-025,
ADR-028, PD-012, PD-023, PD-024, PD-027, PD-028, PD-032,
`12_SECURITY.md` §7 and §9–§11, `13_API.md` §3.2 and §5, `11_DATABASE.md` §2.5,
`03_UX_FLOWS.md` §6

---

## 1. Reconciliation — the brief against what is built

| Brief requirement | State on `develop` | Work needed |
|---|---|---|
| Manual check only, never automatic | PD-012; nothing sends URLs today | a second action on URL entities |
| Malay label **Semak Keselamatan** | M4 labels are Malay already (PD-037) | one more label |
| Local checks work offline | the understanding layer is pure Dart with no I/O | new pure-Dart analyser |
| Four levels, no percentage | ADR-009; `13_API.md` §3.2 has no score field | risk model with four values only |
| Reasons, not a bare badge | `13_API.md` §3.2 returns stable codes, client renders copy | reason codes plus Malay copy in the app |
| External lookup needs an account | ADR-025, PD-023 | sign-in gate on the online step only |
| Provider behind an abstraction | `13_API.md` §5.3 already specifies one | implement it in M8b |
| Provider failure never reads as safe | `12_SECURITY.md` §9, UX §23 | explicit unavailable state (§5) |
| Opening still goes through M4 | `ActionUriBuilder` refuses anything but http/https | reuse unchanged; never bypassed |
| Bare domains stay undetected | PD-027 | no detector change at all |
| No AI, no background scanning | — | scope lock, enforced by tests (§9) |

**Nothing in M8a needs the cloud, a permission, a package or a schema change.**
M8b needs an Edge Function, a Web Risk key held server-side, and a decision on
`security_scans` (§6, C-3).

---

## 2. Gate split

- **M8a — Local Protect.** Risk model, deterministic local checks, reason
  codes and copy, the result screen, the risky-open confirmation, the guest
  path, offline behaviour, and regression against M3/M4. **No URL leaves the
  device in M8a at all.**
- **M8b — External reputation.** The `url-check` Edge Function, Web Risk behind
  the provider abstraction, authentication, quota, timeouts and failure states,
  data minimisation, and whatever persistence C-3 settles.

The split means Product Direction reviews how TINDAK judges links before a
single link is ever sent anywhere.

---

## 3. Local checks (Layer A)

Each check is deterministic, runs on the **normalised** URL the detector
produced, and carries a fixed severity. No check invents a probability.

| Code | Signal | Severity |
|---|---|---|
| `credentials_in_url` | userinfo present: `https://bank.com@evil.example` | suspicious |
| `encoded_authority_character` | a percent-escape in the authority that decodes to `@`, `/` or `.` | suspicious |
| `mixed_script_host` | one label mixes scripts, e.g. Latin with Cyrillic | suspicious |
| `normalisation_mismatch` | the raw span and the normalised value differ beyond trimming | suspicious |
| `not_encrypted` | scheme is `http` (C-5) | caution |
| `ip_address_host` | host is a raw IPv4 or IPv6 literal | caution |
| `punycode_host` | any `xn--` label | caution |
| `unusual_port` | explicit port other than 80 or 443 | caution |
| `deep_subdomains` | six or more labels — a conservative threshold, since `a.b.c.co.uk` is five | caution |
| `url_shortener` | host is on a short, static list of shorteners | caution |

Dropped after the plan gate: `excessive_length` and general `heavy_encoding`.
Length alone is not evidence, and percent-encoding in a path is ordinary; only
encoding that disguises the **authority** is deterministic deception.

`normalisation_mismatch` should never fire — PD-032 strips invisible characters
before detection — and exists so that if it ever does, the user is told rather
than TINDAK silently trusting a rewritten link.

**Not included in M8a:** the brand-lookalike check from `12_SECURITY.md` §9.
It needs a curated brand list, and a wrong entry accuses a real business of
phishing. See C-4.

### 3.1 Combining signals — no scoring

```text
level = the highest severity present
```

That is the whole rule. Three caution signals stay **CAUTION**; they do not add
up to SUSPICIOUS. Counting weak signals into a strong verdict is exactly the
false certainty ADR-009 forbids, and it is how a legitimate shortened link on a
non-standard port would end up labelled dangerous.

**HIGH RISK is unreachable from local checks alone.** It requires an
authoritative provider match (§4), or a condition Product Direction later
approves explicitly.

---

## 4. External reputation (Layer B)

```text
app ─JWT─► Edge Function `url-check` ─► Google Web Risk ─► verdict + codes ─► app
```

**The app never calls Web Risk directly.** The key would have to ship inside the
APK, where anyone can read it (`12_SECURITY.md` §6, AI Rule 9). The function
holds the key, verifies the JWT, enforces the quota, and maps the provider's
answer onto TINDAK's four verdicts and stable reason codes — so replacing the
provider changes one function and touches neither the app nor the database
(`13_API.md` §5.3).

| Provider answer | TINDAK level | Reason code |
|---|---|---|
| Threat match (malware, social engineering, unwanted software) | **high** | `provider_flagged` |
| No match | no change to the local level | `provider_clean` |
| Error, timeout, quota, offline | **no change to the level** — an availability state, not a verdict (C-1) | `provider_unavailable` |

### 4.1 Exactly what leaves the device

The normalised URL, and the user's access token. Nothing else: no memory
content, no surrounding text, no phone, money or date entities, no memory id,
no email. The request body is `{ "url": "<the url>" }`, as `13_API.md` §3.2
already specifies, and a test asserts the body has exactly that one key.

---

## 5. Provider unavailable is not "safe"

A result carries two things that are never collapsed into one:

```text
local assessment      always present, works offline
online reputation     checked | clean | flagged | unavailable | not signed in
```

**Locked at the M8 plan gate (C-1):** the online status never changes the risk
level. A clean local scan with no connection stays **LOW RISK**, and says
*"Tiada sambungan internet. Semakan tempatan masih tersedia."* Offline, timeout,
provider error, exhausted quota and not-signed-in are all **availability
states** — reported in their own words, never as an accusation against the link.

What TINDAK must never do in that state is imply the link is safe. The
disclaimer is always present, and a result that could not be checked online says
so plainly.

---

## 6. Domain model

```text
SecurityAssessment
  url            the normalised URL that was checked
  level          low | caution | suspicious | high
  findings       list of Finding (code + severity), in fixed order
  onlineStatus   notChecked | clean | flagged | unavailable | signInRequired
```

Pure Dart, no Flutter, no I/O — so every classification rule is a unit test, as
with the understanding engine. The provider sits behind:

```dart
abstract interface class ReputationProvider {
  Future<ReputationResult> check(Uri url);
}
```

with a fake in tests and the Edge Function client in M8b.

---

## 7. Screens and flow

```text
URL row:  [Buka] [Semak Keselamatan]

Semak Keselamatan
      │
      ├─ local checks (always, offline too)
      │
      ├─ signed in?  ── no ──► sign-in gate, local result still shown
      │        │ yes
      │        └─► url-check ─► level, reasons
      │
      └─► result: level + reasons + disclaimer + [Buka Pautan] [Tutup]
```

- **Guest gate copy (approved):** "Log masuk untuk semakan keselamatan dalam
  talian." with **[Bukan Sekarang] [Log Masuk]**. Bukan Sekarang keeps the local
  result on screen.
- **Opening:** for `low` and `caution`, Buka Pautan goes straight through the
  existing M4 path. For `suspicious` and `high`, a confirmation first:
  "Pautan ini mempunyai tanda risiko. Anda masih mahu membukanya?" with
  **[Batal] [Buka Pautan]**. No countdown, no disabled button, no trickery.
- **Every result** ends with the disclaimer that a check helps spot risk but
  does not guarantee a link is safe.
- **No scan history screen** (Product Direction preference). Memory stays the
  place people look for things.

Navigation stays Navigator 1.0 (ADR-018): the result is one pushed route.

---

## 8. Quota, and where it is enforced

60 external checks per user per day (PD-028), counted **in Postgres inside the
Edge Function**, against the `user_id` in the verified JWT. Not in the app,
where reinstalling would reset it, and not from a value in the request body.
When the limit is reached the function returns a typed error, calls no provider,
and the app shows *"Had semakan dalam talian hari ini telah dicapai. Cuba lagi
esok."* Local checks keep working.

This needs a durable per-user counter, which is the strongest argument for
keeping `security_scans` at all — see C-3.

---

## 9. Test strategy

- **Pure Dart:** every local check, in both directions (fires / does not fire),
  the combination rule, and the four levels. Fixtures include homograph hosts,
  `https://maybank2u.com.my@evil.example`, raw IP hosts, punycode, odd ports,
  deep subdomains, shorteners, long URLs and heavy percent-encoding.
- **Fake provider:** clean, flagged, timeout, error, quota-exhausted and
  offline, each asserted to produce the right level and reason — especially that
  none of the failures produce `low`.
- **Widget:** result screen for each level, the risky-open confirmation, the
  guest sign-in gate, and the offline state.
- **Boundary:** a test asserting the request body carries the URL only.
- **Scope guard:** a test asserting no AI import, no background entry point, and
  that Protect code never calls the clipboard or the launcher directly.
- **Regression:** the whole existing suite, unchanged, including that a
  dangerous scheme is still refused at the M4 boundary no matter what a scan
  says.

---

## 10. Ambiguities for Product Direction

**C-1 — A guest's clean local result.** Nothing was sent, so "unavailable" is
not quite true, and marking every guest scan CAUTION would punish signing out.
Options: (a) show the local level, with a line saying the online check needs
sign-in and the Log Masuk action; (b) cap every guest result at CAUTION.
**Recommendation: (a).** The user is told plainly that half the check has not
run.

**C-2 — Confirm no escalation by counting.** Three caution signals stay CAUTION
(§3.1). Confirming explicitly, because the alternative is what most "risk score"
products do.

**C-3 — Does `security_scans` survive, and in what shape?** The quota needs a
durable per-user counter, which this table can be. But the locked schema stores
the **full URL**, and a 30-day list of every link a user checked is a browsing
history. Options: (a) keep the table but drop the `url` column, storing host,
verdict, reason codes, provider and time; (b) keep the full URL as designed;
(c) no table, and count quota in a separate counter row per user per day.
**Recommendation: (a)** — it answers the quota need, keeps the operational
record, and stores materially less. This amends `11_DATABASE.md` §2.5 and needs
an ADR.

**C-4 — The brand-lookalike check.** `12_SECURITY.md` §9 lists it; it needs a
curated list of Malaysian brand names, and a false positive tells someone a real
bank's site is fake. **Recommendation: leave it out of M8a**, revisit with real
alpha data. If Product Direction wants it, the brand list is a product artefact
and needs approval name by name.

**C-5 — Is plain `http://` a caution?** It is a real signal and also very
common on older Malaysian sites, so it may make CAUTION the normal result.
**Recommendation: keep it as caution**, with the specific reason
"Sambungan ke tapak ini tidak disulitkan."

**C-6 — The first online check disclosure.** `12_SECURITY.md` §9 says the first
external check shows "the same kind of disclosure as AI consent". The brief does
not mention it. **Recommendation: one-time sheet** before the first ever online
check, stating that the link is sent to a Google service, with Batal and
Teruskan. Needs approved copy.

**C-7 — Reason copy.** Every code needs one short Malay sentence. I will
propose the full table with the M8a implementation for approval, rather than
inventing user-facing wording inside a plan.

---

## 11. Order of work, once approved

1. **M8a:** risk model, local checks, reason codes and copy, result screen,
   risky-open confirmation, guest gate, offline state, tests. Report and stop.
2. **M8b:** Edge Function, Web Risk behind the provider abstraction, auth,
   quota, failure states, persistence per C-3, live provider validation. Report
   and stop for the M8 gate.

No provider credential, no Edge Function, no `security_scans`, no package and no
Android change until each is approved at its own gate.
