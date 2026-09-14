# 01 — PRD V1

**Product:** TINDAK  
**Owner:** Product Direction (ChatGPT)  
**Approval:** CEO  
**Status:** READY FOR CEO APPROVAL

## 1. Objective
Build the smallest reliable Android product that proves:

```text
SHARE → UNDERSTAND → ACT → REMEMBER → PROTECT
```

## 2. Input Scope
**In:** two explicit, user-initiated paths (PD-033, ADR-029):

1. Android Share Intent, `text/plain`, from apps that offer Android sharing.
2. **Manual Paste** — the user copies text in any app, opens TINDAK and presses
   Tampal. The clipboard is read only in response to that press.

WhatsApp's message context menu offers no Android share for a plain text
message, which is why path 2 exists. No document or screen may instruct a user
to share a WhatsApp text message.

**Out:** images, OCR, PDFs, voice, **clipboard monitoring, polling, or any
reading of the clipboard that the user did not just ask for**, Accessibility
Service, background message/screen reading, `ACTION_PROCESS_TEXT` (PD-034).

## 3. Authentication & Persistence
- **Guest-first:** account is not required for core use.
- Guest Memory is saved locally.
- Supabase is the primary **cloud** backend.
- Sign-in enables cloud synchronization.
- Core Share → Understand → Act → local Memory must not depend on connectivity or authentication.
- Technical Lead selects local persistence technology.

### Guest → sign-in
Existing local Memories must **not** be silently uploaded. After first sign-in, present an explicit choice such as:

```text
Sync 40 saved items to your account?
[Not Now] [Sync]
```

`Not Now` keeps them local and sync may be enabled later.

### Sign-out
Account-owned private data must not remain normally readable through TINDAK without re-authentication. Technical Lead designs ownership/provenance, encryption, cache and key behavior. Guest-only data must be distinguishable from account-owned data.

### Guest uninstall
Unsynced guest data may be lost after uninstall/app-data clearing. Communicate this in Memory/Settings without blocking first use.

## 4. Understanding — Required V1 Entities
1. Phone.
2. URL.
3. Money.
4. Date.

TINDAK must retain **multiple meaningful entities** from one input. Ranking for presentation is allowed; discarding relevant entities is not.

Example:
`Bayar bil TNB RM183.50 sebelum 25 September` → Money + Date.

## 5. Phone
Required baseline examples:

```text
0123456789
012-3456789
012-345 6789
+60123456789
011-12345678
03-1234 5678
```

Support Malaysian mobile, +60, common spacing/hyphens and Malaysian landlines. Short codes are out of scope.

Actions: **Call / WhatsApp where applicable / Save.**

## 6. URL
Detect HTTP/HTTPS URLs.

Actions: **Open / Security Check / Save.**

External reputation checking is manual, not automatic.

## 7. Money
Required examples: `RM25`, `RM25.50`, `RM 183.50`, `RM1,500.00`.

V1 focuses on RM/MYR.

Actions: **Copy / Save.**

No full expense management.

## 8. Date
Required baseline:

```text
25/09/2026
25-09-2026
25 September 2026
25 Sep 2026
25 Ogos 2026
```

Ambiguous numeric dates use Malaysian **DD/MM/YYYY**. Therefore `03/04/2026` = 3 April 2026.

Actions: **Reminder / Save.**

If no reliable time exists, Reminder must ask the user to select a time. TINDAK must not silently invent one.

## 9. Save
**Manual Save only.**

```text
Share → Process → Result → user taps Save → Memory
```

Share is not consent for persistent storage.

## 10. Memory V1
Required:
- Create.
- Read/list.
- Search.
- Delete.

Search covers original text plus normalized/extracted entity values. No semantic/vector/AI Memory search.

Delete is user-visible hard delete in V1. No Trash/Archive.

After sign-in, local/cloud data must appear as **one coherent Memory experience**, not separate Local and Cloud tabs. Human-readable status such as `On this device`, `Synced`, or sync error may appear when relevant.

## 11. Offline
Without internet, supported flows should still allow:
- Receive supported shared text.
- Local normalization/detection.
- Local-capable actions.
- Local Memory create/read/search/delete.
- Local reminders.

Cloud-only operations fail gracefully.

## 12. Multi-device
V1 does not require CRDT or sophisticated real-time collaborative conflict resolution. Signed-in devices may access cloud-synced Memories using the simplest safe deterministic sync strategy proposed by Technical Lead.

## 13. Reminder
Use local notifications for V1 unless a later approved requirement needs server push. User explicitly creates reminders. Missing time requires user selection.

## 14. Protect
Security Check is user-triggered.

Risk vocabulary:
- LOW RISK
- CAUTION
- SUSPICIOUS
- HIGH RISK

Results must explain reasons and must not claim unsupported certainty or invented percentages. External provider choice remains Technical Pack scope.

## 15. AI Fallback
AI is not the default parser. It is used for approved complex/low-confidence semantic cases.

Before first cloud-AI processing:
- disclose that content may leave the device;
- obtain consent;
- allow decline without disabling local functionality.

AI output must be structured and validated; AI does not control arbitrary UI.

Technical Pack must propose and justify:
- maximum input size;
- rate limit/quota;
- timeout;
- abuse controls;
- failure handling;
- structured-response validation.

## 16. Share Result
V1 uses a **full-screen TINDAK experience**, not a floating overlay over the source app.

Show shared content/representation, all relevant entities, relevant actions, Save and clear unknown/error states.

## 17. External Actions
Call/WhatsApp/Open may launch another Android app. TINDAK must not force-close itself. Normal Android navigation/recent state should remain sensible.

## 18. Nothing Detected
Show the original content and:

> TINDAK belum dapat mengenal pasti tindakan untuk kandungan ini.

Offer **Save**. `Try AI` may be offered when available and consent rules allow it.

## 19. Screens
1. Share Result.
2. Memory.
3. Memory Detail.
4. Settings.
5. Minimal Home/Empty State if required.

No complex dashboard.

## 20. Onboarding
Maximum three lightweight concepts: **Share / Act / Remember**. No forced registration.

## 21. Analytics & Privacy
Useful events may include `onboarding_completed`, `share_received`, `entity_detected`, `action_selected`, `memory_saved`, `reminder_created`, `security_scan_requested`, `ai_fallback_used`.

Never send private shared text as analytics content.

## 22. Explicit V1 Out-of-Scope
iOS, web, OCR, image understanding, PDFs, voice, clipboard monitoring, Accessibility Service, full expense management, chatbot, semantic/vector Memory search, knowledge graph, proactive AI, family sharing, social features, complex CRDT sync, multiple AI-provider orchestration, advanced threat-intelligence platform.

## 23. Acceptance Criteria
- Real Android `text/plain` Share Intent works.
- Phone/URL/Money/Date baseline cases are tested.
- Multiple relevant entities coexist.
- Simple supported cases stay local.
- Guest can use and save without account.
- Offline local Memory CRUD/search works.
- Guest Memories are not silently uploaded after sign-in.
- Cross-user cloud isolation/RLS is tested.
- Signed-out account data is protected from normal access.
- Reminder without time asks for time.
- Protect is user-triggered and explainable.
- First cloud-AI use obtains consent.
- Declining AI leaves local features usable.
- `flutter analyze`, approved tests and physical-device critical flows pass.
- CEO approves release.

## 24. Locked Product Decisions
Guest-first; local-first persistence; Supabase as primary cloud backend; manual Save; multi-entity; search text + entities; offline core; hard delete V1; no invented reminder time; DD/MM/YYYY; Malaysian phone baseline; explicit AI consent; manual Protect; full-screen Share Result; no forced app close after external action; unknown content remains saveable; explicit guest migration; sign-out privacy; no CRDT V1; guest uninstall loss accepted with disclosure; unified Memory UX.
