# 21 — RELEASE PLAN

**Owner:** Technical Lead (Claude)
**Approval:** CEO approves every production release
**Status:** LOCKED — CEO Architecture Lock, 2026-09-10

---

## 1. Branches

```text
main        releasable at all times
 └── develop
      ├── feat/share-intent
      ├── feat/understanding
      ├── feat/memory
      ├── feat/reminders
      └── feat/security
```

One branch per milestone, merged into `develop` after its gate passes.
`develop` merges to `main` only at a release. Nothing lands on `main` directly.

Commit convention: `feat:`, `fix:`, `test:`, `security:`, `refactor:`, `chore:`,
`docs:`. Small reversible commits (master plan §24).

---

## 2. Versioning

```text
pubspec.yaml:  version: <major>.<minor>.<patch>+<build>
```

`<build>` increments on every upload and never repeats — Play rejects a
duplicate. V1 ships as `1.0.0`. Alpha builds are `0.x.y`.

Every release is tagged `v<version>` on `main`.

---

## 3. Signing

- One upload keystore, generated once, held by the CEO.
- `key.properties` and the keystore file are git-ignored and stored outside the
  repository. Losing them means a new app listing, so they need a backup that is
  not on the build machine.
- Play App Signing holds the distribution key.
- Debug builds use the default debug key and are never uploaded.

The CEO owns these credentials (master plan §1). They are never pasted into a
chat, an issue, or a commit.

---

## 4. Build

```text
flutter analyze          zero warnings
flutter test             all pass
flutter build appbundle --release
```

Release builds inject `SUPABASE_URL` and `SUPABASE_ANON_KEY` via
`--dart-define`, not from a committed file. Both are public values
(`12_SECURITY.md` §6); the point is that a build for a different environment
needs no source change.

Verified before every upload: `allowBackup=false`, `usesCleartextTraffic=false`,
no debug flags, and that the APK contains no provider API key.

---

## 5. Tracks

```text
Internal testing   ─►  Closed testing   ─►  Production
CEO only               5–10, then 20–50      100+
M10                    M11                   M12
```

Progression between tracks needs the validation outcome from master plan §29,
not a calendar date.

---

## 6. Release checklist

Every item, every production release:

- [ ] `flutter analyze` clean.
- [ ] `flutter test` green.
- [ ] RLS bypass matrix recorded as failing to gain access (`20_TEST_PLAN.md` §9).
- [ ] Privacy checks in `12_SECURITY.md` §12 pass.
- [ ] Device testing on a physical Android device passes.
- [ ] No secret in the repository or in the artifact.
- [ ] Play Data Safety declaration matches what the app actually sends.
- [ ] Version and build number incremented, tag pushed.
- [ ] Release notes written.
- [ ] **CEO approval recorded.**

---

## 7. Rollback

Play cannot un-publish a version that a user has already installed. So:

- Halt the staged rollout first — this is the only fast lever.
- Fix forward with a patch release; a "rollback" is a higher version number
  containing the old behaviour.
- A server-side problem is different and faster: Edge Function config and
  quotas change without an app release, which is why the model id, the provider
  choice and the limits live there (`13_API.md` §3.1, §4).
- A migration that has run in production is not reverted. It is followed by a
  new forward migration.

Staged rollout for production: 20% first, widened once crash-free sessions hold.

---

## 8. Definition of Done for V1

Master plan §41 in full, plus the items the guest-first decision added:

- Guest can share, understand, act and save with no account and no network.
- Sign-in does not silently upload guest memories (PD-016).
- Sign-out leaves no account-owned data readable on the device (PD-017).
- Deletion propagates between devices and never resurrects (PD-021).
- No telemetry contains shared content, and guests send none (PD-022).
- A Malaysian IC number is never a Call or WhatsApp candidate, and `*` or `#`
  never reaches a `tel:` URI — required tests, release-blocking (PD-029).
- A denied notification permission still saves the reminder, and TINDAK never
  claims an alert will fire when it will not (PD-026).
- Guests see cloud controls with a sign-in prompt, and sign-in is never
  treated as AI consent (PD-023, PD-024).

Not done because an AAB builds.

---

## 9. Open items

- Release cadence during closed beta.
- Whether Play Console access is CEO-only or shared.
- ENV-2: file writes from scripts silently not persisting on this machine. Not
  diagnosed; do not change security configuration to work around it without
  evidence of the cause. See `mobile/README.md`.
- ENV-1: Android SDK XML version mismatch in the local toolchain. Not a
  blocker; align Android Studio and the command-line tools before CI, and do
  not quiet it by lowering compileSdk, targetSdk or AGP. See
  `mobile/README.md`.
