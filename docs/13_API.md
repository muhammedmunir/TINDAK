# 13 — API

**Owner:** Technical Lead (Claude)
**Status:** BLOCKED — waiting for Product Pack approval
**Approval:** CEO

> Scaffold only.

## Planned contents

- Supabase client usage from Flutter: which tables, which operations.
- Edge Function contracts:
  - AI understanding gateway (Gemini) — request, response, validation of the
    structured result, timeout, and failure behaviour.
  - URL reputation gateway — provider abstraction so one provider can be
    replaced without touching the client.
- Auth token handling and refresh.
- Error codes and client-side handling.
- Versioning approach.

## Binding rule

No external provider is ever called directly from the Flutter client with a
secret key. All such calls route through a Supabase Edge Function (Section 17).
