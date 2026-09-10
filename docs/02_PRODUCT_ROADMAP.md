# 02 — PRODUCT ROADMAP

**Owner:** Product Direction (ChatGPT)  
**Approval:** CEO  
**Status:** READY FOR CEO APPROVAL

## 1. Principle
Build vertical slices. Prove the current layer before adding the next. Claude must not implement future features merely because architecture can support them.

## 2. M0 — Foundation

### M0a Product Pack
- `00_PRODUCT_VISION.md`
- `01_PRD_V1.md`
- `02_PRODUCT_ROADMAP.md`
- `03_UX_FLOWS.md`

**Gate:** CEO Product Lock.

### M0b Technical Pack
After Product Lock:
- `10_ARCHITECTURE.md`
- `11_DATABASE.md`
- `12_SECURITY.md`
- `13_API.md`
- `20_TEST_PLAN.md`
- `21_RELEASE_PLAN.md`

**Gate:** CEO Architecture Lock. No application feature coding before it.

## 3. V0 — Proof

### M1 Flutter Foundation
Flutter Android project, approved feature-first structure, baseline tests/build.

### M2 Android Share Intent
Real `text/plain` share from compatible Android apps → TINDAK Share Result.

### M3 Phone + URL Understanding
Normalizer, modular detectors, Malaysian Phone, URL, multi-entity-capable result.

### M4 Action Engine
UI-independent action resolution; Call, WhatsApp where applicable, Open URL, Save path.

## 4. V1 — Useful

### M5a Local Memory
- Local persistence.
- Guest-first.
- CRUD + search.
- Offline.
- Ownership/provenance model ready for future auth/sync.
- Local-data security approach.

**Gate:** Guest Share → Understand → Save → Memory works without account/network.

### M5b Auth + Cloud Sync + RLS
- Approved sign-in.
- Supabase sync.
- Explicit guest migration choice.
- Ownership distinction.
- Unified Memory UX.
- Simple deterministic multi-device sync.
- RLS + bypass tests.
- Sign-out privacy.

**Not required:** CRDT/collaborative sync.

M5b is a cloud-security release blocker.

### M6 Money + Date
RM/MYR, Malaysian DD/MM date baseline, multi-entity presentation, Copy and Date actions.

### M7 Reminder
Local notification; ask for time when missing.

### M8 Basic Protect
Manual URL Security Check → explainable risk level + reasons.

### M9 AI Fallback
Consent, Edge/API boundary, structured output, validation, limits, rate control, timeout/failure behavior.

## 5. Validation

### M10 Founder Alpha
CEO tests at least 50 manual scenarios across core flows.

### M11 Closed Alpha / Beta
5–10 trusted users first, then ~20–50 Malaysian Android users.

Primary question: **Do users naturally remember to Share useful information to TINDAK after several days?**

### M12 Play Store
Release only after Definition of Done, security/privacy review, production AAB and explicit CEO approval.

## 6. V1.5 — Intelligent (Future)
Candidates only: image sharing, OCR, receipt understanding, semantic Memory search, better security intelligence, warranty/document expiry. Each requires future approval.

## 7. V2 — Proactive (Future)
Potential: Memory relationships, proactive follow-up, expiry intelligence, weekly intelligence, cross-Memory understanding, shared/family contexts.

## 8. Feature Gate
Before entering an active milestone:
1. What real user problem is solved?
2. Does it strengthen Share → Understand → Act → Remember → Protect?
3. How frequently is it needed?
4. Does it improve activation/retention?
5. Complexity?
6. Operating cost?
7. Privacy/security risk?
8. Is it necessary now?

Weak case → **BACKLOG**.

## 9. Explicit V1 Backlog
OCR, images, PDFs, voice, iOS, web, family sharing, semantic/vector search, knowledge graph, proactive AI, full expense tracking, advanced warranty/doc management, social features, background clipboard, Accessibility Service, complex multi-device conflict resolution, multiple AI providers.
