# 12 — SECURITY

**Owner:** Technical Lead (Claude, acting as Security Reviewer)
**Status:** BLOCKED — waiting for Product Pack approval
**Approval:** CEO

> Scaffold only.

## Planned contents

- Threat model: device loss, hostile app sharing malicious payloads, account
  takeover, cross-tenant data access, API key extraction, abuse of the AI and
  reputation endpoints.
- RLS policies per table, plus the bypass attempts that were run and their
  recorded results. "RLS enabled" is not accepted as proof (Section 22).
- Authentication flow proposal that protects cloud data without destroying
  activation (Section 13).
- Secret handling. Sensitive API keys must never ship inside the Flutter client
  (Section 17, AI Rule 9). Required path:
  `Flutter -> Supabase Edge Function -> External API`.
- URL security pipeline: normalize, validate, local indicators, reputation
  provider, risk assessment, explanation.
- Privacy review. Analytics must never carry the user's private shared text
  (Section 27).
- Rate limiting and abuse prevention on Edge Functions.

## Binding rules

- Security controls are never disabled to fix a functional bug (AI Rule 11).
- Security output must be explainable and must not claim unsupported certainty
  such as `SCAM 98%` (ADR-009).
