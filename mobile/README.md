# TINDAK — Android app

Flutter application. Android only (ADR-002).

Project documentation lives in [`../docs`](../docs); this file covers only how
to run the code.

## Requirements

Matches the toolchain M1 was built and verified against:

| | |
|---|---|
| Flutter | 3.41.0 stable |
| Dart | 3.11.0 |
| JDK | 17 |
| Android SDK | 36 |
| minSdk | 24 (Android 7.0) |
| targetSdk | 36 |
| Application id | `my.tindak.app` |

## Commands

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # must pass
flutter build apk --debug
```

## Configuration

Cloud values are supplied at build time, never committed:

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Both are public, RLS-scoped values. **No secret key belongs in this project** —
Gemini and reputation-provider keys live in Supabase Edge Function config and
are reached through an Edge Function (docs/12_SECURITY.md §6, AI Rule 9).

Running with no `--dart-define` is a supported state. TINDAK is guest-first and
local-first: the core loop needs no cloud configuration.

## Structure

Feature-first, per [`../docs/10_ARCHITECTURE.md`](../docs/10_ARCHITECTURE.md) §4.

```text
lib/
├── app/        shell, routes, theme
├── core/       result, failure, clock, config, logging
├── features/   one folder per feature, filled in by its own milestone
└── shared/     reusable widgets and formatters
```

`features/understanding` and `features/actions/resolver` must stay pure Dart —
no Flutter imports, no I/O. That is what keeps the largest and most
failure-prone part of the product testable on the Dart VM without an emulator.

## Status

M1 — foundation. No Share Intent, no detectors, no actions, no Memory, no
Supabase, no auth, no sync, no reminders, no Protect, no AI. Each arrives at its
own milestone behind its own CEO gate.
