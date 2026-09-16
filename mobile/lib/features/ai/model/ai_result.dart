import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/ai/validation/candidate_validator.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// What TINDAK will show, after the model's claims have been through
/// `CandidateValidator`.
sealed class AiResult {
  const AiResult();
}

/// A gate was closed, so nothing was sent.
final class AiBlocked extends AiResult {
  const AiBlocked(this.blocker);
  final AiBlocker blocker;

  @override
  String toString() => 'AiBlocked(${blocker.name})';
}

/// At least one claim survived grounding and validation.
final class AiEntitiesFound extends AiResult {
  AiEntitiesFound({
    required List<DetectedEntity> entities,
    required List<CandidateRejection> rejected,
  }) : entities = List<DetectedEntity>.unmodifiable(entities),
       rejected = List<CandidateRejection>.unmodifiable(rejected),
       assert(entities.isNotEmpty);

  final List<DetectedEntity> entities;

  /// Reason codes for what was dropped. Counted, never shown, never logged
  /// with a value.
  final List<CandidateRejection> rejected;

  @override
  String toString() =>
      'AiEntitiesFound(${entities.length}, dropped: ${rejected.length})';
}

/// The request worked and produced nothing TINDAK can act on — either the
/// model found nothing, or everything it claimed was rejected.
///
/// A normal answer, said plainly. TINDAK does not invent an entity to avoid an
/// empty screen (brief §13).
final class AiNothingUsable extends AiResult {
  AiNothingUsable({List<CandidateRejection> rejected = const <CandidateRejection>[]})
    : rejected = List<CandidateRejection>.unmodifiable(rejected);

  final List<CandidateRejection> rejected;

  @override
  String toString() => 'AiNothingUsable(dropped: ${rejected.length})';
}

/// The check could not run. Availability, not evidence: nothing on screen
/// changes because of it.
final class AiUnavailableResult extends AiResult {
  const AiUnavailableResult(this.failure);
  final AiFailure failure;

  @override
  String toString() => 'AiUnavailableResult(${failure.name})';
}
