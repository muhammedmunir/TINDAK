import 'package:tindak/features/ai/data/ai_understanding_provider.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/ai/model/ai_result.dart';
import 'package:tindak/features/ai/validation/candidate_validator.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Runs an AI request because the user pressed **Cuba dengan AI**, and turns
/// what comes back into entities TINDAK is willing to act on.
///
/// Pure Dart. It is handed the answers to "is there a provider", "is there an
/// account" and "has the user agreed", and decides nothing about the network
/// itself — which is what lets every rule below be tested with no server and
/// no model.
///
/// AI never runs on its own. There is no automatic fallback, no retry of a
/// weak local result, and no path into this class that is not a button press
/// (ADR-006).
final class AiUnderstandingService {
  const AiUnderstandingService({
    required CandidateValidator validator,
    required bool Function() isSignedIn,
    required Future<bool> Function() hasAcceptedDisclosure,
    AiUnderstandingProvider? provider,
  }) : _validator = validator,
       _isSignedIn = isSignedIn,
       _hasAcceptedDisclosure = hasAcceptedDisclosure,
       _provider = provider;

  final CandidateValidator _validator;
  final bool Function() _isSignedIn;
  final Future<bool> Function() _hasAcceptedDisclosure;
  final AiUnderstandingProvider? _provider;

  /// PD-028, in **Unicode code points**.
  ///
  /// Not `String.length`, which counts UTF-16 units: one emoji is two of those,
  /// and a message full of them would be refused at half the stated limit.
  static const int maxCodePoints = 2000;

  static int codePointsOf(String text) => text.runes.length;

  /// Why the request cannot be made, or null when every gate is open.
  ///
  /// Asked **before** anything is prepared, let alone sent.
  ///
  /// The order is deliberate. A build with no provider never asks anyone to
  /// sign in, because a sign-in prompt is a promise TINDAK would not be able to
  /// keep. Text that is too long is refused before sign-in for the same reason.
  /// And consent is asked last, immediately before the only moment it matters
  /// — the moment text would actually leave the device.
  Future<AiBlocker?> blocker(String normalizedText) async {
    if (_provider == null) return AiBlocker.notConfigured;
    if (codePointsOf(normalizedText) > maxCodePoints) return AiBlocker.tooLong;
    if (!_isSignedIn()) return AiBlocker.signInRequired;
    if (!await _hasAcceptedDisclosure()) return AiBlocker.consentRequired;
    return null;
  }

  /// The full request. Sends **only** [normalizedText], and only when
  /// [blocker] says it may.
  ///
  /// The text measured here is the text sent, and it is the same text the
  /// disclosure described: one string, normalised once, never re-derived and
  /// never trimmed to fit.
  Future<AiResult> understand(String normalizedText) async {
    final blocked = await blocker(normalizedText);
    if (blocked != null) return AiBlocked(blocked);

    final outcome = await _provider!.understand(normalizedText);

    return switch (outcome) {
      AiFailedOutcome(failure: final failure) => AiUnavailableResult(failure),
      AiNothingFoundOutcome() => AiNothingUsable(),
      AiCandidatesOutcome(candidates: final candidates) => _validated(
        candidates,
        normalizedText,
      ),
    };
  }

  /// Every claim is checked; the ones that fail are dropped with a reason and
  /// the rest stand. An envelope TINDAK could not read never gets this far —
  /// that is `AiFailure.unreadable`, decided at the transport — but a single
  /// bad claim inside a readable answer is not a reason to discard the good
  /// ones.
  ///
  /// When nothing survives, the answer is "nothing supported was found", not
  /// an error, because that is the truth.
  AiResult _validated(List<AiCandidate> candidates, String normalizedText) {
    final entities = <DetectedEntity>[];
    final rejected = <CandidateRejection>[];

    for (final verdict in _validator.validateAll(candidates, normalizedText)) {
      switch (verdict) {
        case CandidateAccepted(entity: final entity):
          entities.add(entity);
        case CandidateRejected(reason: final reason):
          rejected.add(reason);
      }
    }

    if (entities.isEmpty) return AiNothingUsable(rejected: rejected);
    return AiEntitiesFound(entities: entities, rejected: rejected);
  }

  /// Local entities plus the AI entities the user has just been shown, in one
  /// result.
  ///
  /// Used when an AI entity leads to something that persists — a save, or a
  /// reminder — so that what is stored matches what the user acted on. Overlap
  /// is settled by the **existing** engine rules, not a second set: where a
  /// local entity and an AI entity cover the same ground, the deterministic one
  /// wins, because AI candidates carry a lower confidence by construction.
  static UnderstandingResult merge(
    UnderstandingResult local,
    List<DetectedEntity> aiEntities,
  ) => UnderstandingResult(
    content: local.content,
    entities: <DetectedEntity>[...local.entities, ...aiEntities]
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.end.compareTo(b.end);
      }),
    wasTruncated: local.wasTruncated,
  );
}
