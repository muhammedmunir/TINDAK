# 10 — ARCHITECTURE

**Owner:** Technical Lead (Claude)
**Status:** BLOCKED — waiting for Product Pack (`00`–`03`) approval, per Startup Step 2
**Approval:** CEO (Architecture Lock, Startup Step 4)

> Scaffold only. No architectural decision here is accepted until Step 4.

## Planned contents

- Flutter feature-first module layout under `mobile/lib/`.
- Understanding Engine: `ContentNormalizer` -> `UnderstandingEngine` ->
  detectors (`Phone`, `Url`, `Money`, `Date`) -> `UnderstandingResult`.
  Detectors must be pluggable; no single if/else regex chain (Section 10).
- `ActionResolver`, independent of UI (Section 11).
- State management choice, with the technical reason required by AI Rule 6.
- Share Intent receiver on the Android side.
- Local-first pipeline with the AI fallback boundary (ADR-005, ADR-006).
- Offline and caching strategy.
- Error handling and failure modes.
- Dependency list, each with a justification.

## Constraints already binding

- Android only (ADR-002).
- Supabase is the only backend (ADR-001, AI Rule 7).
- Explicit Share Intent input only (ADR-003, ADR-004).
- AI is fallback, never the default path (ADR-006).
