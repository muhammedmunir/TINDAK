/// What TINDAK found when a user asked it to check a link.
///
/// Pure Dart: no Flutter, no I/O, no network. Every rule here is a unit test,
/// and nothing in this file can send anything anywhere.
library;

/// How serious one finding is. There is no numeric weight, on purpose: the
/// level is the highest severity present, never a sum (ADR-009).
enum SecuritySeverity { caution, suspicious }

/// What the user is shown, in TINDAK's four words (PRD section 14).
enum RiskLevel {
  low,
  caution,
  suspicious,

  /// Reserved for an authoritative provider match in M8b. **The local
  /// analyser can never produce this**, and a test enforces that: no
  /// combination of on-device heuristics is strong enough to call a link
  /// dangerous.
  high,
}

/// Whether the online reputation check happened — and **nothing more**.
///
/// Locked at the M8 plan gate (C-1): this never changes [SecurityAssessment
/// .level]. A link is not more dangerous because the phone is offline or the
/// user has not signed in; TINDAK simply says that half the check did not run.
enum OnlineCheckStatus {
  /// Not run yet. In M8a this is every signed-in scan, because the online
  /// layer arrives with M8b.
  notChecked,

  /// Needs an account first (ADR-025, PD-023).
  signInRequired,

  /// Ran, and the provider knows of no threat.
  clean,

  /// Ran, and the provider reports a threat.
  threatFound,

  /// Attempted and could not complete: offline, timeout, provider error, or
  /// the daily limit reached.
  unavailable,
}

/// One deterministic signal found in a URL.
///
/// [code] is stable and safe for logs; the wording the user reads is chosen in
/// the app from that code, so no sentence is ever assembled from a link.
final class SecurityFinding {
  const SecurityFinding(this.code, this.severity);

  final SecurityFindingCode code;
  final SecuritySeverity severity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityFinding &&
          code == other.code &&
          severity == other.severity;

  @override
  int get hashCode => Object.hash(code, severity);

  @override
  String toString() => 'SecurityFinding(${code.name}, ${severity.name})';
}

/// Every signal TINDAK can report. Adding one means adding its copy, its
/// severity and its tests together.
enum SecurityFindingCode {
  /// The link carries a username or password before the host, which is how
  /// `https://maybank2u.com.my@evil.example` is made to read like a bank.
  credentialsInUrl,

  /// A percent-escape inside the authority that decodes to `@`, `/` or `.` —
  /// the same disguise, written in a way a person cannot see.
  encodedAuthorityCharacter,

  /// One part of the host mixes writing systems, which is how a Latin `a` is
  /// swapped for a Cyrillic one.
  mixedScriptHost,

  /// The link as written and the link as understood differ. Should be
  /// impossible after PD-032; reported rather than trusted if it happens.
  normalisationMismatch,

  /// Plain `http`, so the connection is not encrypted (C-5). A transport
  /// signal, not evidence of a scam.
  notEncrypted,

  /// The host is a raw IP address instead of a name.
  ipAddressHost,

  /// The host uses Punycode, the encoding behind non-Latin domain names.
  punycodeHost,

  /// An explicit port that is neither 80 nor 443.
  unusualPort,

  /// Unusually many labels in the host.
  deepSubdomains,

  /// A link-shortening service, so the real destination is hidden.
  urlShortener,
}

/// The result of one check, as the screen and the tests see it.
final class SecurityAssessment {
  const SecurityAssessment({
    required this.url,
    required this.level,
    required this.findings,
    required this.onlineStatus,
  });

  /// The normalised URL that was examined — the same value M4 would open.
  final String url;

  final RiskLevel level;

  /// In a fixed order, so the same link always reads the same way.
  final List<SecurityFinding> findings;

  final OnlineCheckStatus onlineStatus;

  /// True when the user should be asked again before opening (PD-014: they may
  /// still open it).
  bool get needsConfirmationToOpen =>
      level == RiskLevel.suspicious || level == RiskLevel.high;

  /// Deliberately excludes the URL: it is user content
  /// (docs/12_SECURITY.md section 11).
  @override
  String toString() =>
      'SecurityAssessment(${level.name}, findings: ${findings.length}, '
      'online: ${onlineStatus.name})';
}
