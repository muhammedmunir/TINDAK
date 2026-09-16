import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/security/data/reputation_provider.dart';

/// Asks TINDAK's own Edge Function to check a URL (M8b).
///
/// One of the few files that may import Supabase
/// (test/features/understanding/layer_purity_test.dart). The Web Risk key is
/// **not here and not in the app at all** — the function holds it, verifies the
/// caller and enforces the quota.
///
/// The request carries the URL and nothing else. The response is TINDAK's own
/// vocabulary, so no provider jargon reaches the screen.
final class EdgeReputationProvider implements ReputationProvider {
  const EdgeReputationProvider(this._client);

  final SupabaseClient _client;

  static const String functionName = 'url-check';

  /// Longer than the function's own 8 seconds, so its answer wins the race
  /// (docs/13_API.md section 4).
  static const Duration timeout = Duration(seconds: 12);

  static const AppLogger _log = AppLogger('security');

  @override
  Future<ReputationResult> check(String url) async {
    if (_client.auth.currentSession == null) {
      // Never send a link without a session to send it under.
      return const ReputationResult(ReputationOutcome.notAuthenticated);
    }

    try {
      final response = await _client.functions
          .invoke(functionName, body: <String, String>{'url': url})
          .timeout(timeout);

      final data = response.data;
      if (data is! Map) return _unreadable();

      return switch (data['outcome']) {
        'no_known_threat' => const ReputationResult(
          ReputationOutcome.noKnownThreat,
        ),
        'threat' => ReputationResult(
          ReputationOutcome.threat,
          threatKind: _threatKind(data['threat_kind']),
        ),
        'quota_reached' => const ReputationResult(
          ReputationOutcome.quotaReached,
        ),
        'unauthenticated' => const ReputationResult(
          ReputationOutcome.notAuthenticated,
        ),
        _ => _unreadable(),
      };
    } on FunctionException catch (e) {
      // The function answered with an error status. Its body can quote the
      // request, so only the status is logged.
      _log.failure('reputation_function_${e.status}');
      return switch (e.status) {
        429 => const ReputationResult(ReputationOutcome.quotaReached),
        401 => const ReputationResult(ReputationOutcome.notAuthenticated),
        _ => const ReputationResult(ReputationOutcome.unavailable),
      };
    } on TimeoutException {
      _log.failure('reputation_timeout');
      return const ReputationResult(ReputationOutcome.unavailable);
    } on Object catch (error) {
      // SocketException, ClientException and friends: no connection, so
      // nothing was sent.
      _log.failure('reputation_failed_${error.runtimeType}');
      return const ReputationResult(ReputationOutcome.offline);
    }
  }

  static ReputationResult _unreadable() {
    _log.failure('reputation_unreadable_response');
    // A response TINDAK cannot read is never treated as "nothing found".
    return const ReputationResult(ReputationOutcome.unavailable);
  }

  static ThreatKind? _threatKind(Object? value) => switch (value) {
    'malware' => ThreatKind.malware,
    'social_engineering' => ThreatKind.socialEngineering,
    'unwanted_software' => ThreatKind.unwantedSoftware,
    _ => null,
  };
}
