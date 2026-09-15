import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/test_database.dart';

/// The first real migration: schema 1 (M5a) to 2 (M5b).
///
/// Each test builds a genuine version 1 database file from the frozen DDL in
/// fixtures/schema_v1.sql — the shape a phone running M5a actually has — fills
/// it with rows the M5a code would have written, then opens it with the current
/// code and checks nothing was lost.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    configureSqliteForTests();
    dir = await Directory.systemTemp.createTemp('tindak_migration_');
    file = File('${dir.path}/tindak.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  const guestId = '11111111-1111-4111-8111-111111111111';
  const plainId = '22222222-2222-4222-8222-222222222222';

  /// Writes a version 1 database exactly as M5a left it.
  void createVersion1Database() {
    final ddl = File('test/core/database/fixtures/schema_v1.sql')
        .readAsStringSync();
    final db = raw.sqlite3.open(file.path);
    try {
      db.execute(ddl);
      db.execute(
        'INSERT INTO memories (id, content, intake_source, source_app, '
        'created_at, updated_at, deleted_at, owner_user_id, sync_status) '
        'VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?)',
        <Object?>[
          guestId,
          'Hubungi 012-345 6789',
          'share',
          'com.android.chrome',
          1757900000000,
          1757900000000,
          'local_only',
        ],
      );
      db.execute(
        'INSERT INTO memory_entities (id, memory_id, type, raw_value, '
        'normalized_value, search_value, confidence, start_offset, end_offset, '
        'created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          '33333333-3333-4333-8333-333333333333',
          guestId,
          'phone',
          '012-345 6789',
          '+60123456789',
          '0123456789 60123456789',
          0.95,
          8,
          20,
          1757900000000,
        ],
      );
      db.execute(
        'INSERT INTO memories (id, content, intake_source, source_app, '
        'created_at, updated_at, deleted_at, owner_user_id, sync_status) '
        'VALUES (?, ?, ?, NULL, ?, ?, NULL, NULL, ?)',
        <Object?>[
          plainId,
          'Beli susu 😀',
          'paste',
          1757900001000,
          1757900001000,
          'local_only',
        ],
      );
      expect(db.userVersion, 1);
    } finally {
      db.dispose();
    }
  }

  Future<List<String>> columnsOf(TindakDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  test('the fixture really is version 1', () {
    createVersion1Database();

    final db = raw.sqlite3.open(file.path);
    addTearDown(db.dispose);
    final columns = db
        .select('PRAGMA table_info(memories)')
        .map((r) => r['name'] as String)
        .toList();

    expect(db.userVersion, 1);
    expect(columns, isNot(contains('server_updated_at')));
  });

  test('upgrades to version 2: server_updated_at and sync_meta', () async {
    createVersion1Database();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await columnsOf(db, 'memories'), contains('server_updated_at'));
    expect(await columnsOf(db, 'sync_meta'), <String>['key', 'value']);
    expect(await db.select(db.syncMeta).get(), isEmpty);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
  });

  test('every existing row survives with every value', () async {
    createVersion1Database();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await (db.select(db.memories)
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();

    expect(rows.map((r) => r.id), <String>[guestId, plainId]);
    expect(rows.first.content, 'Hubungi 012-345 6789');
    expect(rows.first.intakeSource, 'share');
    expect(rows.first.sourceApp, 'com.android.chrome');
    expect(rows.first.createdAt, 1757900000000);
    expect(rows.first.ownerUserId, isNull);
    expect(rows.first.syncStatus, 'local_only');
    expect(rows.last.content, 'Beli susu 😀');

    final entities = await db.select(db.memoryEntities).get();
    expect(entities.single.normalizedValue, '+60123456789');
    expect(entities.single.searchValue, '0123456789 60123456789');
  });

  test('every M5a row is marked as never seen by the server', () async {
    createVersion1Database();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db.select(db.memories).get();
    expect(rows.map((r) => r.serverUpdatedAt), everyElement(isNull));
  });

  test('upgraded data is fully usable through the repository', () async {
    createVersion1Database();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final repo = DriftMemoryRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 9, 15)),
    );

    final records = await repo.watch().first;
    expect(records, hasLength(2));

    final found = await repo.watch(query: '0123456789').first;
    expect(found.single.id, guestId);
    expect(found.single.entities.single.type, EntityType.phone);

    expect((await repo.delete(plainId)).isOk, isTrue);
    expect(await repo.watch().first, hasLength(1));
  });

  test('every version 1 constraint still holds after the upgrade', () async {
    createVersion1Database();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    Future<void> insert({
      required String syncStatus,
      String content = 'x',
      String? owner,
    }) => db.customStatement(
      'INSERT INTO memories (id, content, intake_source, created_at, '
      'updated_at, owner_user_id, sync_status) VALUES (?, ?, ?, 1, 1, ?, ?)',
      <Object?>[
        '44444444-4444-4444-8444-444444444444',
        content,
        'share',
        owner,
        syncStatus,
      ],
    );

    await expectLater(insert(syncStatus: 'synced'), throwsA(isA<Exception>()));
    await expectLater(
      insert(syncStatus: 'local_only', content: 'a' * 10001),
      throwsA(isA<Exception>()),
    );

    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
  });

  test('the upgrade runs once — reopening does not migrate again', () async {
    createVersion1Database();

    final first = TindakDatabase(NativeDatabase(file));
    await first.select(first.memories).get();
    await first.close();

    final second = TindakDatabase(NativeDatabase(file));
    addTearDown(second.close);

    expect(await second.select(second.memories).get(), hasLength(2));
  });

  test('a database from a newer build is refused, not guessed at', () async {
    createVersion1Database();
    final future = raw.sqlite3.open(file.path)
      ..execute('PRAGMA user_version = 99');
    future.dispose();

    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    await expectLater(db.select(db.memories).get(), throwsA(anything));
  });

  test('a fresh install creates version 2 directly', () async {
    final db = TindakDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await columnsOf(db, 'memories'), contains('server_updated_at'));
    expect(await columnsOf(db, 'sync_meta'), <String>['key', 'value']);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
  });
}
