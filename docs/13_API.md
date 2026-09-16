# 13 — API

**Owner:** Technical Lead (Claude)
**Approval:** CEO — locked 2026-09-10
**Status:** LOCKED — CEO Architecture Lock, 2026-09-10

Three interfaces: Supabase Auth, Supabase PostgREST through `supabase_flutter`,
and two Edge Functions. Nothing else talks to the network.

---

## 1. Authentication

### 1.1 Email OTP, six-digit code — ADR-020

| Option | Verdict |
|---|---|
| **Email OTP** | **Recommended.** No password to leak or reset. The code is typed inside TINDAK, so the user never leaves the app and no deep link is needed — which keeps the Navigator 1.0 decision (`10_ARCHITECTURE.md` §11) intact. Free. |
| Magic link | Same cost, but it bounces through an email client and back via a deep link. More moving parts, and app-link verification is a classic source of "sign-in does nothing" bug reports. Rejected for V1. |
| Email + password | Adds password reset, strength rules, and a credential worth stealing, for no gain over OTP. Rejected. |
| Phone OTP | Real SMS cost per attempt and an obvious abuse target. Rejected. |
| Google Sign-In | Genuinely good UX and worth adding later. Needs an OAuth client, SHA-1 registration per build variant, and `google_sign_in`. Deferred, not rejected. |
| Supabase anonymous sign-in | Would create a cloud user for every guest, which is exactly the silent upload PD-016 forbids, and it makes the quota in §4 meaningless — a new anonymous identity per reinstall. **Rejected on security grounds.** |

ADR-020.

```text
Settings ─► Sign in ─► enter email ─► signInWithOtp
                                         │
                                    enter 6-digit code
                                         │
                                    verifyOtp ─► session ─► secure storage
                                         │
                                    guest migration prompt (PD-016)
```

Sign-out follows `12_SECURITY.md` §5.

---

## 2. Data access

The client speaks to PostgREST through `supabase_flutter`. RLS is the
authorisation boundary; the client sends no `user_id` filter of its own beyond
what the sync query needs.

| Operation | Call | When |
|---|---|---|
| Push memories | `upsert` on `memories`, then replace `memory_entities` for those ids | sync push |
| Pull memories | `select` where `updated_at > cursor`, ordered ascending | sync pull |
| Push reminders | `upsert` on `reminders` | sync push |
| Record telemetry | `insert` into `usage_events` | signed in only |
| Read profile | `select` on `profiles` | after sign-in |

Search is **never** a cloud query. It runs against local SQLite, so it works
offline and returns at typing speed (PRD §11).

Entities are replaced wholesale with their parent memory rather than diffed —
they are derived data (`11_DATABASE.md` §2.3), and a diff would be code that
can go wrong for no benefit.

---

## 3. Edge Functions

Two, both requiring a verified JWT.

```text
supabase/functions/
├── ai-understand/
└── url-check/
```

### 3.1 `ai-understand`

Request:

```json
{
  "text": "Bro esok lepas lunch jumpa Ahmad dekat KLCC bawa IC dengan proposal",
  "client_local_date": "2026-09-10"
}
```

`client_local_date` is sent so relative words ("esok") resolve against the
user's day, not the server's UTC day. It carries no identity.

Response:

```json
{
  "ok": true,
  "result": {
    "intent": "meeting",
    "entities": [
      { "type": "date", "value": "2026-09-11", "confidence": 0.82 },
      { "type": "location", "value": "KLCC", "confidence": 0.7 }
    ],
    "summary": "Meeting with Ahmad at KLCC"
  }
}
```

Failure:

```json
{ "ok": false, "error": "quota_exceeded", "retry_after_s": 3600 }
```

Errors: `unauthorized`, `input_too_large`, `quota_exceeded`, `rate_limited`,
`provider_timeout`, `provider_error`, `invalid_response`.

**The response is validated before it reaches the UI.** Unknown entity types are
dropped, confidences outside `[0,1]` are rejected, and a malformed body becomes
`invalid_response` and is treated as "not understood" (UX §21). A model does not
get to decide what the app renders — the master plan is explicit that AI does
not control UI.

The provider is a Gemini Flash-class model; the exact model id is pinned at
implementation time, since available model ids change and pinning a stale one in
a document is worse than naming the tier. Model id lives in Edge Function
config, not in the client, so it can be changed without an app release.

Location and person are not V1 entity types (PRD §4). They are accepted from the
model and shown as understood text only — they do not become
`memory_entities` rows and they resolve no actions. Promoting them is a product
decision, not an implementation detail.

### 3.2 `url-check`

Request:

```json
{ "url": "https://example.com/login" }
```

Response:

```json
{
  "ok": true,
  "verdict": "suspicious",
  "reasons": [
    "host_recently_registered",
    "brand_name_in_path_not_host",
    "provider_flagged"
  ],
  "provider": "<provider id>"
}
```

`reasons` are stable codes, not prose. The client renders the Malay and English
copy, so wording changes ship with the app rather than from a server, and there
is no path for server text to reach the user's screen unreviewed.

Verdicts map to the PRD §14 vocabulary: `low`, `caution`, `suspicious`, `high`.
There is no percentage field anywhere in this contract — ADR-009 is enforced by
the shape of the API, not by a reminder in a code review.

Provider failure returns `ok: false`, and the UI shows the "unavailable" state.
A failed check never renders as low risk (UX §23).

---

## 4. AI limits — approved as PD-028

PRD §15 requires bounded input, rate limiting, timeout, failure handling and
abuse protection, and left the numbers to me. Product Direction approved the
table below as **initial operational configuration** — tunable from usage,
abuse and cost data, not immutable product constants.

| Control | Approved | Reasoning |
|---|---|---|
| Max input | 2,000 characters | A shared WhatsApp message or a page title is well under this. It also bounds the per-call token cost, which is what an abuser would be spending. |
| Daily quota | 30 calls per user per day | AI is a fallback for text the local engine could not read (ADR-006). A normal user hits it a handful of times a day; 30 is generous and still caps the damage from one compromised account. |
| Burst | 5 calls per minute | A human cannot share and read faster than this. A script can. |
| Upstream timeout | 8 seconds | Past this the user has already decided the app is broken. |
| Client timeout | 12 seconds | Leaves room for the round trip and one retry of the function's cold start. |
| Retry | one, only on `provider_timeout` | Never on `quota_exceeded` or `rate_limited`. |
| Reputation quota | 60 calls per user per day | Cheaper per call, and a user checking many links is plausible behaviour. |

Counted in Postgres against the token's `user_id`, so reinstalling does not
reset it. All of it is configuration, changeable without an app release.

**Cost shape.** With these caps the worst case is bounded per user and per day,
which is the property that matters — the current V1 exposure is a small number
of short calls per active user, and the free tiers of both provider types cover
alpha and closed beta. A real figure needs the chosen models and real user
counts, and a made-up figure here would be worse than none.

---

## 5. URL reputation provider — verified

Checked against Google's current official documentation, not assumption. The
first recommendation in the previous draft was wrong on terms, and this is the
correction.

### 5.1 Google Safe Browsing API — NOT USABLE by TINDAK

Free, and the obvious first choice, but the usage restrictions say it is
**"for non-commercial use only (meaning 'not for sale or revenue generating
purposes')"**, and direct commercial users to Web Risk instead.

The master plan (§30) plans a paid Pro tier. That makes TINDAK
revenue-generating and puts it outside these terms. Building V1 on Safe
Browsing would mean either abandoning monetization or migrating providers under
pressure the moment pricing ships.

Separately, **v4 is deprecated and ends on 31 March 2027** — inside the life of
V1. v5 is the current version and carries the same non-commercial restriction.

**Rejected on terms, not on quality.**

### 5.2 RECOMMENDED — Google Web Risk, Lookup API (`uris.search`)

Google's commercial equivalent of the same threat data.

| | |
|---|---|
| Free tier | 100,000 `uris.search` calls per month |
| Beyond that | USD 0.50 per 1,000 calls |
| Commercial use | permitted — this is the commercial product |
| Key | server-side only, in Edge Function config |

PD-028 caps external checks at 60 per user per day, so the free tier is not
reached during Founder Alpha, Closed Alpha or Beta. At real usage — a user
checking a handful of links a day — 100,000 monthly calls covers a user base
far larger than V1 targets, and the first paid step is USD 0.50 per 1,000.

Privacy cost: the Lookup API receives the full URL. This is precisely why
PD-012 makes the check manual and why an automatic check was rejected — an
automatic one would send every shared URL to Google.

Web Risk also offers an Update API, where the client keeps a local hash list and
only resolves prefix matches remotely. Better privacy, materially more
complexity, and the resolving call is priced far higher. **Not V1.** Recorded as
a future privacy improvement.

### 5.3 The interface stays abstracted

```dart
abstract interface class ReputationProvider {
  Future<ReputationVerdict> check(Uri url);
}
```

One implementation in V1. The Edge Function maps every provider's response onto
TINDAK's own four verdicts and stable reason codes (§3.2), so replacing the
provider changes one function and touches neither the client nor the database.

**No provider id is stored**, because no scan row is stored: `security_scans`
was never created and the only M8 table is the quota counter
(`11_DATABASE.md` §2.5). Which provider answered is a deployment fact, visible
in the function's source and its configured secrets, not something to be
reconstructed from a table of everybody's links.

As built, the abstraction is `ReputationProvider` in
`mobile/lib/features/security/data/reputation_provider.dart`, with
`EdgeReputationProvider` as the single implementation. The provider layer is
therefore already switchable — which is what makes PD-047 a deferral rather
than a gap.

Local heuristics (`12_SECURITY.md` §9) run first regardless of provider, so a
guest, an offline user, or a provider outage still gets a partial, explainable
answer.

**Decided at M8b.** Web Risk is adopted as the V1 provider (ADR-028), and the
Google Cloud billing account it requires is **not** accepted: enabling billing
is a payment the project is not making, so live Web Risk lookups are deferred
under **PD-047**. The function ships with no `WEB_RISK_API_KEY`, answers
`unavailable`, and — because the key is read before the quota is claimed —
spends none of the user's 60 while it is unconfigured. Enabling the provider
later is a key and a redeploy, not a redesign. Sources:
[Safe Browsing usage restrictions](https://developers.google.com/safe-browsing/v4/usage-limits),
[Safe Browsing overview](https://developers.google.com/safe-browsing),
[Web Risk pricing](https://cloud.google.com/web-risk/pricing).

---

## 6. Errors at the client

| Code | UI |
|---|---|
| `unauthorized` | prompt to sign in again |
| `input_too_large` | "too long to analyse", Save still offered |
| `quota_exceeded` | "you have used today's AI checks" |
| `rate_limited` | "try again in a moment" |
| `provider_timeout` / `provider_error` | UX §21; content is never lost |
| `invalid_response` | same as above, logged without content |
| offline | UX §18 |

Every one answers the three questions in UX §26: what happened, what still
works, what to do next.

---

## 7. Versioning

Edge Functions are versioned by path (`/ai-understand`) with additive changes
only. A breaking change ships as a new path while the old one keeps working
until the installed base has moved — an Android user who never updates must not
find TINDAK broken by a backend deploy.

---

## 8. Open items

- **Adopt Web Risk** (§5.2) — needs CEO approval and a Google Cloud billing
  account before M8.
- Whether Google Sign-In lands in V1 or later (§1.1).

Closed: quota, cap and timeout numbers are approved as PD-028 (§4).
