import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

void main() {
  const engine = UnderstandingEngine();
  String cp(int codePoint) => String.fromCharCode(codePoint);

  group('multi-entity — docs/20_TEST_PLAN.md section 6', () {
    test('phone and URL in one message are both kept (PD-002)', () {
      final result = engine.understand(
        'Hubungi 012-3456789 atau https://example.com',
      );

      expect(result.entities.map((e) => e.type), <EntityType>[
        EntityType.phone,
        EntityType.url,
      ]);
    });

    test('digits inside a URL belong to the URL', () {
      final result = engine.understand('https://example.com/012-3456789');

      expect(result.entities, hasLength(1));
      expect(result.entities.single.type, EntityType.url);
    });

    test('digits inside a www link belong to the link, whatever confidence',
        () {
      // The phone here scores 0.95 and the www link only 0.90. Containment
      // decides, not confidence.
      final result = engine.understand('www.example.com/012-3456789');

      expect(result.entities.single.type, EntityType.url);
    });

    test('nothing to understand gives an empty result', () {
      final result = engine.understand('Tiada apa-apa di sini');

      expect(result.isEmpty, isTrue);
      expect(result.primary, isNull);
    });

    test('entities come back in text order', () {
      final result = engine.understand(
        'https://a.com 012-3456789 www.b.com 019-8765432',
      );

      final starts = result.entities.map((e) => e.start).toList();
      expect(starts, List<int>.of(starts)..sort());
      expect(result.entities, hasLength(4));
    });
  });

  group('primary', () {
    test('is the most confident entity', () {
      final result = engine.understand('0123456789 https://example.com');

      expect(result.primary!.type, EntityType.url);
    });

    test('never removes the others', () {
      final result = engine.understand('0123456789 https://example.com');

      expect(result.entities, hasLength(2));
    });
  });

  group('PD-032 — REQUIRED normalisation safety, section 1.1', () {
    /// For every entity, the digits it would dial must be exactly the digits
    /// visible in its own displayed value. Nothing hidden may change the
    /// number.
    void expectNoHiddenDigits(List<DetectedEntity> entities) {
      final prefix = RegExp('^(0060|60|0)');
      for (final e in entities.where((e) => e.type == EntityType.phone)) {
        final visible = e.rawValue
            .replaceAll(RegExp(r'\D'), '')
            .replaceFirst(prefix, '');
        final dialled = e.normalizedValue
            .replaceAll(RegExp(r'\D'), '')
            .replaceFirst(prefix, '');
        expect(
          dialled,
          visible,
          reason: 'what is displayed must be exactly what would be dialled',
        );
      }
    }

    test('zero-width space inside a number: same number or nothing', () {
      final result = engine.understand('012-345${cp(0x200B)}6789');

      for (final e in result.entities) {
        expect(e.normalizedValue, '+60123456789');
      }
      expectNoHiddenDigits(result.entities);
    });

    test('right-to-left override cannot produce a disguised number', () {
      // Displays reversed; the cleaned characters are what matters.
      final result = engine.understand('${cp(0x202E)}9876543-210');

      expectNoHiddenDigits(result.entities);
      for (final e in result.entities) {
        expect(e.rawValue, isNot(contains(cp(0x202E))));
      }
    });

    test('zero-width space inside a URL host', () {
      final result = engine.understand('https://exam${cp(0x200B)}ple.com');

      expect(result.entities.single.normalizedValue, 'https://example.com');
    });

    test('soft hyphen inside a URL host', () {
      final result = engine.understand('https://bank${cp(0x00AD)}.com.my');

      expect(result.entities.single.normalizedValue, 'https://bank.com.my');
    });

    test('a bidi isolate wrapping an entity does not change it', () {
      final result = engine.understand(
        '${cp(0x2066)}012-3456789${cp(0x2069)}',
      );

      expect(result.entities.single.normalizedValue, '+60123456789');
    });

    test('text with no format characters is unchanged by normalisation', () {
      const text = 'Hubungi 012-3456789 atau https://example.com';

      expect(engine.understand(text).content.text, text);
    });

    test('invariant: no entity carries a format character', () {
      final dirty = <String>[
        '0${cp(0x200B)}12-345${cp(0x200D)}6789',
        '${cp(0x202E)}https://example.com${cp(0x202C)}',
        'w${cp(0xFEFF)}ww.example.com',
        '+6${cp(0x2060)}0 12 345 6789',
        '${cp(0x2067)}03-1234 5678${cp(0x2069)} ${cp(0x200E)}www.a.com.my',
      ];

      for (final input in dirty) {
        for (final e in engine.understand(input).entities) {
          expect(
            ContentNormalizer.containsFormatCharacter(e.rawValue),
            isFalse,
            reason: 'rawValue of ${e.type.name}',
          );
          expect(
            ContentNormalizer.containsFormatCharacter(e.normalizedValue),
            isFalse,
            reason: 'normalizedValue of ${e.type.name}',
          );
        }
      }
    });

    test('invariant holds even for a detector that misbehaves', () {
      // Guards the engine's second line of defence: a future detector that
      // builds a value from somewhere other than normalised text.
      final leaky = UnderstandingEngine(
        detectors: <EntityDetector>[_LeakyDetector()],
      );

      expect(leaky.understand('anything').entities, isEmpty);
    });
  });

  group('input cap — PD-028', () {
    test('input under the cap is analysed whole', () {
      final result = engine.understand('x' * 100);

      expect(result.wasTruncated, isFalse);
    });

    test('only the start of a longer input is analysed', () {
      final padding = 'x ' * UnderstandingEngine.defaultMaxInputLength;
      final result = engine.understand('$padding 012-3456789');

      expect(result.wasTruncated, isTrue);
      expect(result.entities, isEmpty);
    });

    test('an entity inside the cap is still found', () {
      final result = engine.understand(
        '012-3456789 ${'x' * UnderstandingEngine.defaultMaxInputLength}',
      );

      expect(result.wasTruncated, isTrue);
      expect(result.entities.single.type, EntityType.phone);
    });

    test('a very large input returns promptly', () {
      final huge = List<String>.filled(50000, '012-3456789 https://a.com')
          .join(' ');
      final watch = Stopwatch()..start();

      engine.understand(huge);

      // Generous bound. The point is that the cap stops a 1MB paste from
      // blocking the UI thread, not a benchmark.
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  test('result toString omits content', () {
    final result = engine.understand('private 012-3456789');

    expect(result.toString(), isNot(contains('private')));
    expect(result.toString(), isNot(contains('3456789')));
  });
}

final class _LeakyDetector implements EntityDetector {
  @override
  EntityType get type => EntityType.phone;

  @override
  List<DetectedEntity> detect(NormalizedContent content) => <DetectedEntity>[
    DetectedEntity(
      type: EntityType.phone,
      rawValue: '012-3456789',
      normalizedValue: '+6012345${String.fromCharCode(0x200B)}6789',
      confidence: 0.95,
      start: 0,
      end: 1,
    ),
  ];
}
