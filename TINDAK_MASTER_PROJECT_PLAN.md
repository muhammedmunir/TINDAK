# TINDAK — MASTER PROJECT PLAN

**Status:** Product Direction Locked  
**Platform:** Android  
**Primary Stack:** Flutter + Supabase + GitHub  
**Optional/Selective Services:** Firebase FCM, Gemini API, external threat intelligence  
**Operating Model:** CEO-led, Product Direction by ChatGPT, Technical Lead by Claude

---

## 1. Team Structure

### CEO — Founder
**Owner:** You

Responsibilities:
- Final authority for all product and technical decisions.
- Approve or reject features.
- Approve PRD, UX, architecture, schema, security approach, and releases.
- Own GitHub, Supabase, Play Console, billing, and API credentials.
- Decide budget, pricing, and launch timing.
- Test release candidates on physical Android devices.

### Product Direction — ChatGPT
Responsibilities:
- Product vision.
- PRD.
- MVP scope.
- Product positioning.
- UX requirements.
- User journeys.
- Feature prioritization.
- Roadmap.
- Monetization strategy.
- Product metrics.
- Product review.
- Prevent scope creep.

Primary responsibility:

> Define **WHAT** should be built and **WHY**.

### Technical Lead — Claude
Claude holds three technical roles.

#### System Architect
Responsibilities:
- Flutter architecture.
- Supabase architecture.
- Data model.
- API design.
- State management.
- Package/dependency decisions.
- Performance considerations.
- Offline and caching strategy.

#### Security Reviewer
Responsibilities:
- Threat modeling.
- Supabase RLS review.
- Secret/API-key protection.
- Abuse prevention.
- URL/scam analysis architecture.
- Privacy review.
- Security test design.

#### Coding Agent
Responsibilities:
- Write and modify source files.
- Implement approved specifications.
- Create migrations.
- Run tests.
- Debug.
- Refactor.
- Build APK/AAB.
- Maintain code quality.
- Prepare Git commits and pull requests.

Primary responsibility:

> Define and implement **HOW** the approved product specification works.

---

## 2. Authority Model

```text
CEO        -> APPROVE
ChatGPT    -> SPECIFY PRODUCT
Claude     -> DESIGN + SECURE + IMPLEMENT
GitHub     -> SOURCE OF TRUTH
```

Decision hierarchy:

1. CEO decision.
2. Accepted product decision.
3. PRD.
4. Accepted architecture decision.
5. Existing implementation.

If there is a conflict, Claude must not silently choose a different direction.

Required behavior:

```text
STOP
  ↓
Explain conflict
  ↓
Present options
  ↓
CEO decides
```

---

## 3. Product Definition

# TINDAK

**Tagline:**

> Jumpa sesuatu. Tindak terus.

**Product promise:**

> Share anything. TINDAK knows what you can do with it.

Core product loop:

```text
SHARE
  ↓
UNDERSTAND
  ↓
ACT
  ↓
REMEMBER
  ↓
PROTECT
```

TINDAK is not:
- A generic AI chatbot.
- A full to-do application.
- A screenshot manager.
- A standalone scam scanner.
- A background clipboard reader.
- A productivity dashboard.

TINDAK is:

> An action layer for useful information received or discovered on an Android phone.

---

## 4. Core User Problem

Important information is scattered across:
- WhatsApp.
- Telegram.
- Browser.
- Email.
- SMS.
- Notes.
- Screenshots.

Typical behavior:

```text
Receive information
      ↓
Read
      ↓
"I will do it later"
      ↓
Forget
      ↓
Miss action
```

TINDAK changes the flow to:

```text
Receive information
      ↓
Share to TINDAK
      ↓
Understand
      ↓
Act
      ↓
Remember
```

Example:

```text
"Bro esok meeting 3 petang KLCC. Bawa IC."
```

TINDAK:

```text
Meeting detected

Tomorrow
3:00 PM
KLCC

[Remind]
[Maps]
[Save]
```

The success of TINDAK depends on this experience feeling fast and useful.

---

## 5. Technical Stack

### Flutter
Use for:
- Android application.
- Share Intent receiver.
- User interface.
- Local parser.
- Action engine.
- Local notifications.
- Memory screens.
- Settings.

### Supabase
Use as the primary backend.

Use for:
- PostgreSQL.
- Authentication.
- Row Level Security.
- Edge Functions.
- Storage when required.

### GitHub
Use for:
- Source control.
- Documentation.
- Issues.
- Pull requests.
- CI.
- Releases.
- Architecture decision history.

### Gemini API
Use selectively.

Do not send every input to AI.

AI is only used when:
- Local understanding is insufficient.
- Input is semantically complex.
- Confidence is below an accepted threshold.

### Firebase
Firebase is not part of the initial backend architecture.

Use FCM only when TINDAK later needs real server-triggered push notifications.

For V1 reminders, prefer local notifications.

---

## 6. Architecture Principle — Local First

TINDAK must attempt local understanding first.

```text
Input
 ↓
Normalize
 ↓
Local Understanding
 ↓
Can understand?
 ↙        ↘
YES       NO
 ↓         ↓
Action    AI fallback
```

Benefits:
- Lower API cost.
- Lower latency.
- Better privacy.
- Reduced provider dependency.
- Better resilience.
- Potential partial offline operation.

Do not build:

```text
Every user input
      ↓
Gemini API
```

---

# 7. Release Strategy

Development is divided into vertical slices.

The project must not attempt to build the entire final vision at once.

---

## 8. V0.1 — First Vertical Slice

Goal:

Prove the core Share → Understand → Act → Save flow.

Flow:

```text
WhatsApp / Browser
        ↓
      Share
        ↓
      TINDAK
        ↓
 Phone / URL detection
        ↓
      Actions
        ↓
       Save
        ↓
     Supabase
```

### Supported input
- `text/plain`

### Phone
Example:

```text
0123456789
```

Actions:
- Call.
- WhatsApp.
- Save.

### URL
Example:

```text
https://example.com
```

Actions:
- Open.
- Save.

Do not add more features until this flow is smooth and stable.

---

## 9. V0.2 — Local Understanding Expansion

Add:

### Money
Examples:

```text
RM25
RM25.50
RM 183.50
RM1,500.00
```

Actions:
- Copy.
- Save.

### Date
Examples:

```text
25/09/2026
25-09-2026
25 September 2026
25 Sep 2026
```

Actions:
- Reminder.
- Save.

Core local detectors become:

```text
Phone
URL
Money
Date
```

---

## 10. Understanding Engine Design Requirement

Do not build one large chain of `if/else` regex checks.

Required conceptual structure:

```text
SharedContent
      ↓
ContentNormalizer
      ↓
UnderstandingEngine
      ↓
Entity Detectors
      │
      ├── PhoneDetector
      ├── UrlDetector
      ├── MoneyDetector
      └── DateDetector
      ↓
UnderstandingResult
      ↓
ActionResolver
```

Conceptual structured result:

```json
{
  "entities": [
    {
      "type": "money",
      "value": 183.50,
      "confidence": 0.99
    }
  ],
  "actions": [
    "save"
  ]
}
```

Architecture must allow future detectors without rewriting the whole engine.

---

## 11. V0.3 — Action Engine

The Action Engine must be independent of UI.

Concept:

```text
Entity
  ↓
ActionResolver
  ↓
Available Actions
```

Rules:

### Phone
- Call.
- WhatsApp.
- Save.

### URL
- Open.
- Security Check.
- Save.

### Date
- Reminder.
- Save.

### Money
- Copy.
- Save.

Future types may include:
- Location.
- Email.
- Parcel tracking number.
- Receipt.
- Warranty.
- Document.

These are not V1 requirements unless approved by CEO.

---

## 12. V0.4 — Memory

Memory becomes the retention layer.

Concept:

```text
USER
 │
 └── MEMORIES
       │
       ├── Original content
       ├── Entities
       ├── Source
       ├── Created date
       ├── Updated date
       └── Metadata
```

V1 Memory requirements:
- Create.
- Read.
- Search.
- Delete.

Do not implement in early V1:
- Vector database.
- Embeddings.
- Knowledge graph.
- AI semantic search.
- Automatic relationships.
- Proactive memory.

---

## 13. Authentication Strategy

Do not create heavy onboarding friction.

Avoid:

```text
Install
 ↓
Register
 ↓
Verify email
 ↓
Login
 ↓
Long tutorial
 ↓
Use TINDAK
```

Target:

```text
Install
 ↓
Open
 ↓
Minimal onboarding
 ↓
Share something
 ↓
Magic moment
```

Claude must propose an authentication flow that protects cloud data without destroying activation.

---

## 14. V0.5 — Reminder

Date entity can create local reminders.

Example:

```text
"Bayar TNB 25 September"
          ↓
        TINDAK
          ↓
     25 September

     [Remind]
          ↓
 Local Notification
```

Initial reminders do not require Firebase FCM.

---

## 15. V0.6 — Protect

Security is introduced after the basic action and memory flows work.

URL pipeline:

```text
Shared URL
    ↓
Normalize
    ↓
Validate
    ↓
Local indicators
    ↓
Reputation provider
    ↓
Risk assessment
    ↓
Explanation
```

Security results must be explainable.

Avoid unsupported certainty such as:

```text
SCAM 98%
```

Preferred approach:

```text
HIGH RISK

Why?

- Suspicious URL structure.
- Reputation provider reported a warning.
- Destination does not appear consistent with the claimed organisation.

TINDAK cannot guarantee that the URL is fraudulent.

[Go Back]
[Open Anyway]
```

---

## 16. V0.7 — AI Understanding

AI is added after local understanding is stable.

Example input:

```text
Bro esok lepas lunch jumpa Ahmad dekat KLCC jangan lupa bawa IC dengan proposal.
```

Pipeline:

```text
Local Engine
    ↓
Low confidence
    ↓
AI Gateway
    ↓
Structured Result
```

Conceptual output:

```json
{
  "intent": "meeting",
  "date": "2026-09-11",
  "location": "KLCC",
  "person": "Ahmad",
  "items": [
    "IC",
    "proposal"
  ]
}
```

AI must return structured information that can be validated.

AI does not control UI directly.

---

## 17. API Security Rule

Sensitive API keys must not be embedded directly in Flutter.

Required pattern:

```text
Flutter
   ↓
Supabase Edge Function
   ↓
External API
```

Avoid:

```text
Flutter
   ↓
Secret API Key
   ↓
External Provider
```

Claude, acting as Security Reviewer, must enforce this.

---

# 18. V1 Screens

V1 should remain small.

Target:
- 4 to 5 primary screens.

---

## 18.1 Share Result

Most important screen.

Example:

```text
TINDAK

Bayar bil TNB RM183.50
sebelum 25 September

Detected

RM183.50
25 September

[Remind Me]

[Save]
```

Primary UX requirement:

> The user should quickly understand what TINDAK detected and what they can do next.

---

## 18.2 Memory

Example:

```text
TINDAK

[ Search memories... ]

Today

Bayar bil TNB
RM183.50 • 25 Sep

Ahmad
012-3456789
```

---

## 18.3 Memory Detail

Display:
- Original content.
- Extracted entities.
- Available actions.
- Created date.
- Delete/archive controls if approved.

---

## 18.4 Settings

Initial settings:
- Account.
- Notifications.
- Privacy.
- About.

Subscription settings are added later.

---

## 18.5 Home / Empty State

Minimal screen.

Example:

> Jumpa maklumat penting? Tekan Share dan pilih TINDAK.

Avoid creating a complex dashboard in V1.

---

# 19. Onboarding

Maximum three simple steps.

Example:

```text
1. SHARE

Jumpa sesuatu yang penting?
Share ke TINDAK.

2. ACT

TINDAK cadangkan apa yang
anda boleh lakukan.

3. REMEMBER

Simpan benda penting supaya
senang dicari kemudian.

[Start]
```

Do not explain technical implementation to users.

---

# 20. Flutter Project Structure

Claude can refine the final structure, but it must remain feature-first.

Preferred direction:

```text
mobile/lib/

app/
core/

features/
├── share/
├── understanding/
├── actions/
├── memory/
├── reminders/
├── security/
├── ai/
└── settings/

shared/
```

Avoid an unstructured project full of generic folders with unclear ownership.

---

# 21. Supabase Data Model

Claude must design the actual schema.

The product model should be able to support at least:

```text
profiles

memories

memory_entities

reminders

security_scans

usage_events
```

Claude may simplify the initial schema if justified.

The CEO must approve the schema before the first production migration is considered locked.

---

# 22. Row Level Security

RLS is a release blocker.

Requirement:

User A must never be able to access User B's private memories.

Claude must:
- Enable RLS.
- Write policies.
- Test policies.
- Attempt bypass scenarios.
- Document the results.

Do not accept:

> RLS enabled.

as proof of security.

---

# 23. Git Branch Strategy

Suggested:

```text
main
 │
 └── develop
      │
      ├── feat/share-intent
      ├── feat/understanding
      ├── feat/memory
      ├── feat/reminders
      └── feat/security
```

Rules:
- `main` should remain releasable.
- Experiments do not go directly to `main`.
- Technical Lead works through feature branches and reviewable changes.

---

# 24. Commit Convention

Examples:

```text
feat: add Android share receiver

feat: add Malaysian phone detector

fix: normalize +60 phone numbers

test: add phone detector edge cases

security: enforce memory RLS

refactor: separate action resolver
```

Prefer smaller reversible commits.

---

# 25. Continuous Integration

After the foundation is stable:

```text
Push / Pull Request
        ↓
GitHub Actions
        ↓
flutter analyze
        ↓
flutter test
        ↓
build validation
        ↓
PASS / FAIL
```

Do not automatically deploy production during the early stage.

The CEO approves production releases.

---

# 26. Testing Strategy

Testing is part of implementation.

Do not postpone all testing until the end.

### Unit Tests
Priority:
- Phone parser.
- URL parser.
- Money parser.
- Date parser.
- Normalization.
- Action resolver.
- Security scorer.

### Integration Tests

Test core flow:

```text
Share
 ↓
Understand
 ↓
Action
 ↓
Save
```

### Device Testing
CEO tests critical flows on a physical Android device.

---

# 27. Analytics

Collect only what is useful for product decisions.

Initial events:

```text
onboarding_completed

share_received

entity_detected

action_selected

memory_saved

reminder_created

security_scan_requested

ai_fallback_used
```

Privacy rule:

> Do not send the user's private shared text as analytics content.

---

# 28. North Star Metric

Primary product metric:

# Successful Actions per Weekly Active User

The product should optimize for:

```text
Share
 ↓
TINDAK understands
 ↓
User performs useful action
```

Do not use downloads alone as the primary success metric.

---

# 29. Validation Plan

## Stage 1 — Founder Alpha
User:
- CEO only.

Target:
- At least 50 manual scenarios.
- Find crashes.
- Find parser mistakes.
- Check Share Intent reliability.

## Stage 2 — Closed Alpha
Users:
- Approximately 5 to 10 trusted users.

Focus:
- UX confusion.
- Crash reports.
- Detection mistakes.
- Action failures.

## Stage 3 — Beta
Users:
- Approximately 20 to 50 Malaysian Android users.

Key question:

> Do users naturally remember to use Share → TINDAK after several days?

Measure:
- Activation.
- Share frequency.
- Save frequency.
- Most-used entity types.
- Common failures.

## Stage 4 — Wider Validation
Target:
- 100+ real users.

Evaluate:
- D1 retention.
- D7 retention.
- Successful actions/user.
- Memory save rate.
- AI fallback rate.
- Crash-free usage.

---

# 30. Monetization Strategy

Do not prioritize monetization before product value is proven.

Sequence:

```text
UTILITY
 ↓
ACTIVATION
 ↓
RETENTION
 ↓
MONETIZATION
```

Potential future model:

## Free
- Core local detection.
- Basic actions.
- Basic memory.
- Basic reminders.
- Basic security.

## Pro
Potential features:
- Advanced AI understanding.
- Advanced memory.
- Advanced search.
- Advanced security.
- Future image/PDF processing.
- No ads.

Pricing is not yet locked.

Any pricing decision requires CEO approval after validation data exists.

---

# 31. Product Roadmap

## V0 — Proof

```text
Share
Phone
URL
Actions
Save
```

Goal:
- Prove core interaction.

---

## V1 — Useful

```text
+ Money
+ Date
+ Reminder
+ Memory Search
+ Basic Security
+ AI Fallback
```

Goal:
- Become useful enough for repeated weekly usage.

---

## V1.5 — Intelligent

Potential:
- Image sharing.
- OCR.
- Receipt understanding.
- Better scam detection.
- Semantic memory search.
- Warranty tracking.
- Document expiry.

All require future approval.

---

## V2 — Proactive

Potential:
- Memory relationships.
- Proactive follow-up.
- Warranty expiry.
- Document expiry.
- Weekly intelligence.
- Cross-memory understanding.

This is future scope only.

---

# 32. Explicitly Out of Scope for Initial Development

Do not build unless CEO approves a future change:

- iOS.
- Web app.
- OCR.
- PDF processing.
- Voice.
- Accessibility Service.
- Background clipboard monitoring.
- Background screen reading.
- Social feed.
- Family sharing.
- Knowledge graph.
- Vector database.
- Complex recommendation engine.
- Multiple AI providers.
- Microservices.
- Kubernetes.
- Full finance management.
- Full task management.
- Full CRM.
- Full antivirus/scam suite.

---

# 33. Documentation Structure

Recommended project documentation:

```text
docs/

00_PRODUCT_VISION.md
01_PRD_V1.md
02_PRODUCT_ROADMAP.md
03_UX_FLOWS.md

10_ARCHITECTURE.md
11_DATABASE.md
12_SECURITY.md
13_API.md

20_TEST_PLAN.md
21_RELEASE_PLAN.md

90_DECISIONS.md
91_AI_RULES.md
```

Ownership:

### Product Direction — ChatGPT
- `00_PRODUCT_VISION.md`
- `01_PRD_V1.md`
- `02_PRODUCT_ROADMAP.md`
- `03_UX_FLOWS.md`

### Technical Lead — Claude
- `10_ARCHITECTURE.md`
- `11_DATABASE.md`
- `12_SECURITY.md`
- `13_API.md`
- `20_TEST_PLAN.md`
- `21_RELEASE_PLAN.md`

### Shared Governance
- `90_DECISIONS.md`
- `91_AI_RULES.md`

CEO approves all locked versions.

---

# 34. AI Rules

Create `docs/91_AI_RULES.md`.

Minimum rules:

1. CEO is final authority.
2. ChatGPT owns product direction.
3. Claude owns technical design, security review, and implementation.
4. Claude must not invent product features.
5. Claude must not silently change accepted architecture.
6. No dependency may be added without a clear technical reason.
7. No new backend service may be introduced without approval.
8. Secrets must never be committed.
9. Sensitive API keys must not be embedded in the Flutter client.
10. Tests must not be removed simply to make builds pass.
11. Security controls must not be disabled to fix functional bugs.
12. Any scope conflict must be raised before implementation.
13. MVP scope must remain minimal.
14. Existing ADR decisions are binding until explicitly changed.
15. GitHub documentation is the project source of truth.

---

# 35. Architecture Decision Records

Use `docs/90_DECISIONS.md`.

Initial accepted decisions:

## ADR-001 — Primary Backend
**Decision:** Supabase is the primary backend.  
**Status:** Accepted.

## ADR-002 — Platform
**Decision:** Initial release is Android only.  
**Status:** Accepted.

## ADR-003 — Input
**Decision:** User content enters TINDAK through explicit Android Share Intent.  
**Status:** Accepted.

## ADR-004 — Clipboard
**Decision:** No background clipboard monitoring.  
**Status:** Accepted.

## ADR-005 — Understanding
**Decision:** TINDAK uses local-first understanding.  
**Status:** Accepted.

## ADR-006 — AI
**Decision:** AI is fallback, not the default processing engine.  
**Status:** Accepted.

## ADR-007 — Firebase
**Decision:** Firebase is not required for the initial MVP backend.  
**Status:** Accepted.

## ADR-008 — Notifications
**Decision:** Local notifications are preferred for initial reminders.  
**Status:** Accepted.

## ADR-009 — Security
**Decision:** Security results must be explainable and must not claim unsupported certainty.  
**Status:** Accepted.

## ADR-010 — Technical Authority
**Decision:** Claude acts as System Architect, Security Reviewer, and Coding Agent.  
**Status:** Accepted.

## ADR-011 — Product Authority
**Decision:** ChatGPT acts as Product Direction.  
**Status:** Accepted.

## ADR-012 — Final Authority
**Decision:** CEO retains final approval authority.  
**Status:** Accepted.

---

# 36. Product Feature Workflow

Every product feature follows:

```text
IDEA
 ↓
CEO
 ↓
ChatGPT Product Review
 ↓
Product Specification
 ↓
CEO Approval
 ↓
Claude Architecture
 ↓
Claude Security Review
 ↓
Claude Implementation
 ↓
Automated Tests
 ↓
CEO Device Test
 ↓
ChatGPT Product Review
 ↓
CEO Approval
 ↓
Merge / Release
```

---

# 37. Feature Gate

Before approving a feature, Product Direction evaluates:

```text
Does it solve a real user problem?
Does it support the core loop?
How frequently will users need it?
Does it improve retention?
What is the implementation complexity?
What is the operating cost?
Does it increase security/privacy risk?
Is it necessary for the current release?
```

If the answer is not strong enough:

```text
BACKLOG
```

Not every good idea belongs in V1.

---

# 38. Claude Task Workflow

When assigning a milestone to Claude, use a structured instruction.

Example:

```text
Implement Milestone M2.

Read:
- docs/01_PRD_V1.md
- docs/03_UX_FLOWS.md
- docs/10_ARCHITECTURE.md
- docs/12_SECURITY.md
- docs/90_DECISIONS.md
- docs/91_AI_RULES.md

Scope:
Android Share Intent receiving text/plain only.

Do not implement anything outside this scope.

Before implementation:
1. Explain the plan.
2. List files to be created or modified.
3. Identify technical and security risks.
4. Confirm assumptions against the documentation.

Then implement.

After implementation:
1. Run flutter analyze.
2. Run tests.
3. Report changed files.
4. Report remaining risks.
5. Prepare a clean commit.
```

---

# 39. Milestone Plan

| Milestone | Deliverable | Approval Gate |
|---|---|---|
| M0 | Product documents | CEO approval |
| M1 | Flutter + GitHub foundation | Build passes |
| M2 | Android Share Intent | Real app share works |
| M3 | Phone + URL understanding | Parser tests pass |
| M4 | Action Engine | Real actions work |
| M5 | Supabase Memory | CRUD + RLS works |
| M6 | Money + Date | Parser tests pass |
| M7 | Reminder | Device notification works |
| M8 | Basic Protect | Security tests pass |
| M9 | AI fallback | Complex text works |
| M10 | Founder Alpha | CEO test passes |
| M11 | Closed Beta | Real-user validation |
| M12 | Play Store Release | CEO release approval |

---

# 40. Project Startup Sequence

Do not begin by installing many packages or building many screens.

Use this order.

## Step 1 — Product Pack
Create and lock:

```text
00_PRODUCT_VISION.md
01_PRD_V1.md
02_PRODUCT_ROADMAP.md
03_UX_FLOWS.md
90_DECISIONS.md
91_AI_RULES.md
```

Owner:
- ChatGPT prepares.
- CEO reviews and approves.

## Step 2 — Technical Pack
Give Product Pack to Claude.

Claude prepares:

```text
10_ARCHITECTURE.md
11_DATABASE.md
12_SECURITY.md
13_API.md
20_TEST_PLAN.md
21_RELEASE_PLAN.md
```

## Step 3 — Technical Review
CEO + Product Direction review Claude's proposal.

Questions:
- Does architecture support product goals?
- Is it too complex?
- Is security adequate?
- Is scope still V1?
- Are costs reasonable?
- Are dependencies justified?

## Step 4 — Architecture Lock
CEO approves technical direction.

Only then are architectural decisions considered accepted.

## Step 5 — Repository Setup
Create GitHub repository and documentation structure.

## Step 6 — Flutter Foundation
Claude implements M1.

## Step 7 — Supabase Foundation
Create approved database and security configuration.

## Step 8 — Core Vertical Slice
Build:

```text
WhatsApp / Browser
        ↓
      Share
        ↓
      TINDAK
        ↓
 Phone / URL
        ↓
     Actions
        ↓
      Memory
```

## Step 9 — Founder Testing
CEO tests on a physical Android device.

## Step 10 — Expand Only After Core Works
Proceed to:
- Money.
- Date.
- Reminder.
- Protect.
- AI fallback.

---

# 41. Definition of Initial V1 Done

TINDAK V1 is not done simply because an AAB builds.

Minimum Definition of Done:

- Flutter Android app runs reliably.
- Android Share Intent works from real apps.
- `text/plain` input works.
- Phone detection works.
- URL detection works.
- Money detection works.
- Date detection works.
- Action Resolver works.
- Call action works.
- WhatsApp action works.
- URL open action works.
- Reminder works.
- Memory create works.
- Memory read works.
- Memory search works.
- Memory delete works.
- Supabase Auth works.
- RLS is tested.
- Basic URL security flow works.
- AI fallback works for approved complex text cases.
- Parser tests pass.
- Integration tests pass.
- `flutter analyze` passes.
- Physical-device testing passes.
- Critical privacy checks pass.
- Release AAB builds.
- CEO approves release.

---

# 42. Final Operating Model

```text
                   CEO
                   YOU
                    │
          "What should we build?"
                    │
                    ▼
               CHATGPT
          PRODUCT DIRECTION
                    │
             PRODUCT SPEC
                    │
                    ▼
                   CEO
                APPROVE
                    │
                    ▼
                 CLAUDE
            SYSTEM ARCHITECT
                    │
             SECURITY REVIEW
                    │
               IMPLEMENT
                    │
                 TEST
                    │
                    ▼
                 GitHub
                    │
                    ▼
                 TINDAK
                    │
                    ▼
              CEO DEVICE TEST
                    │
                    ▼
               REAL USERS
                    │
             DATA + FEEDBACK
                    │
                    ▼
               CHATGPT
             NEXT DECISION
```

---

# 43. Locked Direction

The following project direction is considered locked unless the CEO changes it:

- Product: TINDAK.
- Platform: Android first.
- Core loop: Share → Understand → Act → Remember → Protect.
- Product Direction: ChatGPT.
- System Architect: Claude.
- Security Reviewer: Claude.
- Coding Agent: Claude.
- Final Authority: CEO.
- Frontend: Flutter.
- Primary backend: Supabase.
- Repository: GitHub.
- Understanding: Local-first.
- AI: Selective fallback.
- Notification: Local first; FCM only when needed.
- Monetization: Later, after utility and retention are validated.
- MVP philosophy: Minimal vertical slices before expansion.
- Source of truth: GitHub documentation.
