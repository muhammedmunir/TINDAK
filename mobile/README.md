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

For local runs, copy `mobile/.env.client.example` to `mobile/.env.client`
(git-ignored), fill in the two values, and pass the file:

```bash
flutter run --dart-define-from-file=.env.client
```

A separate client file, not the root `.env`, on purpose: every key in the file
passed to the build becomes a compile-time define, so a server secret sitting
in the same file would be one typo away from the APK.

Never paste the values into source, a committed file, an issue or a PR — the
repository is public.

Running with no cloud configuration is a supported state. TINDAK is guest-first
and local-first: the core loop needs no cloud, and Settings says Cloud Sync is
unavailable in that build.

### Supabase email template (M5b)

Sign-in is a six-digit code typed in the app (ADR-020). Supabase's default
"Magic Link" email sends a link, not a code. In the Dashboard → Authentication →
Email Templates, set **Magic Link** (and **Confirm signup**, used for a first
sign-in) to the copy approved by Product Direction:

Subject: `Kod log masuk TINDAK`

```html
<h2>Kod log masuk TINDAK</h2>
<p>Kod log masuk anda ialah <strong>{{ .Token }}</strong>.</p>
<p>Masukkan kod ini dalam TINDAK untuk meneruskan.</p>
<p>Jika anda tidak meminta kod ini, abaikan e-mel ini.</p>
```

No `{{ .ConfirmationURL }}` and no marketing. The code is the only way in.

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

### ENV-2 — file writes from scripts silently do not persist

During M2, writing files through a Python script launched from Bash reported
success while the file on disk was unchanged — the same process re-reading the
file afterwards still saw the old content. Editor-based writes to the same paths
worked normally.

Not diagnosed, not a build or product problem, and not worth chasing yet. Most
likely something on this machine watching `C:\Project`.

**Do not change antivirus or security configuration to work around this**
without first establishing the cause. Use editor writes for source files; if a
scripted edit is ever needed, read the file back and confirm the change landed.

## Status

M1 — foundation. No Share Intent, no detectors, no actions, no Memory, no
Supabase, no auth, no sync, no reminders, no Protect, no AI. Each arrives at its
own milestone behind its own CEO gate.
