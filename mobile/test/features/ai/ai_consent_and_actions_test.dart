import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/resolver/action_uri_builder.dart';
import 'package:tindak/features/ai/data/ai_disclosure.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/ai/validation/candidate_validator.dart';
import 'package:tindak/features/security/data/online_check_disclosure.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/test_database.dart';

void main() {
  final today = DateTime(2026, 9, 16);
  final engine = UnderstandingEngine.withClock(FixedClock(today));
  final validator = CandidateValidator(
    engine: engine,
    clock: FixedClock(today),
  );

  group('AI consent is versioned, and its own', () {
    late TindakDatabase db;

    setUp(() {
      db = openTestDatabase();
      addTearDown(db.close);
    });

    test('nothing is accepted until Teruskan', () async {
      expect(await AiDisclosure(db).accepted(), isFalse);
      expect(await AiDisclosure(db).acceptedVersion(), 0);
    });

    test('accepting records the version this build showed', () async {
      await AiDisclosure(db).accept();

      expect(await AiDisclosure(db).acceptedVersion(),
          AiDisclosure.requiredVersion);
      expect(await AiDisclosure(db).accepted(), isTrue);
    });

    test('an older agreement does not cover a newer promise', () async {
      // What a raised `requiredVersion` looks like from the store's side: the
      // user agreed to version 1, the build now shows version 2, and the sheet
      // must appear again rather than carrying consent across a change the
      // user never saw.
      await db
          .into(db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(key: AiDisclosure.key, value: '0'),
          );

      expect(await AiDisclosure(db).accepted(), isFalse);
    });

    test('an unreadable value is not consent', () async {
      await db
          .into(db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(key: AiDisclosure.key, value: 'yes'),
          );

      expect(await AiDisclosure(db).acceptedVersion(), 0);
      expect(await AiDisclosure(db).accepted(), isFalse);
    });

    test('withdrawing means being asked again', () async {
      await AiDisclosure(db).accept();
      await AiDisclosure(db).withdraw();

      expect(await AiDisclosure(db).accepted(), isFalse);
    });

    test('Protect\'s agreement is not AI\'s, and the reverse (PD-024)',
        () async {
      await OnlineCheckDisclosure(db).accept();
      expect(await AiDisclosure(db).accepted(), isFalse);

      await AiDisclosure(db).accept();
      await OnlineCheckDisclosure(db).accept();
      expect(await OnlineCheckDisclosure(db).accepted(), isTrue);
      expect(await AiDisclosure(db).accepted(), isTrue);

      await AiDisclosure(db).withdraw();
      // Withdrawing AI consent leaves Protect exactly as it was.
      expect(await OnlineCheckDisclosure(db).accepted(), isTrue);
    });
  });

  group('an AI entity takes the same road out as a local one', () {
    const resolver = ActionResolver();
    const builder = ActionUriBuilder();

    DetectedEntity aiEntity(EntityType type, String span, String value,
        String text) {
      final verdict = validator.validate(
        AiCandidate(type: type, span: span, value: value),
        text,
      );
      return (verdict as CandidateAccepted).entity;
    }

    test('a phone gets exactly the local actions, and the same URIs', () {
      const text = 'hubungi 012-3456789';
      final local = engine.understand(text).entities.single;
      final ai = aiEntity(
        EntityType.phone,
        '012-3456789',
        '+60123456789',
        text,
      );

      expect(
        resolver.resolve(ai).map((a) => a.kind),
        resolver.resolve(local).map((a) => a.kind),
      );
      for (final action in resolver.resolve(ai)) {
        expect(
          builder.build(action)?.toString(),
          builder
              .build(
                ActionDescriptor(kind: action.kind, entity: local),
              )
              ?.toString(),
        );
      }
    });

    test('a link gets Buka and Semak Keselamatan, like any other', () {
      const text = 'bayar di https://tnb.com.my';
      final ai = aiEntity(
        EntityType.url,
        'https://tnb.com.my',
        'https://tnb.com.my',
        text,
      );

      expect(
        resolver.resolve(ai).map((a) => a.kind),
        containsAll(<ActionKind>[
          ActionKind.openUrl,
          ActionKind.securityCheck,
        ]),
      );
    });

    test('an AI entity ranks below a local one on a tie', () {
      // Fixed and below every detector's minimum, so a deterministic reading
      // always wins where both cover the same ground.
      expect(CandidateValidator.aiConfidence, lessThan(0.60));
    });

    test('the builder still refuses what it always refused', () {
      // The AI path cannot smuggle a value past the last line, because the
      // last line does not care where an entity came from.
      const hand = DetectedEntity(
        type: EntityType.phone,
        rawValue: '*21*012#',
        normalizedValue: '*21*012#',
        confidence: CandidateValidator.aiConfidence,
        start: 0,
        end: 8,
      );

      expect(
        builder.build(
          const ActionDescriptor(kind: ActionKind.call, entity: hand),
        ),
        isNull,
      );
    });
  });
}
