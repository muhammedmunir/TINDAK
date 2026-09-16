import 'package:tindak/features/ai/data/ai_understanding_provider.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// A provider that answers however a test needs it to, and counts what it was
/// asked.
///
/// It lives here, under `test/`, and **not** in `lib/`. That is deliberate:
/// there is no fake AI in the shipped app, not behind a flag and not behind a
/// debug switch, so a release build physically cannot pretend AI is available
/// (M9a gate). Nothing in `lib/` implements `AiUnderstandingProvider` at all.
///
/// It is built to be unhelpful on purpose. A fake that only ever returns a
/// tidy, correct answer would prove that TINDAK works when the model behaves,
/// which is the case nobody needs reassurance about.
final class FakeAiProvider implements AiUnderstandingProvider {
  FakeAiProvider([this.outcome = const AiNothingFoundOutcome()]);

  AiOutcome outcome;

  /// Every text this provider was handed, in order. A test that expects
  /// nothing to be sent asserts this is empty.
  final List<String> calls = <String>[];

  @override
  Future<AiOutcome> understand(String text) async {
    calls.add(text);
    return outcome;
  }

  // --- the scenarios the M9a gate requires ---------------------------------

  static AiOutcome candidates(List<AiCandidate> items) =>
      AiCandidatesOutcome(items);

  static AiCandidate candidate(EntityType type, String span, String value) =>
      AiCandidate(type: type, span: span, value: value);

  /// Well-formed claims that should survive every check.
  static AiOutcome get valid => AiCandidatesOutcome(<AiCandidate>[
    candidate(EntityType.date, 'Jumaat depan', '2026-09-18'),
    candidate(EntityType.money, 'seribu lima ratus ringgit', 'MYR150000'),
  ]);

  /// The model ran and found nothing supported.
  static const AiOutcome nothing = AiNothingFoundOutcome();

  /// A type TINDAK has no action for. Dropped at parse; here it is already a
  /// dropped entry, so the envelope arrives with nothing usable in it.
  static AiOutcome get unsupportedType => AiCandidatesOutcome(
    const <AiCandidate>[],
  );

  /// A span that is nowhere in the user's text.
  static AiOutcome get hallucinatedSpan => AiCandidatesOutcome(<AiCandidate>[
    candidate(EntityType.phone, '+60 19-999 8888', '+60199998888'),
  ]);

  /// A real span used as cover for a different value.
  static AiOutcome get valueMismatch => AiCandidatesOutcome(<AiCandidate>[
    candidate(EntityType.money, 'RM180', 'MYR80000'),
  ]);

  /// The same claim twice.
  static AiOutcome get duplicates => AiCandidatesOutcome(<AiCandidate>[
    candidate(EntityType.money, 'RM180', 'MYR18000'),
    candidate(EntityType.money, 'RM180', 'MYR18000'),
  ]);

  /// A scheme no action may ever launch.
  static AiOutcome get dangerousUrl => AiCandidatesOutcome(<AiCandidate>[
    candidate(
      EntityType.url,
      'javascript:alert(1)',
      'javascript:alert(1)',
    ),
  ]);

  /// An answer TINDAK could not read. Never "nothing found".
  static const AiOutcome unreadable = AiFailedOutcome(AiFailure.unreadable);

  static const AiOutcome timeout = AiFailedOutcome(AiFailure.timeout);
  static const AiOutcome unavailable = AiFailedOutcome(AiFailure.unavailable);
  static const AiOutcome offline = AiFailedOutcome(AiFailure.offline);
  static const AiOutcome quotaDaily = AiFailedOutcome(AiFailure.quotaDaily);
  static const AiOutcome quotaBurst = AiFailedOutcome(AiFailure.quotaBurst);
}
