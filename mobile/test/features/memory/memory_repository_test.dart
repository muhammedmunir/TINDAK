import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/test_database.dart';

IncomingText shared(String text) => IncomingText(
  text: text,
  source: IntakeSource.share,
  sequence: 1,
  receivedAt: DateTime.utc(2026, 9, 14),
  sourceApp: 'com.android.chrome',
);

IncomingText pasted(String text) =>
    IncomingText.pasted(text, at: DateTime.utc(2026, 9, 14));

void main() {
  late TindakDatabase db;
  late DriftMemoryRepository repo;
  late _SteppingClock clock;
  const engine = UnderstandingEngine();

  setUp(() {
    db = openTestDatabase();
    clock = _SteppingClock(DateTime.utc(2026, 9, 14, 8));
    repo = DriftMemoryRepository(db, clock: clock);
    addTearDown(db.close);
  });

  Future<String> save(IncomingText incoming) async {
    final result = await repo.save(
      incoming: incoming,
      understanding: engine.understand(incoming.text),
    );
    return result.valueOrNull!;
  }

  Future<List<MemoryRecord>> list([String query = '']) =>
      repo.watch(query: query).first;

  /// Makes every write fail with a real SQLite error.
  ///
  /// Closing the database is not a failure simulation: Drift silently reopens
  /// an in-memory database with a fresh schema, so the write succeeds.
  Future<void> breakDatabase() async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE memory_entities');
    await db.customStatement('DROP TABLE memories');
  }

  group('save', () {
    test('stores plain text with nothing detected', () async {
      final id = await save(shared('Beli susu dan roti'));

      final record = (await repo.findById(id)).valueOrNull!;
      expect(record.content, 'Beli susu dan roti');
      expect(record.entities, isEmpty);
    });

    test('stores multi-entity text with every entity (PD-002)', () async {
      final id = await save(
        shared('Hubungi 012-345 6789, pejabat 03-1234 5678, https://tnb.com.my'),
      );

      final record = (await repo.findById(id)).valueOrNull!;
      expect(record.entities.map((e) => e.type), <EntityType>[
        EntityType.phone,
        EntityType.phone,
        EntityType.url,
      ]);
      expect(record.entities.first.normalizedValue, '+60123456789');
    });

    test('preserves the original text exactly', () async {
      const original = '  Hubungi saya\n\t012-345 6789  <b>esok</b> 你好 🇲🇾  ';
      final id = await save(pasted(original));

      expect((await repo.findById(id)).valueOrNull!.content, original);
    });

    test('keeps invisible characters in the stored original', () async {
      // Normalisation is for detection only. The user's text is not rewritten,
      // and the entity values stay clean (PD-032).
      final withZeroWidth = 'Hubungi 012-345${String.fromCharCode(0x200B)}6789';
      final id = await save(shared(withZeroWidth));

      final record = (await repo.findById(id)).valueOrNull!;
      expect(record.content, withZeroWidth);
      expect(record.entities.single.normalizedValue, '+60123456789');
    });

    test('records the intake source and sending app', () async {
      final a = await save(shared('x'));
      final b = await save(pasted('y'));

      expect((await repo.findById(a)).valueOrNull!.source, IntakeSource.share);
      expect((await repo.findById(a)).valueOrNull!.sourceApp, 'com.android.chrome');
      expect((await repo.findById(b)).valueOrNull!.source, IntakeSource.paste);
      expect((await repo.findById(b)).valueOrNull!.sourceApp, isNull);
    });

    test('writes a guest-owned, local-only row with a UUID id', () async {
      final id = await save(shared('x'));

      final row = await db.select(db.memories).getSingle();
      expect(row.id, id);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );
      expect(row.ownerUserId, isNull);
      expect(row.syncStatus, 'local_only');
      expect(row.deletedAt, isNull);
      expect(row.createdAt, row.updatedAt);
    });

    test('two explicit saves of the same text are two memories', () async {
      // Product rule: two presses of Simpan are two user actions. Nothing is
      // silently deduplicated.
      final first = await save(shared('Hubungi 012-3456789'));
      final second = await save(shared('Hubungi 012-3456789'));

      expect(first, isNot(second));
      expect(await list(), hasLength(2));
    });

    group('content limit — PD-039', () {
      const limit = TindakDatabase.maxContentLength;

      test('exactly the limit is saved in full', () async {
        final atLimit = 'a' * limit;
        final id = await save(pasted(atLimit));

        expect((await repo.findById(id)).valueOrNull!.content, atLimit);
      });

      test('one character over the limit is refused, not truncated', () async {
        final over = 'a' * (limit + 1);

        final result = await repo.save(
          incoming: pasted(over),
          understanding: engine.understand(over),
        );

        expect(result.failureOrNull, const ContentTooLongFailure(limit));
        expect(await db.select(db.memories).get(), isEmpty);
        expect(await db.select(db.memoryEntities).get(), isEmpty);
      });

      test('a long share is refused rather than saved partially', () async {
        final long = 'Hubungi 012-3456789 ${'a' * limit}';

        final result = await repo.save(
          incoming: shared(long),
          understanding: engine.understand(long),
        );

        expect(result.isErr, isTrue);
        expect(await list(), isEmpty);
      });

      test('the limit counts characters, not UTF-16 units', () async {
        // Each emoji is one character but two UTF-16 code units. Counting code
        // units would refuse this, while SQLite and Postgres both accept it —
        // the app and the database would disagree about the same text.
        final emoji = '😀' * limit;
        expect(emoji.length, limit * 2);

        final id = await save(pasted(emoji));

        expect((await repo.findById(id)).valueOrNull!.content, emoji);
      });

      test('one emoji over the limit is refused', () async {
        final over = '😀' * (limit + 1);

        final result = await repo.save(
          incoming: pasted(over),
          understanding: engine.understand(over),
        );

        expect(result.failureOrNull, isA<ContentTooLongFailure>());
      });

      test('the database refuses it even when the repository is bypassed',
          () async {
        // The guard that matters: a future code path, a bug, or a direct write
        // cannot store more than the limit, because SQLite itself refuses.
        await expectLater(
          db
              .into(db.memories)
              .insert(
                MemoriesCompanion.insert(
                  id: '11111111-1111-4111-8111-111111111111',
                  content: 'a' * (limit + 1),
                  intakeSource: 'paste',
                  createdAt: 1,
                  updatedAt: 1,
                  syncStatus: 'local_only',
                ),
              ),
          throwsA(isA<Exception>()),
        );
        expect(await db.select(db.memories).get(), isEmpty);
      });

      test('the database accepts exactly the limit when bypassed', () async {
        await db
            .into(db.memories)
            .insert(
              MemoriesCompanion.insert(
                id: '11111111-1111-4111-8111-111111111111',
                content: '😀' * limit,
                intakeSource: 'paste',
                createdAt: 1,
                updatedAt: 1,
                syncStatus: 'local_only',
              ),
            );

        expect(await db.select(db.memories).get(), hasLength(1));
      });
    });

    test('a database failure fails safely', () async {
      await breakDatabase();

      final result = await repo.save(
        incoming: shared('x'),
        understanding: engine.understand('x'),
      );

      expect(result.failureOrNull, isA<StorageFailure>());
    });
  });

  group('list', () {
    test('is empty before anything is saved', () async {
      expect(await list(), isEmpty);
    });

    test('is newest first', () async {
      await save(shared('first'));
      await save(shared('second'));
      await save(shared('third'));

      expect((await list()).map((r) => r.content), <String>[
        'third',
        'second',
        'first',
      ]);
    });

    test('updates when a memory is saved', () async {
      final emissions = <int>[];
      final sub = repo.watch().listen((records) => emissions.add(records.length));
      addTearDown(sub.cancel);

      await pumpEventQueue();
      await save(shared('x'));
      await pumpEventQueue();

      expect(emissions, containsAllInOrder(<int>[0, 1]));
    });

    test('never shows a tombstoned row (future sync, PD-021)', () async {
      final id = await save(shared('x'));
      await db.customStatement(
        "UPDATE memories SET owner_user_id = 'u', sync_status = 'pending', "
        'deleted_at = 1 WHERE id = ?',
        <Object?>[id],
      );

      expect(await list(), isEmpty);
      expect(await list('x'), isEmpty);
      expect((await repo.findById(id)).failureOrNull, isA<NotFoundFailure>());
    });

    test('skips an entity of a type this version does not know', () async {
      final id = await save(shared('Hubungi 012-3456789'));
      await db.customStatement(
        "UPDATE memory_entities SET type = 'hologram' WHERE memory_id = ?",
        <Object?>[id],
      );

      final record = (await list()).single;
      expect(record.content, 'Hubungi 012-3456789');
      expect(record.entities, isEmpty);
    });
  });

  group('search — local, deterministic, non-AI (PD-004)', () {
    setUp(() async {
      await save(shared('Hubungi saya 012-345 6789'));
      await save(shared('Bayar bil TNB di https://www.tnb.com.my/bayar'));
      await save(pasted('Beli susu 100% segar_hari ini'));
    });

    Future<List<String>> found(String query) async =>
        (await list(query)).map((r) => r.content).toList();

    test('an empty query shows everything', () async {
      expect(await found(''), hasLength(3));
      expect(await found('   '), hasLength(3));
    });

    test('matches original text', () async {
      expect(await found('Hubungi'), <String>['Hubungi saya 012-345 6789']);
    });

    test('is case-insensitive', () async {
      expect(await found('hubungi'), hasLength(1));
      expect(await found('TNB'), hasLength(1));
      expect(await found('tnb'), hasLength(1));
    });

    test('matches part of a word', () async {
      expect(await found('Hubu'), hasLength(1));
    });

    test('finds a phone by its national form', () async {
      expect(await found('0123456789'), <String>['Hubungi saya 012-345 6789']);
    });

    test('finds a phone however it is punctuated', () async {
      for (final q in <String>['012-3456789', '012 345 6789', '+60123456789',
          '60123456789', '3456789']) {
        expect(await found(q), <String>['Hubungi saya 012-345 6789'], reason: q);
      }
    });

    test('finds a link by its host', () async {
      expect(await found('tnb.com.my'), hasLength(1));
      expect(await found('www.tnb'), hasLength(1));
    });

    test('finds text as written in the original', () async {
      expect(await found('345 6789'), hasLength(1));
    });

    test('no match gives an empty result', () async {
      expect(await found('tiada langsung'), isEmpty);
    });

    test('% and _ are literal, not wildcards', () async {
      expect(await found('100%'), hasLength(1));
      expect(await found('segar_hari'), hasLength(1));
      expect(await found('%'), hasLength(1));
      expect(await found('_'), hasLength(1));
      expect(await found(r'\'), isEmpty);
    });

    test('two digits alone do not match as a number', () async {
      // "0-1" is not in any text, and its digits "01" are too short to be
      // matched against phone numbers — otherwise it would match every mobile.
      expect(await found('0-1'), isEmpty);
    });

    test('three digits do match as a number', () async {
      expect(await found('0-12'), <String>['Hubungi saya 012-345 6789']);
    });

    test('a very long query does not fail', () async {
      expect(await found('a' * 5000), isEmpty);
    });

    test('the same query always gives the same result', () async {
      expect(await found('0123456789'), await found('0123456789'));
    });
  });

  group('delete — permanent, user-visible (PD-006)', () {
    test('removes the correct record only', () async {
      final keep = await save(shared('keep me'));
      final remove = await save(shared('remove me'));

      expect((await repo.delete(remove)).isOk, isTrue);

      expect((await list()).map((r) => r.id), <String>[keep]);
      expect((await repo.findById(remove)).failureOrNull, isA<NotFoundFailure>());
      expect((await repo.findById(keep)).isOk, isTrue);
    });

    test('the row is physically gone, not hidden', () async {
      final id = await save(shared('Hubungi 012-3456789'));

      await repo.delete(id);

      expect(await db.select(db.memories).get(), isEmpty);
      expect(await db.select(db.memoryEntities).get(), isEmpty);
    });

    test('a deleted record no longer appears in search', () async {
      final id = await save(shared('Hubungi 012-3456789'));
      await repo.delete(id);

      expect(await list('Hubungi'), isEmpty);
      expect(await list('0123456789'), isEmpty);
    });

    test('deleting twice fails safely the second time', () async {
      final id = await save(shared('x'));
      await repo.delete(id);

      expect((await repo.delete(id)).failureOrNull, isA<NotFoundFailure>());
    });

    test('an unknown id fails safely', () async {
      expect(
        (await repo.delete('00000000-0000-4000-8000-000000000000')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

  });

  group('accounts — M5b', () {
    String? signedIn;
    late DriftMemoryRepository accountRepo;

    setUp(() {
      signedIn = null;
      accountRepo = DriftMemoryRepository(
        db,
        clock: clock,
        currentUserId: () => signedIn,
      );
    });

    Future<String> saveAs(String? user, String text) async {
      signedIn = user;
      final result = await accountRepo.save(
        incoming: shared(text),
        understanding: engine.understand(text),
      );
      return result.valueOrNull!;
    }

    Future<MemoryRow> rowOf(String id) =>
        (db.select(db.memories)..where((m) => m.id.equals(id))).getSingle();

    test('a guest save stays device-only', () async {
      final id = await saveAs(null, 'guest');

      final row = await rowOf(id);
      expect(row.ownerUserId, isNull);
      expect(row.syncStatus, 'local_only');
      expect((await accountRepo.findById(id)).valueOrNull!.storage,
          MemoryStorage.deviceOnly);
    });

    test('a signed-in save belongs to the account and waits for sync '
        '(PD-042)', () async {
      final id = await saveAs('user-a', 'account');

      final row = await rowOf(id);
      expect(row.ownerUserId, 'user-a');
      expect(row.syncStatus, 'pending');
      expect(row.serverUpdatedAt, isNull);
      expect((await accountRepo.findById(id)).valueOrNull!.storage,
          MemoryStorage.pendingSync);
    });

    test('signing in shows guest items and the account items together, '
        'in one list (PD-020)', () async {
      final guest = await saveAs(null, 'guest item');
      final mine = await saveAs('user-a', 'my item');
      final theirs = await saveAs('user-b', 'their item');

      signedIn = 'user-a';
      expect((await accountRepo.watch().first).map((r) => r.id).toSet(),
          <String>{guest, mine});
      expect((await accountRepo.findById(theirs)).failureOrNull,
          isA<NotFoundFailure>());

      signedIn = null;
      expect((await accountRepo.watch().first).map((r) => r.id), <String>[
        guest,
      ]);
    });

    test('search never reaches another account', () async {
      await saveAs('user-b', 'rahsia orang lain');

      signedIn = 'user-a';
      expect(await accountRepo.watch(query: 'rahsia').first, isEmpty);
    });

    test('a guest item is deleted outright', () async {
      final id = await saveAs(null, 'guest');

      expect((await accountRepo.delete(id)).isOk, isTrue);
      expect(await db.select(db.memories).get(), isEmpty);
    });

    test('an account item becomes a hidden, pending tombstone (PD-021)',
        () async {
      final id = await saveAs('user-a', 'account 012-3456789');
      await db.customStatement(
        "UPDATE memories SET sync_status = 'synced', server_updated_at = 5 "
        'WHERE id = ?',
        <Object?>[id],
      );

      expect((await accountRepo.delete(id)).isOk, isTrue);

      final row = await rowOf(id);
      expect(row.deletedAt, isNotNull);
      expect(row.syncStatus, 'pending');
      expect(await accountRepo.watch().first, isEmpty);
      expect(await accountRepo.watch(query: '3456789').first, isEmpty);
      expect((await accountRepo.findById(id)).failureOrNull,
          isA<NotFoundFailure>());
    });

    test('an account item not yet pushed is still tombstoned, because its '
        'push may be in flight', () async {
      final id = await saveAs('user-a', 'offline save');

      expect((await accountRepo.delete(id)).isOk, isTrue);
      expect((await rowOf(id)).deletedAt, isNotNull);
    });

    test('another account\'s item cannot be deleted', () async {
      final id = await saveAs('user-b', 'theirs');

      signedIn = 'user-a';
      expect((await accountRepo.delete(id)).failureOrNull,
          isA<NotFoundFailure>());
      expect((await rowOf(id)).deletedAt, isNull);
    });
  });

  group('persistence', () {
    test('memories survive closing and reopening the database', () async {
      configureSqliteForTests();
      final dir = await Directory.systemTemp.createTemp('tindak_m5a_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/tindak.sqlite');

      final first = TindakDatabase(NativeDatabase(file));
      final id = await DriftMemoryRepository(first, clock: clock).save(
        incoming: shared('Hubungi 012-3456789'),
        understanding: engine.understand('Hubungi 012-3456789'),
      );
      await first.close();

      final reopened = TindakDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final records =
          await DriftMemoryRepository(reopened, clock: clock).watch().first;

      expect(records.single.id, id.valueOrNull);
      expect(records.single.content, 'Hubungi 012-3456789');
      expect(records.single.entities.single.normalizedValue, '+60123456789');
    });
  });

  group('privacy', () {
    test('a failure logs no saved text', () async {
      final logged = <String>[];
      AppLogger.testSink = (name, message) => logged.add(message);
      addTearDown(() => AppLogger.testSink = null);

      await breakDatabase();
      await repo.save(
        incoming: shared('RAHSIA peribadi 012-3456789'),
        understanding: engine.understand('RAHSIA peribadi 012-3456789'),
      );

      expect(logged, isNotEmpty);
      for (final line in logged) {
        expect(line, isNot(contains('RAHSIA')));
        expect(line, isNot(contains('3456789')));
      }
    });

    test('a record prints no content', () async {
      final id = await save(shared('RAHSIA 012-3456789'));
      final record = (await repo.findById(id)).valueOrNull!;

      expect(record.toString(), isNot(contains('RAHSIA')));
      expect(record.toString(), isNot(contains('3456789')));
    });
  });
}

/// A clock that moves forward a second each time it is read, so saves get
/// distinct, ordered timestamps.
final class _SteppingClock implements Clock {
  _SteppingClock(this._next);

  DateTime _next;

  @override
  DateTime now() {
    final current = _next;
    _next = _next.add(const Duration(seconds: 1));
    return current;
  }

  @override
  DateTime today() => DateTime(_next.year, _next.month, _next.day);
}
