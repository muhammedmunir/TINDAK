# 91 — AI RULES

**Owner:** Shared governance (CEO + Product Direction + Technical Lead)
**Status:** Accepted
**Source:** `TINDAK_MASTER_PROJECT_PLAN.md` Section 34

These rules are binding on every AI participant in this project. They are
transcribed from the locked master plan and may only be changed by the CEO.

---

## Rules

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

## Conflict Procedure

When an instruction conflicts with an accepted decision, the PRD, or an existing
ADR, the Technical Lead must not silently pick a direction.

```text
STOP
  |
Explain conflict
  |
Present options
  |
CEO decides
```

## Decision Hierarchy

1. CEO decision.
2. Accepted product decision.
3. PRD.
4. Accepted architecture decision.
5. Existing implementation.

## Role Boundary

```text
ChatGPT  ->  WHAT and WHY
Claude   ->  HOW
CEO      ->  APPROVE
```
