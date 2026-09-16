import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/database/tindak_database.dart';

import '../../support/test_database.dart';

/// The M5a schema checkpoint (docs/11_DATABASE.md section 3).
///
/// This is the first schema that holds a user's data. These tests pin its
/// exact shape so an accidental change shows up as a failure rather than as a
/// migration problem on a real phone. Each constraint is exercised directly
/// against SQLite, not through the repository, because the point is that the
/// database itself refuses bad data.
void main() {
  late TindakDatabase db;

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
  });

  Future<List<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  Future<void> insertMemory({
    String id = '11111111-1111-4111-8111-111111111111',
    String? owner,
    String syncStatus = 'local_only',
    String source = 'share',
    int created = 1000,
    int updated = 1000,
    int? deleted,
  }) => db.customStatement(
    'INSERT INTO memories (id, content, intake_source, source_app, '
    'created_at, updated_at, deleted_at, owner_user_id, sync_status) '
    'VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?)',
    <Object?>[id, 'x', source, created, updated, deleted, owner, syncStatus],
  );

  group('shape', () {
    test('schema version is 3', () {
      expect(db.schemaVersion, 3);
    });

    test('reminders has exactly the documented columns', () async {
      expect(await columnsOf('reminders'), <String>[
        'id',
        'memory_id',
        'owner_user_id',
        'local_date',
        'local_time',
        'time_zone',
        'remind_at',
        'scheduled_at',
        'status',
        'notification_id',
        'created_at',
        'updated_at',
      ]);
    });

    test('an unknown reminder status is refused', () async {
      await insertMemory();
      await expectLater(
        db.customStatement(
          'INSERT INTO reminders (id, memory_id, local_date, local_time, '
          'time_zone, remind_at, status, created_at, updated_at) VALUES '
          "('66666666-6666-4666-8666-666666666666', "
          "'11111111-1111-4111-8111-111111111111', '2026-12-25', '09:00', "
          "'X', 1, 'snoozed', 1, 1)",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting a memory deletes its reminders', () async {
      await insertMemory();
      await db.customStatement(
        'INSERT INTO reminders (id, memory_id, local_date, local_time, '
        'time_zone, remind_at, status, created_at, updated_at) VALUES '
        "('77777777-7777-4777-8777-777777777777', "
        "'11111111-1111-4111-8111-111111111111', '2026-12-25', '09:00', "
        "'X', 1, 'scheduled', 1, 1)",
      );

      await db.customStatement('DELETE FROM memories');

      expect(await db.select(db.reminders).get(), isEmpty);
    });

    test('memories has exactly the documented columns', () async {
      expect(await columnsOf('memories'), <String>[
        'id',
        'content',
        'intake_source',
        'source_app',
        'created_at',
        'updated_at',
        'deleted_at',
        'owner_user_id',
        'sync_status',
        'server_updated_at',
      ]);
    });

    test('sync_meta is a key/value table keyed by key', () async {
      expect(await columnsOf('sync_meta'), <String>['key', 'value']);
      await db.customStatement(
        "INSERT INTO sync_meta (key, value) VALUES ('pull_cursor:u', 'a')",
      );
      await expectLater(
        db.customStatement(
          "INSERT INTO sync_meta (key, value) VALUES ('pull_cursor:u', 'b')",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('memory_entities has exactly the documented columns', () async {
      expect(await columnsOf('memory_entities'), <String>[
        'id',
        'memory_id',
        'type',
        'raw_value',
        'normalized_value',
        'search_value',
        'confidence',
        'start_offset',
        'end_offset',
        'created_at',
      ]);
    });

    test('indexes exist', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get();

      expect(rows.map((r) => r.read<String>('name')), <String>[
        'memories_visible_created_idx',
        'memory_entities_memory_idx',
        'memory_entities_search_idx',
        'reminders_memory_idx',
        'reminders_one_active_per_memory',
        'reminders_remind_at_idx',
      ]);
    });

    test('foreign keys are enforced', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();

      expect(row.read<int>('foreign_keys'), 1);
    });
  });

  group('M5b readiness — verified now, used later', () {
    test('a guest row: no owner, local only', () async {
      await insertMemory();

      final row = await db.select(db.memories).getSingle();
      expect(row.ownerUserId, isNull);
      expect(row.syncStatus, 'local_only');
    });

    test('a future account row can carry an owner and be pending', () async {
      await insertMemory(owner: 'user-uuid', syncStatus: 'pending');

      expect(await db.select(db.memories).get(), hasLength(1));
    });

    test('a guest row can never claim to be synced (PD-016)', () async {
      await expectLater(
        insertMemory(syncStatus: 'synced'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertMemory(syncStatus: 'pending'),
        throwsA(isA<Exception>()),
      );
    });

    test('an unknown sync status is refused', () async {
      await expectLater(
        insertMemory(owner: 'u', syncStatus: 'uploaded'),
        throwsA(isA<Exception>()),
      );
    });

    test('an unknown intake source is refused', () async {
      await expectLater(
        insertMemory(source: 'clipboard_monitor'),
        throwsA(isA<Exception>()),
      );
    });

    test('ids must be UUID length', () async {
      await expectLater(insertMemory(id: '1'), throwsA(isA<Exception>()));
    });

    test('updated_at cannot precede created_at', () async {
      await expectLater(
        insertMemory(created: 2000, updated: 1000),
        throwsA(isA<Exception>()),
      );
    });

    test('a tombstone can be stored for future sync', () async {
      await insertMemory(owner: 'u', syncStatus: 'pending', deleted: 5000);

      final row = await db.select(db.memories).getSingle();
      expect(row.deletedAt, 5000);
    });
  });

  group('entities', () {
    Future<void> insertEntity({
      String memoryId = '11111111-1111-4111-8111-111111111111',
      double confidence = 0.9,
      int start = 0,
      int end = 5,
      String type = 'phone',
    }) => db.customStatement(
      'INSERT INTO memory_entities (id, memory_id, type, raw_value, '
      'normalized_value, search_value, confidence, start_offset, end_offset, '
      'created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        '22222222-2222-4222-8222-${DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}',
        memoryId,
        type,
        'r',
        'n',
        's',
        confidence,
        start,
        end,
        1000,
      ],
    );

    test('an entity must belong to an existing memory', () async {
      await expectLater(insertEntity(), throwsA(isA<Exception>()));
    });

    test('deleting a memory deletes its entities', () async {
      await insertMemory();
      await insertEntity();

      await db.customStatement('DELETE FROM memories');

      final left = await db.select(db.memoryEntities).get();
      expect(left, isEmpty);
    });

    test('confidence must be within [0, 1]', () async {
      await insertMemory();

      await expectLater(insertEntity(confidence: 1.5), throwsA(isA<Exception>()));
    });

    test('offsets must describe a real span', () async {
      await insertMemory();

      await expectLater(insertEntity(start: 5, end: 5), throwsA(isA<Exception>()));
    });

    test('type is not locked to today\'s entity kinds', () async {
      // M6 adds money and date without rebuilding the table.
      await insertMemory();

      await insertEntity(type: 'money');

      expect(await db.select(db.memoryEntities).get(), hasLength(1));
    });
  });
}
