import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/understanding/detectors/phone_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

List<DetectedEntity> detect(String text) =>
    const PhoneDetector().detect(const ContentNormalizer().normalize(text));

/// docs/20_TEST_PLAN.md section 2. Every row of the specification is an
/// assertion here; a detector change that adds no row is either not a
/// behaviour change or is missing its test.
void main() {
  group('must detect — section 2.1', () {
    const cases = <String, String>{
      '0123456789': '+60123456789',
      '012-3456789': '+60123456789',
      '012-345 6789': '+60123456789',
      '+60123456789': '+60123456789',
      '+60 12-345 6789': '+60123456789',
      '011-12345678': '+601112345678',
      '0341234567': '+60341234567',
      '03-1234 5678': '+60312345678',
      '04-123 4567': '+6041234567',
      '082-123456': '+6082123456',
      '019 8765432': '+60198765432',
      '60123456789': '+60123456789',
    };

    cases.forEach((input, e164) {
      test('$input → $e164', () {
        final found = detect(input);

        expect(found, hasLength(1), reason: input);
        expect(found.single.type, EntityType.phone);
        expect(found.single.normalizedValue, e164);
        expect(found.single.rawValue, input);
      });
    });
  });

  group('must NOT detect — section 2.2, REQUIRED safety tests (PD-029)', () {
    const cases = <String, String>{
      '901231-14-5678': 'Malaysian IC, hyphenated',
      '900101-03-1234': 'Malaysian IC, hyphenated',
      '900101 03 1234': 'Malaysian IC, spaced',
      '900101031234': 'Malaysian IC, unseparated',
      '012345678901234': 'digit run longer than any valid number',
      'RM1234567890': 'preceded by a currency marker',
      'RM 0123456789': 'preceded by a currency marker and a space',
      'MYR0123456789': 'preceded by MYR',
      '2026091012345678': 'order or reference number',
      '1300-88-1234': 'toll-free short code, out of scope',
      '999': 'emergency short code',
    };

    cases.forEach((input, why) {
      test('$input — $why', () {
        expect(detect(input), isEmpty, reason: why);
      });
    });

    test('an IC number inside a sentence is still never a phone', () {
      expect(detect('No IC saya 900101-03-1234 terima kasih'), isEmpty);
    });

    test('an IC whose digits start with 01 is never a phone', () {
      // Born 2001: the IC begins 01, the same prefix as a mobile number.
      expect(detect('010203-14-5678'), isEmpty);
      expect(detect('011231-01-2345'), isEmpty);
    });

    test('an IC next to a real phone does not hide the phone', () {
      final found = detect('IC 900101-03-1234, telefon 012-3456789');

      expect(found, hasLength(1));
      expect(found.single.normalizedValue, '+60123456789');
    });
  });

  group('mobile length rules', () {
    test('011 requires eleven digits', () {
      expect(detect('011-12345678'), hasLength(1));
      expect(detect('011-1234567'), isEmpty);
    });

    test('015 requires eleven digits', () {
      expect(detect('015-46001234'), hasLength(1));
      expect(detect('015-4600123'), isEmpty);
    });

    test('other mobile prefixes require ten digits', () {
      for (final prefix in <String>['010', '012', '013', '014', '016', '017',
          '018', '019']) {
        expect(detect('$prefix-3456789'), hasLength(1), reason: prefix);
        expect(detect('$prefix-34567890'), isEmpty, reason: prefix);
      }
    });
  });

  group('landline rules', () {
    test('Klang Valley 03 needs eight subscriber digits', () {
      expect(detect('03-1234 5678'), hasLength(1));
      expect(detect('03-123 4567'), isEmpty);
    });

    test('other peninsular codes need seven', () {
      for (final code in <String>['04', '05', '06', '07', '09']) {
        expect(detect('$code-123 4567'), hasLength(1), reason: code);
      }
    });

    test('Sabah and Sarawak codes take six or seven', () {
      expect(detect('082-123456'), hasLength(1));
      expect(detect('088-1234567'), hasLength(1));
      expect(detect('081-123456'), isEmpty);
    });

    test('parenthesised area code', () {
      final found = detect('(03) 1234 5678');

      expect(found.single.normalizedValue, '+60312345678');
    });
  });

  group('confidence — section 2.3', () {
    test('explicit +60 is 0.95', () {
      expect(detect('+60123456789').single.confidence, 0.95);
    });

    test('separators in place are 0.95', () {
      expect(detect('012-3456789').single.confidence, 0.95);
    });

    test('bare digits with a valid prefix are 0.80', () {
      expect(detect('0123456789').single.confidence, 0.80);
    });

    test('a bare country code without + is 0.60', () {
      expect(detect('60123456789').single.confidence, 0.60);
    });
  });

  group('numbers in running text', () {
    test('finds a number inside a sentence', () {
      final found = detect('Hubungi Ahmad 012-345 6789 esok');

      expect(found.single.rawValue, '012-345 6789');
      expect(found.single.start, 14);
    });

    test('finds two numbers separated only by a space', () {
      final found = detect('0123456789 0198765432');

      expect(
        found.map((e) => e.normalizedValue),
        <String>['+60123456789', '+60198765432'],
      );
    });

    test('a stray digit after a number does not spoil it', () {
      final found = detect('Call 012-3456789 2 kali');

      expect(found.single.normalizedValue, '+60123456789');
    });

    test('a time before a number does not spoil it', () {
      final found = detect('3.30 0123456789');

      expect(found.single.normalizedValue, '+60123456789');
    });

    test('an amount before a number does not spoil it', () {
      final found = detect('RM183.50 0123456789');

      expect(found.single.normalizedValue, '+60123456789');
    });

    test('a number glued to letters is not a phone', () {
      expect(detect('A0123456789'), isEmpty);
      expect(detect('0123456789abc'), isEmpty);
    });

    test('a date is not a phone', () {
      expect(detect('25-09-2026'), isEmpty);
      expect(detect('03-04-2026'), isEmpty);
      expect(detect('25.09.2026'), isEmpty);
    });

    test('offsets map back onto the normalised text', () {
      const text = 'Tel: 03-1234 5678.';
      final found = detect(text).single;

      expect(text.substring(found.start, found.end), found.rawValue);
    });
  });

  group('separators from the normaliser', () {
    test('a non-breaking space still separates groups', () {
      final nbsp = String.fromCharCode(0x00A0);

      expect(
        detect('012${nbsp}345${nbsp}6789').single.normalizedValue,
        '+60123456789',
      );
    });
  });
}
