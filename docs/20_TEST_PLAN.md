# 20 — TEST PLAN

**Owner:** Technical Lead (Claude)
**Status:** BLOCKED — waiting for Product Pack approval
**Approval:** CEO

> Scaffold only.

## Principle

Testing is part of implementation, not a phase at the end (Section 26).
Tests are never deleted to make a build pass (AI Rule 10).

## Unit test priorities

- Phone parser, including Malaysian formats and `+60` normalization.
- URL parser.
- Money parser: `RM25`, `RM25.50`, `RM 183.50`, `RM1,500.00`.
- Date parser: `25/09/2026`, `25-09-2026`, `25 September 2026`, `25 Sep 2026`.
- Content normalization.
- Action resolver.
- Security scorer.

## Integration tests

```text
Share -> Understand -> Action -> Save
```

## Security tests

RLS bypass attempts, documented with results. Release blocker.

## Device testing

CEO runs critical flows on a physical Android device. Founder Alpha target is at
least 50 manual scenarios (Section 29).

## CI

```text
Push / PR -> flutter analyze -> flutter test -> build validation -> PASS / FAIL
```

No automatic production deploy during the early stage.
