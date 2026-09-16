import 'package:tindak/features/ai/model/ai_candidate.dart';

/// What the provider said. The transport's vocabulary, before validation.
sealed class AiOutcome {
  const AiOutcome();
}

/// The model returned claims. None of them is trusted yet.
final class AiCandidatesOutcome extends AiOutcome {
  AiCandidatesOutcome(List<AiCandidate> candidates)
    : candidates = List<AiCandidate>.unmodifiable(candidates);

  final List<AiCandidate> candidates;

  @override
  String toString() => 'AiCandidatesOutcome(${candidates.length})';
}

/// The model ran and found nothing supported. A valid answer, not a failure
/// (brief §13).
final class AiNothingFoundOutcome extends AiOutcome {
  const AiNothingFoundOutcome();

  @override
  String toString() => 'AiNothingFoundOutcome()';
}

/// The check could not run, or its answer could not be read.
final class AiFailedOutcome extends AiOutcome {
  const AiFailedOutcome(this.failure);

  final AiFailure failure;

  @override
  String toString() => 'AiFailedOutcome(${failure.name})';
}

/// Why an AI request produced nothing usable.
///
/// Every one of these leaves the screen, the text and every local action
/// exactly as they were (brief §19). None of them is evidence about the
/// content — the same rule M8 settled as C-1.
enum AiFailure {
  /// No connection, so nothing was sent.
  offline,

  /// Sent, but no answer inside the client's window.
  timeout,

  /// PD-028: 30 requests per user per day.
  quotaDaily,

  /// PD-028: 5 requests per user per minute.
  quotaBurst,

  /// The session was gone by the time the request was made.
  notAuthenticated,

  /// An answer arrived that TINDAK could not read. Never treated as "nothing
  /// found".
  unreadable,

  /// The provider, or TINDAK's function in front of it, could not serve the
  /// request.
  unavailable,
}

/// Why the online half cannot run at all. Availability, never a verdict.
enum AiBlocker {
  /// No provider in this build. Under PD-048 this is the normal state until a
  /// provider whose terms allow it is chosen and paid for.
  notConfigured,

  /// Over the 2,000-code-point cap. Refused before anything is sent, and never
  /// silently truncated (brief §6).
  tooLong,

  /// ADR-025, PD-023: cloud AI needs an account.
  signInRequired,

  /// PD-011, PD-024: signing in is not consent.
  consentRequired,
}
