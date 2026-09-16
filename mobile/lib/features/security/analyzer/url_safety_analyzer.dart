import 'package:tindak/features/security/model/security_assessment.dart';

/// Deterministic, on-device URL checks (M8a).
///
/// Pure Dart with no network: this runs in airplane mode, and it is the only
/// part of Protect that runs at all until M8b. Every check answers a factual
/// question about the link's structure — never "does this look like a scam".
///
/// **The level is the highest severity found, never a sum** (ADR-009). Three
/// cautions stay CAUTION: counting weak signals into a strong verdict is how a
/// shortened link on an unusual port would end up accused of being dangerous.
///
/// **This analyser can never return [RiskLevel.high].** Nothing on the device
/// is strong enough evidence; that requires the authoritative provider match in
/// M8b.
final class UrlSafetyAnalyzer {
  const UrlSafetyAnalyzer();

  /// Hosts that hide their destination. A short, static list: a longer one
  /// would be a maintenance burden pretending to be completeness.
  static const Set<String> shorteners = <String>{
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'is.gd',
    'buff.ly',
    'cutt.ly',
    'rb.gy',
    's.id',
    'rebrand.ly',
    'shorturl.at',
  };

  /// Six or more labels. `a.b.c.co.uk` is five and perfectly ordinary, so the
  /// threshold sits above it deliberately.
  static const int maxHostLabels = 5;

  static final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  static final RegExp _percentEscape = RegExp('%[0-9a-fA-F]{2}');
  static final RegExp _latin = RegExp(r'[a-zA-Z]');
  static final RegExp _nonLatinLetter = RegExp(
    r'[^\x00-\x7F]',
  );

  /// Examines [normalisedUrl] — the value the URL detector produced and the
  /// one M4 would open. [rawValue], when given, is the text as it appeared, so
  /// a mismatch between the two can be reported.
  SecurityAssessment analyse(String normalisedUrl, {String? rawValue}) {
    final findings = <SecurityFinding>[];
    final uri = Uri.tryParse(normalisedUrl);

    if (uri == null || uri.host.isEmpty) {
      // Unparseable here means unopenable at M4 as well. Reported as a
      // mismatch rather than silently passing.
      return SecurityAssessment(
        url: normalisedUrl,
        level: RiskLevel.suspicious,
        findings: const <SecurityFinding>[
          SecurityFinding(
            SecurityFindingCode.normalisationMismatch,
            SecuritySeverity.suspicious,
          ),
        ],
        onlineStatus: OnlineCheckStatus.notChecked,
      );
    }

    void add(SecurityFindingCode code, SecuritySeverity severity) =>
        findings.add(SecurityFinding(code, severity));

    // --- suspicious: deliberate disguise of where the link goes ---
    if (uri.userInfo.isNotEmpty) {
      add(SecurityFindingCode.credentialsInUrl, SecuritySeverity.suspicious);
    }
    if (_hasEncodedAuthorityCharacter(normalisedUrl)) {
      add(
        SecurityFindingCode.encodedAuthorityCharacter,
        SecuritySeverity.suspicious,
      );
    }
    if (_hasMixedScriptLabel(_decodedHost(uri))) {
      add(SecurityFindingCode.mixedScriptHost, SecuritySeverity.suspicious);
    }
    if (rawValue != null && _differsBeyondTrimming(rawValue, normalisedUrl)) {
      add(
        SecurityFindingCode.normalisationMismatch,
        SecuritySeverity.suspicious,
      );
    }

    // --- caution: worth noticing, not evidence of anything ---
    if (uri.scheme.toLowerCase() == 'http') {
      add(SecurityFindingCode.notEncrypted, SecuritySeverity.caution);
    }
    if (_isIpHost(uri.host)) {
      add(SecurityFindingCode.ipAddressHost, SecuritySeverity.caution);
    }
    if (uri.host.toLowerCase().contains('xn--')) {
      add(SecurityFindingCode.punycodeHost, SecuritySeverity.caution);
    }
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      add(SecurityFindingCode.unusualPort, SecuritySeverity.caution);
    }
    if (!_isIpHost(uri.host) &&
        uri.host.split('.').length > maxHostLabels) {
      add(SecurityFindingCode.deepSubdomains, SecuritySeverity.caution);
    }
    if (shorteners.contains(_withoutWww(uri.host.toLowerCase()))) {
      add(SecurityFindingCode.urlShortener, SecuritySeverity.caution);
    }

    return SecurityAssessment(
      url: normalisedUrl,
      level: _levelOf(findings),
      findings: List<SecurityFinding>.unmodifiable(findings),
      onlineStatus: OnlineCheckStatus.notChecked,
    );
  }

  /// The highest severity present. Nothing is added up, and nothing here can
  /// reach [RiskLevel.high].
  static RiskLevel _levelOf(List<SecurityFinding> findings) {
    if (findings.any((f) => f.severity == SecuritySeverity.suspicious)) {
      return RiskLevel.suspicious;
    }
    if (findings.isNotEmpty) return RiskLevel.caution;
    return RiskLevel.low;
  }

  /// A percent-escape before the path that decodes to `@`, `/` or `.` — the
  /// same trick as credentials in the URL, written so a person cannot see it.
  static bool _hasEncodedAuthorityCharacter(String url) {
    final afterScheme = url.contains('://')
        ? url.substring(url.indexOf('://') + 3)
        : url;
    final authority = afterScheme.split(RegExp(r'[/?#]')).first;

    for (final match in _percentEscape.allMatches(authority)) {
      final decoded = String.fromCharCode(
        int.parse(match.group(0)!.substring(1), radix: 16),
      );
      if (decoded == '@' || decoded == '/' || decoded == '.') return true;
    }
    return false;
  }

  /// Dart percent-encodes a non-ASCII host, so the letters have to be read
  /// back before they can be compared. A host that cannot be decoded is
  /// examined as written rather than skipped.
  static String _decodedHost(Uri uri) {
    try {
      return Uri.decodeComponent(uri.host);
    } on FormatException {
      return uri.host;
    }
  }

  /// One label mixing Latin letters with non-Latin ones: the homograph shape,
  /// where a Cyrillic character stands in for a Latin lookalike. A wholly
  /// non-Latin domain is perfectly ordinary and is not flagged here.
  static bool _hasMixedScriptLabel(String host) {
    for (final label in host.split('.')) {
      if (label.isEmpty) continue;
      if (_latin.hasMatch(label) && _nonLatinLetter.hasMatch(label)) {
        return true;
      }
    }
    return false;
  }

  static bool _isIpHost(String host) {
    if (_ipv4.hasMatch(host)) {
      return host.split('.').every((part) => int.parse(part) <= 255);
    }
    // Uri keeps IPv6 hosts in brackets.
    return host.startsWith('[') && host.endsWith(']');
  }

  static String _withoutWww(String host) =>
      host.startsWith('www.') ? host.substring(4) : host;

  /// Ignores case and a trailing slash, which the detector may add or drop.
  static bool _differsBeyondTrimming(String raw, String normalised) {
    String tidy(String value) {
      var v = value.trim().toLowerCase();
      if (!v.contains('://')) v = 'https://$v';
      while (v.endsWith('/')) {
        v = v.substring(0, v.length - 1);
      }
      return v;
    }

    return tidy(raw) != tidy(normalised);
  }
}
