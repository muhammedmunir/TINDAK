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

## Known environment issues

### ENV-1 — Android SDK XML version mismatch

`flutter build apk` prints:

```text
Warning: SDK processing. This version only understands SDK XML versions up to 3
but an SDK XML file of version 4 was encountered. This can happen if you use
versions of Android Studio and the command-line tools that were released at
different times.
```

The build succeeds and the artifact is correct, so this is not a blocker. It is
a toolchain mismatch: the Android Gradle Plugin's bundled SDK parser is older
than the installed command-line tools.

**Fix by aligning the toolchain** — update Android Studio and the command-line
tools to matching releases, or pin the same versions on every machine and in
CI. **Do not silence it by lowering `compileSdk`, `targetSdk`, or the Android
Gradle Plugin version.** Those are product-facing settings and moving them to
quiet a log line would be trading a real property for a cosmetic one.

Left as-is until CI exists (M1 gate onward), because CI is where a local/CI
toolchain divergence would actually start to hurt.

## Status

M1 — foundation. No Share Intent, no detectors, no actions, no Memory, no
Supabase, no auth, no sync, no reminders, no Protect, no AI. Each arrives at its
own milestone behind its own CEO gate.
