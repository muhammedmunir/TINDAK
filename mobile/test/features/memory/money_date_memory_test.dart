import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/test_database.dart';

/// Money and dates through the Memory pipeline: explicit Save, then local
/// search by the original text and by the extracted values (M6b).
///
/// Search stays LIKE-based (ADR-030) — no full-text index, no ranking model.
void main() {
  late TindakDatabase db;
  late DriftMemoryRepository repo;
  final today = DateTime.utc(2026, 9, 10);
  late UnderstandingEngine engine;

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    engine = UnderstandingEngine.withClock(FixedClock(today));
    repo = DriftMemoryRepository(db, clock: FixedClock(today));
  });

  Future<String> save(String text) async {
    final result = await repo.save(
      incoming: IncomingText.pasted(text, at: today),
      understanding: engine.understand(text),
    );
    return result.valueOrNull!;
  }

  Future<List<MemoryRecord>> find(String query) => repo.watch(query: query).first;

  group('save', () {
    test('stores the original text, with money and date entities', () async {
      final id = await save('Bayar RM183.50 pada 25/09/2026');
      final record = (await repo.findById(id)).valueOrNull!;

      // The original is kept exactly as written.
      expect(record.content, 'Bayar RM183.50 pada 25/09/2026');
      expect(record.entities.map((e) => e.type), <EntityType>[
        EntityType.money,
        EntityType.date,
      ]);
      expect(record.entities.map((e) => e.normalizedValue), <String>[
        'MYR18350',
        '2026-09-25',
      ]);
    });

    test('a no-year date is stored resolved, and stays flagged', () async {
      final id = await save('Mesyuarat 25 Ogos');
      final record = (await repo.findById(id)).valueOrNull!;
      final date = record.entities.single;

      // Today is 10 September 2026, so 25 Ogos has passed: next occurrence is
      // next year (PD-025).
      expect(date.normalizedValue, '2027-08-25');
      // Derived from the written text, so it survives the round trip with no
      // column of its own (PD approval A-4).
      expect(date.yearInferred, isTrue);
    });

    test('every valid amount and date is kept separately', () async {
      final id = await save('RM25 pada 25/09/2026 dan RM50 pada 30/09/2026');
      final record = (await repo.findById(id)).valueOrNull!;

      expect(record.entities, hasLength(4));
    });
  });

  group('search', () {
    setUp(() async {
      await save('Bayar bil TNB RM183.50 sebelum 25/09/2026');
      await save('Sewa RM1,500.00 pada 1 Oktober 2026');
      await save('Tiada nombor di sini');
    });

    test('by original text', () async {
      expect((await find('TNB')).single.content, contains('TNB'));
      expect((await find('sewa')).single.content, contains('Sewa'));
    });

    test('by the amount as written', () async {
      expect((await find('183.50')).single.content, contains('TNB'));
      expect((await find('RM183.50')).single.content, contains('TNB'));
      expect((await find('1,500')).single.content, contains('Sewa'));
    });

    test('by the amount as stored, in sen', () async {
      expect((await find('18350')).single.content, contains('TNB'));
    });

    test('by the date as written', () async {
      expect((await find('25/09/2026')).single.content, contains('TNB'));
    });

    test('by the date as stored, in ISO', () async {
      expect((await find('2026-09-25')).single.content, contains('TNB'));
    });

    test('by month name, including a date written with one', () async {
      expect((await find('oktober')).single.content, contains('Sewa'));
    });

    test('a query matching nothing returns nothing', () async {
      expect(await find('RM999.99'), isEmpty);
      expect(await find('2030-01-01'), isEmpty);
    });

    test('the same query always returns the same rows', () async {
      final first = await find('183.50');
      final second = await find('183.50');

      expect(first.map((r) => r.id), second.map((r) => r.id));
    });
  });

  group('delete still removes everything derived', () {
    test('an amount is no longer findable after delete', () async {
      final id = await save('Bayar RM77.70 pada 25/12/2026');
      expect(await find('77.70'), hasLength(1));

      await repo.delete(id);

      expect(await find('77.70'), isEmpty);
      expect(await find('2026-12-25'), isEmpty);
      expect(await db.select(db.memoryEntities).get(), isEmpty);
    });
  });
}
