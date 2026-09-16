import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/ai/model/ai_result.dart';
import 'package:tindak/features/ai/service/ai_understanding_service.dart';
import 'package:tindak/features/ai/validation/candidate_validator.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/fake_ai_provider.dart';

/// The gates, the cap, and what happens to an answer once it arrives.
void main() {
  final today = DateTime(2026, 9, 16);
  final engine = UnderstandingEngine.withClock(FixedClock(today));
  final validator = CandidateValidator(
    engine: engine,
    clock: FixedClock(today),
  );

  AiUnderstandingService serviceWith(
    FakeAiProvider? provider, {
    bool signedIn = true,
    bool consented = true,
  }) => AiUnderstandingService(
    validator: validator,
    isSignedIn: () => signedIn,
    hasAcceptedDisclosure: () async => consented,
    provider: provider,
  );

  const text = 'Jumpa kontraktor Jumaat depan, bayar RM180';

  group('nothing is sent unless every gate is open', () {
    test('a build with no provider sends nothing', () async {
      final service = serviceWith(null);

      expect(await service.blocker(text), AiBlocker.notConfigured);
      expect(await service.understand(text), isA<AiBlocked>());
    });

    test('a guest sends nothing', () async {
      final provider = FakeAiProvider();
      final service = serviceWith(provider, signedIn: false);

      expect(await service.blocker(text), AiBlocker.signInRequired);
      expect(await service.understand(text), isA<AiBlocked>());
      expect(provider.calls, isEmpty);
    });

    test('without consent, nothing is sent', () async {
      final provider = FakeAiProvider();
      final service = serviceWith(provider, consented: false);

      expect(await service.blocker(text), AiBlocker.consentRequired);
      expect(await service.understand(text), isA<AiBlocked>());
      expect(provider.calls, isEmpty);
    });

    test('a build with no provider never asks a guest to sign in', () async {
      // A sign-in prompt is a promise. TINDAK does not make one it cannot
      // keep, so "not configured" is reported first.
      final service = serviceWith(null, signedIn: false, consented: false);
      expect(await service.blocker(text), AiBlocker.notConfigured);
    });

    test('with every gate open, exactly the text is sent — once', () async {
      final provider = FakeAiProvider();
      await serviceWith(provider).understand(text);

      expect(provider.calls, <String>[text]);
    });
  });

  group('the 2,000 cap', () {
    test('code points, not UTF-16 units', () {
      // Each of these is one code point and two UTF-16 units. Counting units
      // would refuse this at half the stated limit.
      final emoji = '👍' * 1500;
      expect(emoji.length, 3000);
      expect(AiUnderstandingService.codePointsOf(emoji), 1500);
    });

    test('exactly 2,000 passes and 2,001 does not', () async {
      final provider = FakeAiProvider();
      final service = serviceWith(provider);

      expect(await service.blocker('a' * 2000), isNull);
      expect(await service.blocker('a' * 2001), AiBlocker.tooLong);
    });

    test('over the cap, nothing is sent and nothing is truncated', () async {
      final provider = FakeAiProvider();
      final service = serviceWith(provider);

      final result = await service.understand('a' * 2001);

      expect(result, isA<AiBlocked>());
      expect((result as AiBlocked).blocker, AiBlocker.tooLong);
      expect(provider.calls, isEmpty);
    });

    test('the cap is checked before sign-in', () async {
      // Refusing for length is a fact about the text. Asking someone to sign
      // in first, then refusing anyway, would waste their time.
      final service = serviceWith(
        FakeAiProvider(),
        signedIn: false,
      );
      expect(await service.blocker('a' * 2001), AiBlocker.tooLong);
    });
  });

  group('what comes back is checked, not shown', () {
    Future<AiResult> run(AiOutcome outcome, [String input = text]) async {
      final provider = FakeAiProvider(outcome);
      return serviceWith(provider).understand(input);
    }

    test('valid claims become entities', () async {
      final result = await run(
        FakeAiProvider.candidates(<AiCandidate>[
          FakeAiProvider.candidate(
            EntityType.date,
            'Jumaat depan',
            '2026-09-18',
          ),
          FakeAiProvider.candidate(EntityType.money, 'RM180', 'MYR18000'),
        ]),
      );

      expect(result, isA<AiEntitiesFound>());
      final found = result as AiEntitiesFound;
      expect(found.entities.map((e) => e.type), <EntityType>[
        EntityType.date,
        EntityType.money,
      ]);
      expect(found.rejected, isEmpty);
    });

    test('nothing found is said plainly, not dressed up', () async {
      expect(await run(FakeAiProvider.nothing), isA<AiNothingUsable>());
    });

    test('a hallucinated span leaves nothing usable', () async {
      final result = await run(FakeAiProvider.hallucinatedSpan);

      expect(result, isA<AiNothingUsable>());
      expect(
        (result as AiNothingUsable).rejected,
        <CandidateRejection>[CandidateRejection.spanNotFound],
      );
    });

    test('a real span with a wrong value leaves nothing usable', () async {
      final result = await run(FakeAiProvider.valueMismatch);

      expect(result, isA<AiNothingUsable>());
      expect(
        (result as AiNothingUsable).rejected,
        <CandidateRejection>[CandidateRejection.valueMismatch],
      );
    });

    test('a dangerous link never becomes an entity', () async {
      final result = await run(
        FakeAiProvider.dangerousUrl,
        'klik javascript:alert(1)',
      );

      expect(result, isA<AiNothingUsable>());
    });

    test('the same claim twice is kept once', () async {
      final result = await run(FakeAiProvider.duplicates, 'bayar RM180');

      expect(result, isA<AiEntitiesFound>());
      expect((result as AiEntitiesFound).entities, hasLength(1));
      expect(result.rejected, <CandidateRejection>[
        CandidateRejection.duplicate,
      ]);
    });

    test('one bad claim does not discard the good ones', () async {
      final result = await run(
        FakeAiProvider.candidates(<AiCandidate>[
          FakeAiProvider.candidate(EntityType.money, 'RM180', 'MYR80000'),
          FakeAiProvider.candidate(EntityType.money, 'RM180', 'MYR18000'),
        ]),
        'bayar RM180',
      );

      expect(result, isA<AiEntitiesFound>());
      expect((result as AiEntitiesFound).entities, hasLength(1));
      expect(result.rejected, <CandidateRejection>[
        CandidateRejection.valueMismatch,
      ]);
    });

    test('an unreadable answer is never "nothing found"', () async {
      final result = await run(FakeAiProvider.unreadable);

      expect(result, isA<AiUnavailableResult>());
      expect(
        (result as AiUnavailableResult).failure,
        AiFailure.unreadable,
      );
    });

    for (final failure in AiFailure.values) {
      test('${failure.name} is reported as itself', () async {
        final result = await run(AiFailedOutcome(failure));

        expect(result, isA<AiUnavailableResult>());
        expect((result as AiUnavailableResult).failure, failure);
      });
    }

    test('a result prints no value', () async {
      final result = await run(
        FakeAiProvider.candidates(<AiCandidate>[
          FakeAiProvider.candidate(
            EntityType.url,
            'https://tnb.com.my',
            'https://tnb.com.my',
          ),
        ]),
        'bayar di https://tnb.com.my',
      );

      expect(result.toString(), isNot(contains('tnb')));
    });
  });

  group('merging with what was already understood', () {
    test('AI entities join the local ones, in position order', () {
      const input = 'bayar RM180 pada Jumaat depan';
      final local = engine.understand(input);
      final ai = FakeAiProvider.candidate(
        EntityType.date,
        'Jumaat depan',
        '2026-09-18',
      );
      final verdict = validator.validate(ai, input);

      final merged = AiUnderstandingService.merge(local, <DetectedEntity>[
        (verdict as CandidateAccepted).entity,
      ]);

      expect(merged.entities.length, local.entities.length + 1);
      expect(
        merged.entities.map((e) => e.start).toList(),
        List<int>.from(merged.entities.map((e) => e.start))..sort(),
      );
      expect(merged.content, same(local.content));
    });
  });
}
