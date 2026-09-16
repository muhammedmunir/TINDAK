import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/ai/data/ai_disclosure.dart';
import 'package:tindak/features/ai/data/ai_understanding_provider.dart';
import 'package:tindak/features/ai/service/ai_understanding_service.dart';
import 'package:tindak/features/ai/validation/candidate_validator.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/intake/intake_understanding.dart';
import 'package:tindak/features/memory/memory_providers.dart';

/// The AI provider.
///
/// **Null in every shipped M9a build, and there is no implementation in `lib/`
/// to override it with.** PD-048 forbids sending a user's message to a service
/// that may use it for product improvement or human review, and no provider
/// meeting that bar has been chosen or paid for yet. Until one is, the gate
/// answers `notConfigured` and the app says *AI tidak tersedia buat masa ini*.
///
/// Tests override this with a fake. The fake lives under `test/`, so it cannot
/// be reached from a release build even by accident — there is nothing to
/// import.
final Provider<AiUnderstandingProvider?> aiUnderstandingProviderProvider =
    Provider<AiUnderstandingProvider?>((ref) => null);

final Provider<AiDisclosure> aiDisclosureProvider = Provider<AiDisclosure>(
  (ref) => AiDisclosure(ref.watch(databaseProvider)),
);

/// Checks a model's claims against the user's own text and TINDAK's own rules.
///
/// It is given the same engine the local pipeline uses, so "what TINDAK would
/// make of this span" is answered by the real detectors rather than a second
/// copy of their logic.
final Provider<CandidateValidator> candidateValidatorProvider =
    Provider<CandidateValidator>(
      (ref) => CandidateValidator(
        engine: ref.watch(understandingEngineProvider),
        clock: ref.watch(clockProvider),
      ),
    );

final Provider<AiUnderstandingService> aiUnderstandingServiceProvider =
    Provider<AiUnderstandingService>(
      (ref) => AiUnderstandingService(
        validator: ref.watch(candidateValidatorProvider),
        isSignedIn: () => ref.read(currentAccountProvider) != null,
        hasAcceptedDisclosure: ref.watch(aiDisclosureProvider).accepted,
        provider: ref.watch(aiUnderstandingProviderProvider),
      ),
    );
