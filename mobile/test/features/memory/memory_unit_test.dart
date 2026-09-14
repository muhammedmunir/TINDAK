import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/memory/data/memory_search.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';
import 'package:tindak/shared/saved_date_label.dart';

/// A repository whose save can be held open, to test racing presses.
final class GatedRepository implements MemoryRepository {
  int saves = 0;
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<Result<String>> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  }) async {
    saves += 1;
    if (gate != null) await gate!.future;
    return fail
        ? const Result<String>.err(StorageFailure())
        : Result<String>.ok('id-$saves');
  }

  @override
  Stream<List<MemoryRecord>> watch({String query = ''}) =>
      const Stream<List<MemoryRecord>>.empty();

  @override
  Future<Result<MemoryRecord>> findById(String id) async =>
      const Result<MemoryRecord>.err(NotFoundFailure());

  @override
  Future<Result<void>> delete(String id) async =>
      const Result<void>.err(NotFoundFailure());
}

void main() {
  group('MemorySaver', () {
    final incoming = IncomingText.pasted('x', at: DateTime.utc(2026));
    final understanding = const UnderstandingEngine().understand('x');

    test('a completed press saves', () async {
      final repo = GatedRepository();

      expect(
        await MemorySaver(repo).save(
          incoming: incoming,
          understanding: understanding,
        ),
        SaveOutcome.saved,
      );
      expect(repo.saves, 1);
    });

    test('two separate presses are two saves', () async {
      final repo = GatedRepository();
      final saver = MemorySaver(repo);

      await saver.save(incoming: incoming, understanding: understanding);
      await saver.save(incoming: incoming, understanding: understanding);

      expect(repo.saves, 2);
    });

    test('a press while the previous write is still running is ignored',
        () async {
      // A physical double tap racing a database write — not a second decision.
      final repo = GatedRepository()..gate = Completer<void>();
      final saver = MemorySaver(repo);

      final first = saver.save(incoming: incoming, understanding: understanding);
      final second = await saver.save(
        incoming: incoming,
        understanding: understanding,
      );

      expect(second, SaveOutcome.busy);
      repo.gate!.complete();
      expect(await first, SaveOutcome.saved);
      expect(repo.saves, 1);
    });

    test('a failure is reported and does not leave the saver stuck', () async {
      final repo = GatedRepository()..fail = true;
      final saver = MemorySaver(repo);

      expect(
        await saver.save(incoming: incoming, understanding: understanding),
        SaveOutcome.failed,
      );

      repo.fail = false;
      expect(
        await saver.save(incoming: incoming, understanding: understanding),
        SaveOutcome.saved,
      );
    });
  });

  group('MemorySearch', () {
    final phone = const UnderstandingEngine()
        .understand('012-345 6789')
        .entities
        .single;
    final url = const UnderstandingEngine()
        .understand('https://WWW.TNB.com.my/Bayar')
        .entities
        .single;

    test('a phone is searchable in national and international digits', () {
      expect(MemorySearch.searchValueFor(phone), '0123456789 60123456789');
    });

    test('a link is searchable lowercased', () {
      expect(MemorySearch.searchValueFor(url), 'https://www.tnb.com.my/Bayar'
          .toLowerCase());
    });

    test('a query is trimmed and capped', () {
      expect(MemorySearch.textOf('  tnb  '), 'tnb');
      expect(MemorySearch.textOf('a' * 500).length, MemorySearch.maxQueryLength);
    });

    test('digits are extracted only when there are enough', () {
      expect(MemorySearch.digitsOf('012-345 6789'), '0123456789');
      expect(MemorySearch.digitsOf('01'), '');
      expect(MemorySearch.digitsOf('tnb'), '');
    });

    test('LIKE wildcards are escaped', () {
      expect(MemorySearch.containsPattern('100%'), r'%100\%%');
      expect(MemorySearch.containsPattern('a_b'), r'%a\_b%');
      expect(MemorySearch.containsPattern(r'a\b'), r'%a\\b%');
    });
  });

  group('savedDateLabel', () {
    final today = DateTime(2026, 9, 15, 10);

    test('today', () {
      expect(savedDateLabel(DateTime(2026, 9, 15, 8, 5), today: today),
          'Hari ini, 08:05');
    });

    test('yesterday', () {
      expect(savedDateLabel(DateTime(2026, 9, 14, 23, 59), today: today),
          'Semalam, 23:59');
    });

    test('older dates are DD/MM/YYYY (PD-008)', () {
      expect(savedDateLabel(DateTime(2026, 3, 4, 14, 30), today: today),
          '04/03/2026, 14:30');
    });

    test('across a year boundary', () {
      expect(
        savedDateLabel(DateTime(2026, 12, 31, 23), today: DateTime(2027, 1, 1)),
        'Semalam, 23:00',
      );
    });
  });
}
