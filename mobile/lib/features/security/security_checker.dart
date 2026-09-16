import 'package:tindak/features/security/analyzer/url_safety_analyzer.dart';
import 'package:tindak/features/security/data/reputation_provider.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// Runs a check because the user pressed Semak Keselamatan, and combines what
/// the two layers found (PD-012).
///
/// Pure Dart. It is handed the answers to "is there an account", "has the user
/// agreed to send links" and "what did the provider say"; it decides nothing
/// about the network itself, which is what keeps the combination rules
/// testable without one.
final class SecurityChecker {
  const SecurityChecker({
    required UrlSafetyAnalyzer analyzer,
    required bool Function() isSignedIn,
    required Future<bool> Function() hasAcceptedDisclosure,
    ReputationProvider? provider,
  }) : _analyzer = analyzer,
       _isSignedIn = isSignedIn,
       _hasAcceptedDisclosure = hasAcceptedDisclosure,
       _provider = provider;

  final UrlSafetyAnalyzer _analyzer;
  final bool Function() _isSignedIn;
  final Future<bool> Function() _hasAcceptedDisclosure;
  final ReputationProvider? _provider;

  /// The local half, which always runs and never sends anything.
  SecurityAssessment local(DetectedEntity url) =>
      _analyzer.analyse(url.normalizedValue, rawValue: url.rawValue);

  /// Why the online half cannot run yet, or null when it can.
  ///
  /// Checked **before** anything is sent: no account, no agreement, or no
  /// provider in this build all stop the request from being made at all.
  Future<OnlineCheckStatus?> onlineBlocker() async {
    if (_provider == null) return OnlineCheckStatus.notChecked;
    if (!_isSignedIn()) return OnlineCheckStatus.signInRequired;
    if (!await _hasAcceptedDisclosure()) {
      return OnlineCheckStatus.disclosureRequired;
    }
    return null;
  }

  /// The full check. Runs the local half, and the online half only when
  /// [onlineBlocker] says it may.
  Future<SecurityAssessment> check(DetectedEntity url) async {
    final assessment = local(url);

    final blocker = await onlineBlocker();
    if (blocker != null) return _withOnline(assessment, blocker);

    final result = await _provider!.check(assessment.url);
    return combine(assessment, result);
  }

  /// Local findings and provider evidence, resolved by the same rule as
  /// everything else: **the highest severity that is actually justified**.
  ///
  /// - A provider threat match is authoritative and reaches HIGH RISK.
  /// - A provider that knows of no threat **never lowers** the local level,
  ///   and is never reported as "this link is safe".
  /// - A check that could not run changes nothing at all: it is availability,
  ///   not evidence (C-1).
  static SecurityAssessment combine(
    SecurityAssessment local,
    ReputationResult result,
  ) => switch (result.outcome) {
    ReputationOutcome.threat => SecurityAssessment(
      url: local.url,
      level: RiskLevel.high,
      findings: local.findings,
      onlineStatus: OnlineCheckStatus.threatFound,
      onlineFinding: switch (result.threatKind) {
        ThreatKind.malware => OnlineFindingCode.providerThreatMalware,
        ThreatKind.socialEngineering =>
          OnlineFindingCode.providerThreatSocialEngineering,
        ThreatKind.unwantedSoftware =>
          OnlineFindingCode.providerThreatUnwantedSoftware,
        null => OnlineFindingCode.providerThreat,
      },
    ),
    ReputationOutcome.noKnownThreat => _withOnline(
      local,
      OnlineCheckStatus.clean,
    ),
    ReputationOutcome.offline => _withOnline(local, OnlineCheckStatus.offline),
    ReputationOutcome.quotaReached => _withOnline(
      local,
      OnlineCheckStatus.quotaReached,
    ),
    ReputationOutcome.notAuthenticated => _withOnline(
      local,
      OnlineCheckStatus.signInRequired,
    ),
    ReputationOutcome.unavailable => _withOnline(
      local,
      OnlineCheckStatus.unavailable,
    ),
  };

  /// Keeps the level exactly as the local checks found it, and records only
  /// what happened to the online half.
  static SecurityAssessment _withOnline(
    SecurityAssessment local,
    OnlineCheckStatus status,
  ) => SecurityAssessment(
    url: local.url,
    level: local.level,
    findings: local.findings,
    onlineStatus: status,
  );
}
