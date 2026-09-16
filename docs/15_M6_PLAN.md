# 15 — M6 PLAN: Money + Date Understanding

**Owner:** Technical Lead (Claude)
**Status:** PROPOSED — awaiting Product Direction review. No code written.
**Baseline:** `develop @ 8d8001b`
**Inputs:** M6 Product Direction Brief (2026-09-16), `10_ARCHITECTURE.md` §5–§6
and §15.2, `11_DATABASE.md` §4, `20_TEST_PLAN.md` §3–§4 and §6, ADR-023,
ADR-026, PD-007, PD-025, PD-027, PD-029, PD-032, PD-037

---

## 1. Reconciliation — the brief against what is built

| Brief requirement | State on `develop` | Work needed |
|---|---|---|
| Money and Date detection, local only | `UnderstandingEngine` runs a list of detectors over normalised text; adding one is a list entry | two new detectors |
| DD/MM/YYYY, no locale guessing | specified in `20_TEST_PLAN.md` §4 | implement as specified |
| Two-digit years rejected | ADR-026 | implement |
| No-year dates resolve to next occurrence | PD-025, `10_ARCHITECTURE.md` §15.2 | implement; needs a clock in the engine (§4.3) |
| Exact money, no float error | ADR-023: integer sen | implement |
| Multi-entity, order by position | engine already sorts by start offset and resolves overlaps centrally | no change |
| No regression in phone, URL, IC guard, Unicode safety | enforced by existing tests, kept and extended | new detectors must not widen those spans |
| Memory save and search by extracted value | `MemorySearch.searchValueFor` maps type → searchable text | add money and date cases (§4.5) |
| No AI, works offline | understanding is pure Dart with no I/O; a test forbids network imports | no change |
| Cloud unchanged | the deployed entity table already allows `money` and `date`; the local table does not constrain type | **no migration, no schema version bump** |

**Nothing in the brief requires a cloud change, an auth change or a database
migration.** That is the most important reconciliation result: M6 is additive
inside the understanding and actions layers.

---

## 2. What M6 must not become

Out of scope, stated so the plan cannot drift: expense tracking, categories,
merchants, budgets, currency other than MYR, relative time words (`esok`,
`minggu depan`), clock times, notification scheduling, permissions, and any AI
path. Reminder scheduling stays M7.

---

## 3. Gate split

- **M6a — Understanding.** `EntityType` gains `money` and `date`; the two
  detectors; overlap priority; the full detector test suite. Nothing user-facing
  changes except that two more entity kinds appear in the result list.
- **M6b — Actions and Memory.** `Salin` for money, the `Ingatkan` contract for
  date, entity row labels and icons, Memory search values, integration and
  regression tests, offline verification, emulator run.

Each gate ends with a report and a stop.

---

## 4. Technical proposal

### 4.1 Money detector

Scans normalised text for `RM` or `MYR`, case-insensitive, not preceded or
followed by a letter or digit, then optional space, then the amount.

Amount grammar, deliberately strict:

```text
digits            ::= [0-9]+
grouped           ::= [0-9]{1,3} ( "," [0-9]{3} )+
amount            ::= ( digits | grouped ) ( "." [0-9]{1,2} )?
```

- Value is computed in **integer sen** by string arithmetic, never through a
  double: `1,500.5` → `150050`, `183.50` → `18350`, `25` → `2500`.
- `normalized_value` is `MYR<sen>`, e.g. `MYR18350`, matching `11_DATABASE.md`
  §4 ("integer sen, plus MYR") in a single stable string.
- `raw_value` is the matched text from the normalised content, as today.
- Rejected, producing no entity: `RM`, `RM.`, `RM1,2`, `RM12.345`, `RM-25`,
  `ROOM25`, and any bare number with no marker. A malformed amount never falls
  back to a partial value — the whole candidate is dropped.
- Confidence: 0.95 with a decimal or thousands separator, 0.90 otherwise. Both
  are high because the `RM` marker is explicit; the number itself is not a guess.

### 4.2 Date detector

Two shapes only:

1. **Numeric** `D/M/YYYY`, `D-M-YYYY`, `D.M.YYYY`, one or two digit day and
   month, **four-digit year, always DD/MM** (PD-008). Two-digit years are
   rejected outright (ADR-026), including `25/08/26`.
2. **Month name** `D <month> [YYYY]`, month names in Malay and English, full and
   abbreviated, from the table in `20_TEST_PLAN.md` §4. `Mac` and `Mei` map to
   March and May.

- Calendar validity is checked by constructing the date and comparing the parts
  back, so `31/02/2026`, `31/04/2026` and `29/02/2025` are rejected while
  `29/02/2028` is accepted.
- `normalized_value` is ISO-8601 `YYYY-MM-DD` (`11_DATABASE.md` §4).
- No year: resolve to the **next occurrence** against today — this year if the
  date is today or still ahead, next year if it has passed (PD-025). Today
  resolves to today, as the brief states.
- Confidence: 0.95 with an explicit four-digit year, 0.85 when the year was
  inferred — lower because a year TINDAK supplied is worth less certainty than
  one the user wrote.

### 4.3 The clock reaches the engine

Next-occurrence needs today's date. `UnderstandingEngine` is currently a `const`
with no clock, and `understandingEngineProvider` builds it with no arguments.

Proposal: `DateDetector` takes a `Clock` (already pure Dart in `core/clock`),
`UnderstandingEngine` takes an optional `Clock` used to build its default
detector list, and the provider passes `clockProvider`. Tests pin the clock, as
`20_TEST_PLAN.md` §4.4 requires. The understanding layer stays free of Flutter
and I/O, so the purity test still passes.

### 4.4 `yearInferred` without a schema change

PD-025 requires the flag; the entity table has no column for it and the brief
asks for no migration. It does not need one: an entity is year-inferred exactly
when its `raw_value` carries no four-digit year, which is deterministic and
survives a save, a sync and a pull.

Proposal: `DetectedEntity` gains a computed `yearInferred` for the date type,
derived from `raw_value`. Nothing is stored, nothing migrates, and M7 can still
tell the difference. If Product Direction would rather have it persisted
explicitly, that is a schema v3 and a cloud migration, and it should be decided
now rather than after M7 starts (see §6, A-4).

### 4.5 Search values

`MemorySearch.searchValueFor` gains two cases, lowercased as the others are:

| Type | `search_value` | Finds |
|---|---|---|
| money | `rm183.50 183.50 18350` | `RM183.50`, `183.50`, `18350`, and digit queries via the existing digits rule |
| date | `2026-09-25 25/09/2026 25 september 2026` | ISO, the way it was typed, and the month-name form |

Pulled rows rebuild these locally, so a device that pulls a money entity written
by another device gets the same searchable text.

### 4.6 Actions

- `ActionKind.copy` — **Salin**, for money. Writing to the clipboard is not
  reading it, so ADR-004 is untouched. It goes in a new
  `actions/executor/clipboard_writer.dart`, the same boundary pattern as
  `ExternalLauncher`; the resolver stays pure and the purity test is extended to
  keep `flutter/services` confined to that file.
- `ActionKind.remind` — **Ingatkan**, for date. M6 resolves and displays it, and
  **schedules nothing**. What a tap does in the alpha build is a product
  decision, not mine (§6, A-1).
- `EntityRow` gains `Wang` (money) and `Tarikh` (date) labels with icons, and
  display values: money as `RM1,500.00`, date as `25 September 2026` (§6, A-2
  and A-3).

### 4.7 Overlap priority

`EntityType.priority` becomes url 0, phone 1, date 2, money 3. It only decides
ties between identical spans of equal confidence, which these types cannot
produce today; it is set explicitly so behaviour stays deterministic.

---

## 5. Test plan additions

Beyond the brief's minimum set:

- **Money:** `MYR99`, `rm25.50`, `RM 1,234,567.89`, `RM1,500` (no decimals),
  two amounts in one message, `RM25.5` (one decimal), amount inside a URL is not
  money, `RM` at end of text, `RM0.01`, `RM0`, `1,500` alone, `RM25.555`,
  `RM1,23`, `ROOM25`, `RM-25`, and an amount with a zero-width space inside it.
- **Date:** all separators, both languages, `1 Mac 2026` vs `1 Mar 2026`,
  `25 Ogos` with the clock pinned before, on and after that date, `29/02/2028`,
  `29/02/2025`, `31/04/2026`, `25/08/26`, `2026` alone, `0341234567` is not a
  date, `25/09/2026` produces no phone or money entity.
- **Interaction:** phone + money + date + URL in one message, order by position,
  a date inside a URL path is not a date, an IC number is still not a phone and
  not a date, `RM1234567890` is still not a phone.
- **Memory:** save and find by `183.50`, by `18350`, by `25/09/2026` and by
  `2026-09-25`; a pulled money entity is searchable after sync.
- **Regression:** the whole existing suite, unchanged, must still pass.

---

## 6. Ambiguities for Product Direction

Implementation does not start until these are answered.

**A-1 — What does `Ingatkan` do in M6?** M7 owns scheduling, and the brief
forbids pretending. Options: (a) show the button and, on tap, a plain line such
as *"Peringatan belum tersedia dalam versi ini."*; (b) show the date entity with
`Simpan` only, and introduce `Ingatkan` in M7. (a) shows the shape of the
product and needs one approved string; (b) ships nothing a user can be
disappointed by. **Recommendation: (a)**, with the copy approved by Product
Direction.

**A-2 — Money display form.** Proposal: always canonical — `RM183.50`,
`RM1,500.00`, `RM25.00`. A user who wrote `rm25` sees `RM25.00`. The alternative
is echoing what they typed, which makes two identical amounts look different.
**Recommendation: canonical.**

**A-3 — Date display form.** Proposal: `25 September 2026`, matching UX §8, with
Malay month names (`Mac`, `Ogos`, `Disember`). For a year-inferred date the full
resolved date is shown, so the inference is visible before M7 uses it.

**A-4 — `yearInferred`: derived or stored?** §4.4 derives it, with no migration.
Storing it means schema v3 plus a cloud migration, and is only worth doing if
Product Direction wants the flag to be independent of the original text.
**Recommendation: derived.**

**A-5 — Money with no `RM` marker.** The brief says `RM` is the signal. So
`1,500` stays undetected even in `Bayar 1,500 sebelum 25/09/2026`. Confirming,
because it is the most likely "why didn't it catch this" report from alpha.

**A-6 — `Salin` copies which form?** Proposal: the canonical display text
(`RM183.50`), not `MYR18350` and not the raw span. It is what a person would
paste into a banking app.

---

## 7. Order of work, once approved

1. M6a: `EntityType`, `MoneyDetector`, `DateDetector`, clock wiring, priority,
   detector tests. Report and stop.
2. M6b: `Salin` and the `Ingatkan` contract, entity row, search values,
   integration and regression tests, offline check, emulator verification.
   Report and stop for the M6 gate.

No cloud change, no schema change, no new dependency.
