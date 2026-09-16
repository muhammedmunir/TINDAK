import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/understanding/detectors/money_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/money_value.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// docs/20_TEST_PLAN.md section 3. Money is stored as whole sen (ADR-023), and
/// `RM` is required — a bare number is never an amount (PD approval A-5).
void main() {
  const detector = MoneyDetector();
  const normalizer = ContentNormalizer();

  List<DetectedEntity> detect(String input) =>
      detector.detect(normalizer.normalize(input));

  int? senOf(String input) {
    final found = detect(input);
    if (found.isEmpty) return null;
    return MoneyValue.parse(found.single.normalizedValue)?.sen;
  }

  group('must detect — section 3.1', () {
    const cases = <String, int>{
      'RM25': 2500,
      'RM 25': 2500,
      'RM25.50': 2550,
      'RM 183.50': 18350,
      'RM1,500': 150000,
      'RM1,500.00': 150000,
      'RM 1,500.00': 150000,
      'MYR99': 9900,
      'rm25.50': 2550,
      'Rm25.50': 2550,
      'myr 25': 2500,
      'RM1,234,567.89': 123456789,
      'RM0.01': 1,
      'RM0': 0,
      'RM25.5': 2550,
      'RM100.00': 10000,
    };

    cases.forEach((input, sen) {
      test('$input is $sen sen', () => expect(senOf(input), sen));
    });

    test('the amount is exact, with no floating-point drift', () {
      // 0.1 + 0.2 as doubles is not 0.3; as sen it is exactly 30.
      expect(senOf('RM0.10')! + senOf('RM0.20')!, 30);
      expect(senOf('RM183.50'), 18350);
    });

    test('inside a sentence, with the span on the amount only', () {
      final found = detect('Bayar bil TNB RM183.50 sebelum tarikh akhir');

      expect(found.single.rawValue, 'RM183.50');
      expect(found.single.type, EntityType.money);
      expect(found.single.normalizedValue, 'MYR18350');
    });

    test('two amounts in one message stay two entities', () {
      final found = detect('RM25 hari ini dan RM50 kemudian');

      expect(found, hasLength(2));
      expect(found.map((e) => e.normalizedValue), <String>[
        'MYR2500',
        'MYR5000',
      ]);
    });

    test('confidence is higher when the amount is written out', () {
      expect(detect('RM25').single.confidence, 0.90);
      expect(detect('RM25.50').single.confidence, 0.95);
      expect(detect('RM1,500').single.confidence, 0.95);
    });
  });

  group('must not detect — section 3.2', () {
    const rejected = <String>[
      '1,500',
      '25',
      'RM',
      'RM.',
      'RM ',
      'RM1,2',
      'RM12.345',
      'RM25.555',
      'RM-25',
      'ROOM25',
      'WARM25',
      'HARGA25',
      '2026',
      '0123456789',
      'RM,500',
      'RM .50',
    ];

    for (final input in rejected) {
      test('"$input" is not money', () => expect(detect(input), isEmpty));
    }

    test('a malformed amount yields nothing at all, not a prefix', () {
      // The dangerous failure is RM12.345 quietly becoming RM12.34.
      expect(detect('RM12.345'), isEmpty);
      expect(detect('RM1,2'), isEmpty);
      expect(detect('RM1,23'), isEmpty);
    });

    test('a bare number is not money even next to a date', () {
      expect(detect('Bayar 1,500 sebelum 25/09/2026'), isEmpty);
    });
  });

  group('safety', () {
    test('an amount carries no invisible characters (PD-032)', () {
      // RM25 with a zero-width space between the digits.
      final input = 'RM2${String.fromCharCode(0x200B)}5';
      final found = detect(input);

      for (final entity in found) {
        expect(
          ContentNormalizer.containsFormatCharacter(entity.rawValue),
          isFalse,
        );
      }
    });

    test('an amount inside a longer number is not money', () {
      expect(detect('REF2026RM25X'), isEmpty);
    });

    test('the same text always gives the same result', () {
      final first = detect('RM1,500.00 dan RM25');
      final second = detect('RM1,500.00 dan RM25');

      expect(first.map((e) => e.normalizedValue), second.map((e) => e.normalizedValue));
    });
  });

  group('MoneyValue', () {
    test('display is canonical, whatever was typed (A-2)', () {
      expect(MoneyValue.parse(detect('rm25').single.normalizedValue)!.display,
          'RM25.00');
      expect(MoneyValue.parse(detect('RM 25').single.normalizedValue)!.display,
          'RM25.00');
      expect(const MoneyValue(150000).display, 'RM1,500.00');
      expect(const MoneyValue(18350).display, 'RM183.50');
      expect(const MoneyValue(123456789).display, 'RM1,234,567.89');
      expect(const MoneyValue(1).display, 'RM0.01');
    });

    test('search value covers the forms a person types', () {
      expect(const MoneyValue(18350).searchValue, 'rm183.50 183.50 18350');
    });

    test('an unreadable stored value is refused, not guessed', () {
      expect(MoneyValue.parse('183.50'), isNull);
      expect(MoneyValue.parse('MYR'), isNull);
      expect(MoneyValue.parse('USD100'), isNull);
    });

    test('prints no amount (docs/12_SECURITY.md section 11)', () {
      expect(const MoneyValue(18350).toString(), isNot(contains('18350')));
      expect(const MoneyValue(18350).toString(), isNot(contains('183.50')));
    });
  });
}
