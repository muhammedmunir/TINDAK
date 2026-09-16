import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/money_value.dart';

/// Money and Date inside the whole engine, alongside phone and URL.
///
/// docs/20_TEST_PLAN.md section 6. The engine is the only place that resolves
/// overlap between detectors, so this is where a new detector can break an old
/// one — the M3 and M4 protections are asserted here again, with money and
/// dates in the same text.
void main() {
  final today = DateTime(2026, 9, 10);
  final engine = UnderstandingEngine.withClock(FixedClock(today));

  List<DetectedEntity> understand(String input) =>
      engine.understand(input).entities;

  List<EntityType> typesIn(String input) =>
      understand(input).map((e) => e.type).toList();

  group('multi-entity', () {
    test('money and date together', () {
      final found = understand('Bayar bil RM183.50 sebelum 25/09/2026');

      expect(found.map((e) => e.type), <EntityType>[
        EntityType.money,
        EntityType.date,
      ]);
      expect(found.first.normalizedValue, 'MYR18350');
      expect(found.last.normalizedValue, '2026-09-25');
    });

    test('phone and money', () {
      expect(typesIn('Hubungi 012-345 6789 untuk bayar RM50'), <EntityType>[
        EntityType.phone,
        EntityType.money,
      ]);
    });

    test('URL and date', () {
      expect(typesIn('Daftar di https://tnb.com.my sebelum 30/09/2026'),
          <EntityType>[EntityType.url, EntityType.date]);
    });

    test('phone, URL, money and date in one message', () {
      final found = understand(
        'Bayar bil TNB RM183.50 sebelum 25/09/2026. '
        'Hubungi 012-345 6789 atau buka https://tnb.com.my',
      );

      expect(found.map((e) => e.type), <EntityType>[
        EntityType.money,
        EntityType.date,
        EntityType.phone,
        EntityType.url,
      ]);
      expect(
        found.map((e) => e.normalizedValue),
        <String>[
          'MYR18350',
          '2026-09-25',
          '+60123456789',
          'https://tnb.com.my',
        ],
      );
    });

    test('order follows position in the text, not detector order', () {
      final found = understand(
        '25/09/2026 https://a.com RM10 012-345 6789',
      );

      expect(found.map((e) => e.type), <EntityType>[
        EntityType.date,
        EntityType.url,
        EntityType.money,
        EntityType.phone,
      ]);
      for (var i = 1; i < found.length; i++) {
        expect(found[i].start, greaterThan(found[i - 1].start));
      }
    });

    test('nothing collapses: two amounts and two dates stay four entities', () {
      final found = understand(
        'RM25 pada 25/09/2026 dan RM50 pada 30/09/2026',
      );

      expect(found, hasLength(4));
      expect(found.map((e) => e.normalizedValue), <String>[
        'MYR2500',
        '2026-09-25',
        'MYR5000',
        '2026-09-30',
      ]);
    });
  });

  group('no regression in the M3 and M4 protections', () {
    test('an IC number is still not a phone, and not a date (PD-029)', () {
      expect(understand('IC saya 901231-14-5678'), isEmpty);
      expect(understand('901231145678'), isEmpty);
    });

    test('a long digit run is still nothing', () {
      expect(understand('012345678901234'), isEmpty);
      expect(understand('2026091012345678'), isEmpty);
    });

    test('an amount is not a phone number (RM guard)', () {
      expect(typesIn('RM1234567890'), <EntityType>[EntityType.money]);
    });

    test('a date is neither a phone nor money', () {
      expect(typesIn('25/09/2026'), <EntityType>[EntityType.date]);
      expect(typesIn('25.09.2026'), <EntityType>[EntityType.date]);
    });

    test('a date inside a link belongs to the link', () {
      expect(typesIn('https://example.com/2026/09/25'), <EntityType>[
        EntityType.url,
      ]);
    });

    test('digits inside a link are still not a phone', () {
      expect(typesIn('https://example.com/012-3456789'), <EntityType>[
        EntityType.url,
      ]);
    });

    test('a bare domain is still not a link (PD-027)', () {
      expect(understand('Jumpa saya di kedai.my esok'), isEmpty);
    });

    test('phone and URL still behave exactly as at M4', () {
      final found = understand('Hubungi 012-345 6789 atau https://tnb.com.my');

      expect(found.first.normalizedValue, '+60123456789');
      expect(found.last.normalizedValue, 'https://tnb.com.my');
    });
  });

  group('safety', () {
    test('no entity carries an invisible character (PD-032)', () {
      final zwsp = String.fromCharCode(0x200B);
      final found = understand('RM1$zwsp,500.00 pada 25$zwsp/09/2026');

      for (final entity in found) {
        expect(entity.rawValue.contains(zwsp), isFalse);
        expect(entity.normalizedValue.contains(zwsp), isFalse);
      }
    });

    test('a date written around a bidi override is not reordered', () {
      final rlo = String.fromCharCode(0x202E);
      final found = understand('Tarikh ${rlo}25/09/2026');

      for (final entity in found) {
        if (entity.type != EntityType.date) continue;
        expect(entity.normalizedValue, '2026-09-25');
      }
    });

    test('understanding needs no network and no clock beyond today', () {
      // Same input, two engines, same answer: nothing here depends on state.
      final a = UnderstandingEngine.withClock(FixedClock(today));
      final b = UnderstandingEngine.withClock(FixedClock(today));
      const input = 'RM183.50 pada 25 Ogos';

      expect(
        a.understand(input).entities.map((e) => e.normalizedValue),
        b.understand(input).entities.map((e) => e.normalizedValue),
      );
    });

    test('a no-year date resolves against the injected clock only', () {
      final early = UnderstandingEngine.withClock(
        FixedClock(DateTime(2026, 1, 1)),
      ).understand('25 Ogos').entities.single;
      final late = UnderstandingEngine.withClock(
        FixedClock(DateTime(2026, 12, 1)),
      ).understand('25 Ogos').entities.single;

      expect(early.normalizedValue, '2026-08-25');
      expect(late.normalizedValue, '2027-08-25');
    });
  });

  group('display forms, as a person sees them', () {
    test('money is canonical and date is fully resolved', () {
      final found = understand('bayar rm25 sebelum 25 Ogos');

      expect(MoneyValue.parse(found.first.normalizedValue)!.display, 'RM25.00');
      expect(
        DateValue.parse(found.last.normalizedValue)!.display,
        '25 Ogos 2027',
      );
    });
  });
}
