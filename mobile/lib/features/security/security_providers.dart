import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/security/analyzer/url_safety_analyzer.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// The on-device checks. Pure Dart, so this provider holds no state and
/// touches nothing outside the URL it is given.
final Provider<UrlSafetyAnalyzer> urlSafetyAnalyzerProvider =
    Provider<UrlSafetyAnalyzer>((ref) => const UrlSafetyAnalyzer());

/// Runs a check because the user pressed Semak Keselamatan (PD-012).
///
/// **M8a is local only. Nothing here reaches the network**, and a test in
/// layer_purity_test.dart keeps it that way. The online layer arrives with
/// M8b, behind the same result type.
final Provider<SecurityChecker> securityCheckerProvider =
    Provider<SecurityChecker>(
      (ref) => SecurityChecker(
        analyzer: ref.watch(urlSafetyAnalyzerProvider),
        isSignedIn: () => ref.read(currentAccountProvider) != null,
      ),
    );

final class SecurityChecker {
  const SecurityChecker({
    required UrlSafetyAnalyzer analyzer,
    required bool Function() isSignedIn,
  }) : _analyzer = analyzer,
       _isSignedIn = isSignedIn;

  final UrlSafetyAnalyzer _analyzer;
  final bool Function() _isSignedIn;

  /// Checks one URL entity the user chose. Never called on its own.
  SecurityAssessment check(DetectedEntity url) {
    final local = _analyzer.analyse(
      url.normalizedValue,
      rawValue: url.rawValue,
    );

    // Whether the online half can run is a matter of availability, and it
    // leaves the risk level exactly as the local checks found it (C-1).
    return SecurityAssessment(
      url: local.url,
      level: local.level,
      findings: local.findings,
      onlineStatus: _isSignedIn()
          ? OnlineCheckStatus.notChecked
          : OnlineCheckStatus.signInRequired,
    );
  }
}
