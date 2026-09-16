/// The online reputation check, as the rest of Protect sees it (M8b).
///
/// Pure Dart: no Supabase, no HTTP. The only implementation that reaches the
/// network is `EdgeReputationProvider`, and the app never talks to Google
/// directly — the key lives in an Edge Function and nowhere else
/// (`12_SECURITY.md` §6, AI Rule 9).
abstract interface class ReputationProvider {
  /// Checks one URL the user explicitly chose. Never called on its own.
  Future<ReputationResult> check(String url);
}

/// What the online layer came back with.
///
/// Deliberately not "safe" and "unsafe". A provider that knows of no threat has
/// said exactly that, and nothing more.
enum ReputationOutcome {
  /// The provider returned no match for the threat lists it covers.
  noKnownThreat,

  /// The provider reports this URL as a threat.
  threat,

  /// The device has no connection. Nothing was sent.
  offline,

  /// The provider or the function could not answer: error, timeout, or a
  /// response TINDAK could not read.
  unavailable,

  /// This account has used its checks for today. Nothing was sent.
  quotaReached,

  /// The session is not valid for this call. Nothing was sent.
  notAuthenticated,
}

final class ReputationResult {
  const ReputationResult(this.outcome, {this.threatKind});

  /// What the provider said, in TINDAK's words.
  final ReputationOutcome outcome;

  /// A threat category TINDAK recognises, when the provider named one — used
  /// to choose a more specific sentence. Never raw provider jargon.
  final ThreatKind? threatKind;

  bool get reachedProvider =>
      outcome == ReputationOutcome.noKnownThreat ||
      outcome == ReputationOutcome.threat;

  @override
  String toString() =>
      'ReputationResult(${outcome.name}'
      '${threatKind == null ? '' : ', ${threatKind!.name}'})';
}

/// Threat categories TINDAK has copy for. Anything else the provider reports
/// is still a threat — it simply gets the general sentence.
enum ThreatKind { malware, socialEngineering, unwantedSoftware }
