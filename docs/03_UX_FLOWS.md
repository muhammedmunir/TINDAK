# 03 — UX FLOWS

**Owner:** Product Direction (ChatGPT)  
**Approval:** CEO  
**Status:** READY FOR CEO APPROVAL

## 1. Principles
Fast, focused, predictable, user-controlled, privacy-conscious and useful without an account. The Share Result is the most important V1 experience.

## 2. Navigation

Normal launch:

```text
TINDAK → Memory / Empty State → Memory Detail
                         └────→ Settings
```

Share:

```text
Source App → Android Share → TINDAK full-screen Share Result
```

## 3. Onboarding
Maximum three lightweight concepts:

1. **SHARE** — “Jumpa sesuatu yang penting? Share ke TINDAK, atau salin dan
   tampal.”
2. **ACT** — “TINDAK cadangkan apa yang anda boleh lakukan seterusnya.”
3. **REMEMBER** — “Simpan benda penting supaya senang dicari kemudian.”

CTA: `[Start]`

No forced registration or unnecessary permission wall.

Per-app guidance, when it is shown at all (PD-033):

| App | Guidance |
|---|---|
| WhatsApp | Copy → TINDAK → Tampal |
| Browsers and apps with Android share | Share → TINDAK |

Never tell a user to share a WhatsApp text message. They cannot.

## 3.1 Paste intake

```text
Any app ─► Copy ─► open TINDAK ─► [Tampal] ─► same result screen as a share
```

The clipboard is read **only** when the user presses Tampal. Never at launch,
never on resume, never in the background (ADR-004, PD-033). Android may show its
own "pasted from clipboard" notice; that transparency is welcome, not something
to suppress.

Empty or non-text clipboard:

```text
Tiada teks untuk ditampal.
```

A quiet line, then the user is still on Home. Nothing else changes.

## 4. Empty State

```text
TINDAK

Jumpa maklumat penting?
Share ke TINDAK, atau salin teks
dan tampal di sini.

[ Tampal ]
```

No complex dashboard.

Two intake paths, both explicit (PD-033). The previous copy told users to share
a WhatsApp message; physical testing showed WhatsApp offers no Android share for
a text message, so that instruction was wrong and has been removed.

If the clipboard holds no usable text, fail quietly — a short message, never a
dramatic error.

## 5. Phone Share Result

```text
TINDAK

Hubungi saya 012-3456789

Detected
📞 012-3456789

[Call] [WhatsApp]

[Save]
```

Only applicable actions appear.

## 6. URL Share Result

```text
TINDAK

https://example.com

Detected
🔗 example.com

[Open] [Security Check]

[Save]
```

Security Check is manual.

## 7. Money Share Result

```text
TINDAK

Bayar RM183.50

Detected
💰 RM183.50

[Copy]

[Save]
```

## 8. Date Share Result

```text
TINDAK

Temujanji 25 September 2026

Detected
📅 25 September 2026

[Reminder]

[Save]
```

If no time exists:

```text
Set reminder time
25 September 2026

[Select time]

[Cancel] [Create Reminder]
```

No silent default time.

## 9. Multi-Entity

```text
TINDAK

Bayar bil TNB RM183.50
sebelum 25 September

Detected
💰 RM183.50
📅 25 September

[Remind]

[Save]
```

Keep all meaningful entities. UI may prioritize actions without discarding entities.

## 10. Manual Save
`Share Result → [Save] → Saved locally/synced as applicable.`

Guest feedback may say: `✓ Saved on this device`.

Never auto-save every share.

## 11. Guest → Sign-In
If guest has local Memories:

```text
You're signed in

You have 40 items saved on this device.
Sync them to your account?

[Not Now] [Sync 40 Items]
```

No silent upload. `Not Now` keeps them local.

## 12. Guest Data Disclosure
In Memory/Settings, not before first value:

```text
Saved on this device

Items stored only on this device may be lost
if TINDAK is uninstalled.

[Sign in to enable sync]
```

## 13. Sign-Out
After sign-out, account-owned private data must not remain normally accessible without authentication. Guest-only items follow the approved ownership model. If local account cache is removed, confirmation should explain that clearly.

## 14. Memory

```text
TINDAK

[ Search memories... ]

Today

Bayar bil TNB
RM183.50 • 25 Sep

Ahmad
012-3456789
```

One unified Memory experience; no separate Local/Cloud tabs.

## 15. Search
One search field across original text and extracted entity values. No AI semantic search V1.

## 16. Memory Detail

```text
TINDAK

Bayar bil TNB RM183.50
sebelum 25 September

Detected
💰 RM183.50
📅 25 September

Saved
Today, 8:42 PM

[Reminder]
[Delete]
```

Where relevant: `On this device`, `Synced`, or a clear sync-error state. Do not expose database terminology.

## 17. Delete

```text
Delete this saved item?

This action cannot be undone.

[Cancel] [Delete]
```

No Trash/Archive V1.

## 18. Offline
If locally understandable:

```text
Share → Local detection → Share Result → local actions / Save
```

For a cloud-only action:

```text
You're offline

This action needs an internet connection.
Your saved items on this device are still available.

[OK]
```

Do not show a generic internet failure for operations that can work locally.

## 19. Nothing Detected

```text
TINDAK

<original content>

TINDAK belum dapat mengenal pasti
tindakan untuk kandungan ini.

[Try AI] [Save]
```

`Try AI` only when available and consent rules allow it. Save always remains available.

## 20. First AI Consent

```text
AI Understanding

TINDAK can use cloud AI to understand text
that cannot be fully understood on this device.

The content being analysed may be sent to
an AI service for processing.

[Not Now] [Continue]
```

Declining must leave local features usable. Final privacy/legal wording is reviewed before production.

## 21. AI Failure

```text
TINDAK couldn't complete AI understanding.

Your local TINDAK features still work.

[Save] [Try Again]
```

Do not lose the shared content.

## 22. Security Check

```text
HIGH RISK

Why?
• Suspicious URL structure
• Reputation service reported a warning
• Destination may not match the claimed organisation

TINDAK cannot guarantee that this link is
safe or fraudulent.

[Go Back] [Open Anyway]
```

Risk levels: LOW RISK / CAUTION / SUSPICIOUS / HIGH RISK.

No invented scam percentages or guaranteed-safety wording.

## 23. Security Provider Failure

```text
Security check unavailable

TINDAK couldn't complete the external
security check right now.

This does not mean the link is safe.

[Go Back] [Open Anyway]
```

Failure is never treated as a clean result.

## 24. External Actions
Call/WhatsApp/Open launch the appropriate Android destination. TINDAK does not force-close. Returning should preserve sensible context where practical.

## 25. Settings
Initial categories may include:
- Account.
- Cloud Sync.
- Notifications.
- AI & Privacy.
- Privacy.
- About.

No subscription settings until monetization is approved.

## 26. Error Rule
Every error should answer:
1. What happened?
2. What can the user still do?
3. What should they do next?

Avoid technical dumps.

## 27. Permissions
Ask only when a user reaches a feature that genuinely needs a permission. Do not front-load unnecessary permissions.

## 28. UX Non-Goals
No chat UI, complex dashboard, social feed, OCR/image editor, expense dashboard, knowledge graph, separate Local/Cloud Memory products, automation builder, family workspace or proactive AI feed.

## 29. UX Acceptance Checklist
- First use works without account.
- Share Result is full-screen and understandable.
- Simple local detection feels immediate.
- Multi-entity result is clear.
- Save is manual.
- Guest Memory works offline.
- Search is simple.
- Missing reminder time prompts user.
- Unknown content remains saveable.
- First cloud-AI use asks consent.
- Security Check is user-triggered.
- Security failure never implies safety.
- Sign-in does not silently upload guest Memory.
- Sync status is understandable when relevant.
- Sign-out protects account-owned data.
- Users never need to understand Supabase, RLS or local DB internals.
