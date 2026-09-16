import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/understanding/detectors/date_detector.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// docs/20_TEST_PLAN.md section 4. Every case that depends on "today" pins the
/// clock, so behaviour never changes with the month the suite runs in.
void main() {
  const normalizer = ContentNormalizer();

  List<DetectedEntity> detectOn(String input, DateTime today) =>
      DateDetector(clock: FixedClock(today)).detect(normalizer.normalize(input));

  List<DetectedEntity> detect(String input) =>
      detectOn(input, DateTime(2026, 9, 10));

  String? isoOf(String input, [DateTime? today]) {
    final found = detectOn(input, today ?? DateTime(2026, 9, 10));
    return found.isEmpty ? null : found.single.normalizedValue;
  }

  group('must detect — section 4.1', () {
    const cases = <String, String>{
      '25/09/2026': '2026-09-25',
      '25-09-2026': '2026-09-25',
      '25.09.2026': '2026-09-25',
      '25/9/2026': '2026-09-25',
      '5/9/2026': '2026-09-05',
      '25 September 2026': '2026-09-25',
      '25 Sep 2026': '2026-09-25',
      '25 Ogos 2026': '2026-08-25',
      '25 ogos 2026': '2026-08-25',
      '25 Aug 2026': '2026-08-25',
      '25 August 2026': '2026-08-25',
      '25 Disember 2026': '2026-12-25',
      '1 Mac 2026': '2026-03-01',
      '1 Mar 2026': '2026-03-01',
      '1 Mei 2026': '2026-05-01',
      '1 May 2026': '2026-05-01',
      '29/02/2028': '2028-02-29',
      '31/12/2026': '2026-12-31',
    };

    cases.forEach((input, iso) {
      test('$input is $iso', () => expect(isoOf(input), iso));
    });

    test('DD/MM, never MM/DD (PD-008)', () {
      expect(isoOf('03/04/2026'), '2026-04-03');
    });

    test('inside a sentence, with the span on the date only', () {
      final found = detect('Temujanji pada 25/09/2026 di klinik');

      expect(found.single.rawValue, '25/09/2026');
      expect(found.single.type, EntityType.date);
      expect(found.single.confidence, 0.95);
    });

    test('two dates in one message stay two entities', () {
      final found = detect('25/09/2026 dan 30/09/2026');

      expect(found.map((e) => e.normalizedValue), <String>[
        '2026-09-25',
        '2026-09-30',
      ]);
    });
  });

  group('must not detect — section 4.2', () {
    const rejected = <String>[
      '32/09/2026',
      '25/13/2026',
      '31/02/2026',
      '31/04/2026',
      '29/02/2025',
      '00/09/2026',
      '25/00/2026',
      '2026',
      '0341234567',
      '25 Foobar 2026',
      '25/09/2026/01',
      '125/09/2026',
    ];

    for (final input in rejected) {
      test('"$input" is not a date', () => expect(detect(input), isEmpty));
    }

    test('a phone number is never a date', () {
      expect(detect('Hubungi 012-345 6789'), isEmpty);
      expect(detect('03-1234 5678'), isEmpty);
    });
  });

  group('two-digit years — rejected (ADR-026)', () {
    const rejected = <String>['25/08/26', '25-08-26', '1/1/26', '25.08.26'];

    for (final input in rejected) {
      test('"$input" yields nothing', () => expect(detect(input), isEmpty));
    }

    test('26 is never silently read as 2026', () {
      expect(detect('25/08/26').map((e) => e.normalizedValue), isEmpty);
    });
  });

  group('no year — next occurrence (PD-025, section 4.4)', () {
    test('still ahead this year', () {
      expect(isoOf('25 September', DateTime(2026, 9, 10)), '2026-09-25');
    });

    test('already passed, so next year', () {
      expect(isoOf('3 Mac', DateTime(2026, 9, 10)), '2027-03-03');
    });

    test('across the year boundary', () {
      expect(isoOf('1 Januari', DateTime(2026, 12, 31)), '2027-01-01');
    });

    test('today stays today, not next year', () {
      expect(isoOf('25 Ogos', DateTime(2026, 8, 25)), '2026-08-25');
    });

    test('yesterday becomes next year', () {
      expect(isoOf('25 Ogos', DateTime(2026, 8, 26)), '2027-08-25');
    });

    test('tomorrow stays this year', () {
      expect(isoOf('25 Ogos', DateTime(2026, 8, 24)), '2026-08-25');
    });

    test('29 February skips to the next leap year', () {
      expect(isoOf('29 Februari', DateTime(2026, 3, 1)), '2028-02-29');
    });

    test('an inferred year is less certain, and flagged', () {
      final inferred = detectOn('25 Ogos', DateTime(2026, 1, 1)).single;
      final written = detectOn('25 Ogos 2026', DateTime(2026, 1, 1)).single;

      expect(inferred.confidence, 0.85);
      expect(inferred.yearInferred, isTrue);
      expect(written.confidence, 0.95);
      expect(written.yearInferred, isFalse);
    });

    test('the flag survives a round trip through storage', () {
      // yearInferred is derived from the written text, so it holds after a
      // save and a sync without a column of its own (PD approval A-4).
      final entity = detectOn('25 Ogos', DateTime(2026, 1, 1)).single;
      final restored = DetectedEntity(
        type: entity.type,
        rawValue: entity.rawValue,
        normalizedValue: entity.normalizedValue,
        confidence: entity.confidence,
        start: entity.start,
        end: entity.end,
      );

      expect(restored.yearInferred, isTrue);
    });
  });

  group('DateValue', () {
    test('display is the full resolved date in Malay (A-3)', () {
      expect(const DateValue(2026, 9, 25).display, '25 September 2026');
      expect(const DateValue(2026, 3, 1).display, '1 Mac 2026');
      expect(const DateValue(2026, 12, 25).display, '25 Disember 2026');
      expect(const DateValue(2026, 5, 2).display, '2 Mei 2026');
    });

    test('an inferred date displays the year it resolved to', () {
      final entity = detectOn('25 Ogos', DateTime(2026, 9, 10)).single;

      expect(
        DateValue.parse(entity.normalizedValue)!.display,
        '25 Ogos 2027',
      );
    });

    test('search value covers ISO, numeric and month-name forms', () {
      expect(
        const DateValue(2026, 9, 25).searchValue,
        '2026-09-25 25/09/2026 25 september 2026',
      );
    });

    test('an impossible date cannot be built', () {
      expect(DateValue.build(2026, 2, 31), isNull);
      expect(DateValue.build(2025, 2, 29), isNull);
      expect(DateValue.build(2028, 2, 29), isNotNull);
      expect(DateValue.build(2026, 13, 1), isNull);
    });

    test('an unreadable stored value is refused, not guessed', () {
      expect(DateValue.parse('25/09/2026'), isNull);
      expect(DateValue.parse('2026-02-31'), isNull);
      expect(DateValue.parse(''), isNull);
    });
  });

  group('relative expressions stay out of scope', () {
    const outOfScope = <String>[
      'esok',
      'lusa',
      'minggu depan',
      'Jumaat depan',
      'malam ini',
      '3 petang',
      '8:30 PM',
      'hari ini',
    ];

    for (final input in outOfScope) {
      test('"$input" is not a date in V1', () => expect(detect(input), isEmpty));
    }
  });
}
