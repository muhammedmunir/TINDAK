import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/sync/data/cloud_memory_api.dart';
import 'package:tindak/features/sync/data/sync_store.dart';
import 'package:tindak/features/sync/sync_engine.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

const String userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late TindakDatabase db;
  late FakeCloud cloud;
  late SyncStore store;
  late SyncEngine engine;
  late DriftMemoryRepository repo;
  late DriftReminderRepository reminders;
  late _MutableClock clock;
  String? signedIn;
  const understanding = UnderstandingEngine();

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    cloud = FakeCloud()..sessionUser = userA;
    clock = _MutableClock(DateTime.utc(2026, 9, 15, 10));
    signedIn = userA;
    store = SyncStore(db);
    engine = SyncEngine(store: store, api: cloud, clock: clock);
    repo = DriftMemoryRepository(
      db,
      clock: clock,
      currentUserId: () => signedIn,
    );
    reminders = DriftReminderRepository(db, clock: clock, memories: repo);
  });

  Future<String> save(String text, {String? as = userA}) async {
    signedIn = as;
    final id = (await repo.save(
      incoming: IncomingText.pasted(text, at: clock.now()),
      understanding: understanding.understand(text),
    )).valueOrNull!;
    signedIn = userA;
    return id;
  }

  Future<MemoryRow?> rowOf(String id) => (db.select(
    db.memories,
  )..where((m) => m.id.equals(id))).getSingleOrNull();

  CloudMemory remote(String id, String text, {List<CloudEntity>? entities}) =>
      CloudMemory(
        id: id,
        content: text,
        intakeSource: 'share',
        createdAt: DateTime.utc(2026, 9, 14),
        entities: entities ?? const <CloudEntity>[],
      );

  group('push', () {
    test('a signed-in save reaches the cloud with its entities, and is then '
        'marked synced', () async {
      final id = await save('Hubungi 012-345 6789');

      expect(await engine.sync(userA), SyncResult.upToDate);

      expect(cloud.rows[id]!.userId, userA);
      expect(cloud.rows[id]!.memory.content, 'Hubungi 012-345 6789');
      expect(cloud.rows[id]!.memory.entities.single.normalizedValue,
          '+60123456789');
      final row = (await rowOf(id))!;
      expect(row.syncStatus, 'synced');
      expect(row.serverUpdatedAt,
          cloud.rows[id]!.updatedAt.millisecondsSinceEpoch);
    });

    test('offline: the save stays on the device, pending, and syncs on the '
        'next trigger (PD-042)', () async {
      cloud.offline = true;
      final id = await save('offline save');

      expect(await engine.sync(userA), SyncResult.offline);
      expect((await rowOf(id))!.syncStatus, 'pending');
      expect(await store.pendingCount(userA), 1);

      cloud.offline = false;
      expect(await engine.sync(userA), SyncResult.upToDate);
      expect((await rowOf(id))!.syncStatus, 'synced');
      expect(await store.pendingCount(userA), 0);
    });

    test('a lost reply is retried without duplicating anything', () async {
      final id = await save('reply lost');
      cloud.duringPush = (_) async => cloud.offline = true;

      expect(await engine.sync(userA), SyncResult.offline);
      expect(cloud.rows, hasLength(1));
      expect((await rowOf(id))!.syncStatus, 'pending');

      cloud
        ..duringPush = null
        ..offline = false;
      expect(await engine.sync(userA), SyncResult.upToDate);
      expect(cloud.rows, hasLength(1));
      expect((await rowOf(id))!.syncStatus, 'synced');
    });

    test('guest items are never uploaded by sync (PD-016)', () async {
      final guest = await save('guest item', as: null);
      await save('account item');

      await engine.sync(userA);

      expect(cloud.rows.containsKey(guest), isFalse);
      expect((await rowOf(guest))!.ownerUserId, isNull);
      expect((await rowOf(guest))!.syncStatus, 'local_only');
    });

    test('guest items are uploaded only after explicit migration '
        '(PD-044)', () async {
      final guest = await save('guest item', as: null);

      expect(await store.migrateGuestRows(userA), 1);
      await engine.sync(userA);

      expect(cloud.rows[guest]!.userId, userA);
      expect((await rowOf(guest))!.ownerUserId, userA);
      expect((await rowOf(guest))!.syncStatus, 'synced');
      expect(await store.guestCount(), 0);
    });

    test('a refused change stays pending and does not block the others',
        () async {
      final bad = await save('refused');
      final good = await save('accepted');
      cloud.rejectIds.add(bad);

      expect(await engine.sync(userA), SyncResult.failed);

      expect((await rowOf(bad))!.syncStatus, 'pending');
      expect((await rowOf(good))!.syncStatus, 'synced');
    });

    test('nothing is written when the session belongs to someone else',
        () async {
      await save('mine');
      cloud.sessionUser = userB;

      expect(await engine.sync(userA), SyncResult.sessionEnded);
      expect(cloud.rows, isEmpty);
      expect(await store.pendingCount(userA), 1);
    });
  });

  group('delete', () {
    test('deleting a synced item tombstones it in the cloud, then removes it '
        'here', () async {
      final id = await save('to delete');
      await engine.sync(userA);

      await repo.delete(id);
      expect(await engine.sync(userA), SyncResult.upToDate);

      expect(cloud.isDeleted(id), isTrue);
      expect(await rowOf(id), isNull);
    });

    test('an item deleted before it was ever pushed is never uploaded',
        () async {
      final id = await save('RAHSIA never sent');
      await repo.delete(id);

      expect(await engine.sync(userA), SyncResult.upToDate);

      expect(cloud.rows.containsKey(id), isFalse);
      expect(await rowOf(id), isNull);
    });

    test('offline: the deletion waits and is sent later', () async {
      final id = await save('delete offline');
      await engine.sync(userA);
      cloud.offline = true;

      await repo.delete(id);
      expect(await engine.sync(userA), SyncResult.offline);
      expect(await repo.watch().first, isEmpty);
      expect((await rowOf(id))!.deletedAt, isNotNull);

      cloud.offline = false;
      await engine.sync(userA);
      expect(cloud.isDeleted(id), isTrue);
      expect(await rowOf(id), isNull);
    });

    test('a delete that races an in-flight push is not undone by the next '
        'pull', () async {
      final id = await save('racing');
      cloud.duringPush = (_) async {
        await repo.delete(id);
      };

      await engine.sync(userA);
      cloud.duringPush = null;
      await engine.sync(userA);
      await engine.sync(userA);

      expect(cloud.isDeleted(id), isTrue);
      expect(await rowOf(id), isNull);
      expect(await repo.watch().first, isEmpty);
    });
  });

  group('pull', () {
    test('an item saved on another device appears, searchable by phone',
        () async {
      cloud.insertDirect(
        userA,
        remote(
          'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'Hubungi 012-345 6789',
          entities: const <CloudEntity>[
            CloudEntity(
              id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
              type: 'phone',
              rawValue: '012-345 6789',
              normalizedValue: '+60123456789',
              confidence: 0.95,
              start: 8,
              end: 20,
            ),
          ],
        ),
      );

      expect(await engine.sync(userA), SyncResult.upToDate);

      final found = await repo.watch(query: '0123456789').first;
      expect(found.single.content, 'Hubungi 012-345 6789');
      expect(found.single.entities.single.normalizedValue, '+60123456789');
      final row = (await rowOf(found.single.id))!;
      expect(row.ownerUserId, userA);
      expect(row.syncStatus, 'synced');
    });

    test('another account\'s cloud items never arrive', () async {
      cloud.insertDirect(
        userB,
        remote('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'bukan milik A'),
      );

      await engine.sync(userA);

      expect(await db.select(db.memories).get(), isEmpty);
    });

    test('a deletion made on another device removes the item here', () async {
      final id = await save('deleted elsewhere');
      await engine.sync(userA);

      cloud.tombstoneDirect(id);
      await engine.sync(userA);

      expect(await rowOf(id), isNull);
    });

    test('a local deletion is never undone by a pulled live copy', () async {
      final id = await save('deleted here');
      await engine.sync(userA);
      cloud.offline = true;
      await repo.delete(id);
      cloud.offline = false;

      // Pull only, as if push had failed for this row.
      await store.applyPulled(userA, <CloudMemory>[cloud.rows[id]!.asCloud()]);

      expect((await rowOf(id))!.deletedAt, isNotNull);
      expect(await repo.watch().first, isEmpty);
    });

    test('pages through many changes and remembers where it stopped',
        () async {
      final paged = SyncEngine(
        store: store,
        api: cloud,
        clock: clock,
        pageSize: 2,
      );
      for (var i = 0; i < 5; i++) {
        cloud.advance(const Duration(seconds: 2));
        cloud.insertDirect(
          userA,
          remote('0000000$i-0000-4000-8000-000000000000', 'item $i'),
        );
      }

      await paged.sync(userA);
      expect(await repo.watch().first, hasLength(5));
      expect(await store.cursor(userA), isNotNull);

      final before = cloud.pulledRows;
      cloud.advance(const Duration(seconds: 2));
      cloud.insertDirect(
        userA,
        remote('00000009-0000-4000-8000-000000000000', 'new item'),
      );
      await paged.sync(userA);

      expect(await repo.watch().first, hasLength(6));
      // The one-second overlap re-reads the last change; everything older is
      // not read again.
      expect(cloud.pulledRows - before, 2);
    });

    test('the cursor survives a restart, stored as text with microseconds',
        () async {
      final cursor = SyncCursor(
        DateTime.utc(2026, 9, 15, 10, 0, 0, 123, 456),
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
      );
      await store.saveCursor(userA, cursor);

      final read = (await store.cursor(userA))!;
      expect(read.updatedAt, cursor.updatedAt);
      expect(read.id, cursor.id);
    });

    test('after longer than the purge window, synced items are pulled again '
        'in full, and unsent changes are kept', () async {
      final kept = await save('synced and still in cloud');
      final purged = await save('synced, purged from cloud');
      await engine.sync(userA);
      final unsent = await save('unsent');
      cloud
        ..rows.remove(purged)
        ..offline = true;
      await engine.sync(userA);
      cloud.offline = false;

      clock.value = clock.value.add(const Duration(days: 81));
      // Push first sends the unsent item; then the full pull runs.
      await engine.sync(userA);

      expect(await rowOf(kept), isNotNull);
      expect(await rowOf(purged), isNull);
      expect((await rowOf(unsent))!.syncStatus, 'synced');
    });

    // Regression: resetForFullPull deleted synced memories via cascade, which
    // silently destroyed any reminders attached to them. Reminders are
    // device-local (B-5) and have no cloud copy, so once lost they are gone
    // forever. The fix reads reminder rows before deletion, re-inserts them
    // after, and cancels the underlying alarm only for reminders whose memory
    // was never pulled back.
    test('a full re-pull preserves active reminders on synced memories',
        () async {
      // 1. Save and sync a memory so it is 'synced'.
      final memId = await save('Bayar bil TNB RM183.50');
      await engine.sync(userA);
      expect((await rowOf(memId))!.syncStatus, 'synced');

      // 2. Set a future reminder on that memory.
      final reminderResult = await reminders.create(
        memoryId: memId,
        at: LocalDateTime.parse('2027-01-01', '09:00')!,
      );
      expect(reminderResult.isOk, isTrue,
          reason: 'reminder setup precondition');
      expect(await reminders.active(), hasLength(1),
          reason: 'before full pull');

      // 3. Advance past the 80-day full-pull window and trigger a sync.
      cloud.offline = true;
      await engine.sync(userA); // offline — pending stays
      cloud.offline = false;
      clock.value = clock.value.add(const Duration(days: 81));
      await engine.sync(userA); // triggers resetForFullPull then re-pulls

      // 4. The memory comes back from the cloud; the reminder must survive.
      expect(await rowOf(memId), isNotNull,
          reason: 'memory pulled back from cloud');
      expect(
        await reminders.active(),
        hasLength(1),
        reason:
            'reminder must survive a full re-pull — it is device-local (B-5) '
            'and cannot be recovered from anywhere else',
      );
    });

    test('a full re-pull cancels reminders whose memory was purged from the '
        'cloud and not pulled back', () async {
      // 1. Save and sync a memory, then set a reminder.
      final memId = await save('Item yang akan dipadam dari cloud');
      await engine.sync(userA);
      await reminders.create(
        memoryId: memId,
        at: LocalDateTime.parse('2027-01-01', '09:00')!,
      );
      expect(await reminders.active(), hasLength(1));

      // 2. Server-side tombstone: cloud removes the row (90-day purge model).
      cloud.rows.remove(memId);

      // 3. Full pull after 81 days.
      clock.value = clock.value.add(const Duration(days: 81));
      await engine.sync(userA);

      // 4. Memory is gone and reminder is cancelled — no orphan alarm.
      expect(await rowOf(memId), isNull,
          reason: 'memory not pulled back — server has no copy');
      expect(await reminders.active(), isEmpty,
          reason:
              'reminder for a memory that no longer exists must be cancelled');
    });
  });

  group('EAR-FIX-01 — full pull durable staging and atomic commit', () {
    test('1. Internet cuts out before page 1: active memories and reminders untouched',
        () async {
      final memId = await save('Memori kekal sebelum pull');
      await engine.sync(userA);
      final r = (await reminders.create(
        memoryId: memId,
        at: LocalDateTime.parse('2027-01-01', '09:00')!,
      )).valueOrNull!;
      expect(await reminders.active(), hasLength(1));

      // Advance clock past 80 days to trigger full pull
      clock.value = clock.value.add(const Duration(days: 81));

      // Cloud offline before page 1
      cloud.offline = true;
      final result = await engine.sync(userA);
      expect(result, SyncResult.offline);

      // Database state verification:
      // Memory row must exist and still be 'synced'
      final memRow = await rowOf(memId);
      expect(memRow, isNotNull);
      expect(memRow!.syncStatus, 'synced');

      // Active reminder must be 100% intact
      final activeReminders = await reminders.active();
      expect(activeReminders, hasLength(1));
      expect(activeReminders.single.id, r.id);
      expect(activeReminders.single.memoryId, memId);
      expect(activeReminders.single.notificationId, r.notificationId);

      // Staging meta should not be marked complete
      final metaStr = await db.customSelect(
        "SELECT value FROM sync_meta WHERE key LIKE 'stage:$userA:%:meta'",
      ).getSingleOrNull();
      if (metaStr != null) {
        expect(metaStr.read<String>('value'), contains('"complete":false'));
      }
    });

    test('2. Failure on page 2: partial pull does not replace active dataset',
        () async {
      final pagedEngine = SyncEngine(
        store: store,
        api: cloud,
        clock: clock,
        pageSize: 1, // 1 item per page forces page 1, page 2
      );

      final mem1 = await save('Memori Halaman 1');
      final mem2 = await save('Memori Halaman 2');
      await engine.sync(userA);

      final r1 = (await reminders.create(
        memoryId: mem1,
        at: LocalDateTime.parse('2027-01-01', '09:00')!,
      )).valueOrNull!;
      final r2 = (await reminders.create(
        memoryId: mem2,
        at: LocalDateTime.parse('2027-02-01', '09:00')!,
      )).valueOrNull!;
      expect(await reminders.active(), hasLength(2));

      final cursorBefore = await store.cursor(userA);
      expect(cursorBefore, isNotNull);

      // Advance clock past 80 days
      clock.value = clock.value.add(const Duration(days: 81));

      // Reset relative failure counter immediately before full pull
      cloud.resetPageFailure();
      // Fail on pull request #2 of THIS full pull — proves page 1 succeeded first!
      cloud.fullPullFailOnPage = 2;
      final result = await pagedEngine.sync(userA);
      expect(result, SyncResult.offline);

      // Verify that page 1 DID arrive and was staged before page 2 failed:
      final stagedPage0 = await db.customSelect(
        "SELECT value FROM sync_meta WHERE key LIKE 'stage:$userA:%:page:0'",
      ).getSingleOrNull();
      expect(stagedPage0, isNotNull,
          reason: 'Page 1 was successfully fetched and staged before failure');
      expect(stagedPage0!.read<String>('value'), contains('Memori Halaman'),
          reason: 'Staged page contains valid memory data from cloud');

      // Active dataset must NOT be in a partial state:
      // Both memories still exist locally in active table
      expect(await rowOf(mem1), isNotNull);
      expect(await rowOf(mem2), isNotNull);

      // Both reminders still exist locally
      final active = await reminders.active();
      expect(active, hasLength(2));
      expect(active.map((x) => x.id).toSet(), <String>{r1.id, r2.id});

      // Cursor was not updated to page 1's position
      final cursorAfter = await store.cursor(userA);
      expect(cursorAfter?.encode(), cursorBefore!.encode());
    });

    test('3. Process interruption / recovery: file-backed SQLite close/reopen test',
        () async {
      // Create a temporary file-based SQLite database to prove durable
      // persistence across true connection close and reopen
      final tempDir = Directory.systemTemp.createTempSync('tindak_reopen_test_');
      final dbFile = File('${tempDir.path}/tindak_test.sqlite');
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      // 1. Open first database connection
      var fileDb = TindakDatabase(NativeDatabase(dbFile));
      var fileRepo = DriftMemoryRepository(fileDb, clock: clock, currentUserId: () => userA);
      var fileReminders = DriftReminderRepository(fileDb, clock: clock, memories: fileRepo);
      var fileStore = SyncStore(fileDb);

      // Save a valid active memory and set a reminder
      final memResult = await fileRepo.save(
        incoming: IncomingText.pasted('Memori sah kekal', at: clock.now()),
        understanding: understanding.understand('Memori sah kekal'),
      );
      final memId = memResult.valueOrNull!;
      await fileDb.customStatement(
        "UPDATE memories SET sync_status = 'synced', server_updated_at = 1 WHERE id = ?",
        <Object?>[memId],
      );
      final rActive = (await fileReminders.create(
        memoryId: memId,
        at: LocalDateTime.parse('2027-01-01', '09:00')!,
      )).valueOrNull!;

      // Put the memory into cloud so full pull reconciles it as surviving!
      cloud.insertDirect(
        userA,
        remote(memId, 'Memori sah kekal'),
      );

      // Simulate an uncommitted interrupted staging session containing garbage
      await fileStore.startFullPull(userA, 'crashed_attempt_888');
      await fileStore.stageFullPullPage(userA, 'crashed_attempt_888', 0, <CloudMemory>[
        remote('garbage-interrupted-id', 'Data sampah sesi tergendala'),
      ]);

      // 2. TRUE PROCESS SHUTDOWN: Close the database connection completely!
      await fileDb.close();

      // 3. REOPEN NEW PROCESS: Open a brand-new connection to the file
      fileDb = TindakDatabase(NativeDatabase(dbFile));
      addTearDown(fileDb.close);
      fileRepo = DriftMemoryRepository(fileDb, clock: clock, currentUserId: () => userA);
      fileReminders = DriftReminderRepository(fileDb, clock: clock, memories: fileRepo);
      fileStore = SyncStore(fileDb);

      // Verify that after reopen, the active dataset is 100% intact
      final memAfter = await (fileDb.select(fileDb.memories)..where((m) => m.id.equals(memId))).getSingleOrNull();
      expect(memAfter, isNotNull, reason: 'Active memory survived process shutdown');
      final remindersAfter = await fileReminders.active();
      expect(remindersAfter, hasLength(1));
      expect(remindersAfter.single.id, rActive.id);

      // Verify incomplete staging is present in persistent SQLite storage
      final countBeforeNewSync = await fileDb.customSelect(
        "SELECT COUNT(*) AS c FROM sync_meta WHERE key LIKE 'stage:$userA:%'",
      ).map((r) => r.read<int>('c')).getSingle();
      expect(countBeforeNewSync, greaterThan(0), reason: 'Staging was durably stored in SQLite file');

      // 4. Run full sync with newly reopened engine
      await fileStore.saveLastPullAt(userA, clock.now().subtract(const Duration(days: 90)));
      final fileEngine = SyncEngine(store: fileStore, api: cloud, clock: clock);
      clock.value = clock.value.add(const Duration(days: 81));
      final result = await fileEngine.sync(userA);
      expect(result, SyncResult.upToDate);

      // Verify staging was cleaned and active data remains completely valid
      final countAfterSync = await fileDb.customSelect(
        "SELECT COUNT(*) AS c FROM sync_meta WHERE key LIKE 'stage:$userA:%'",
      ).map((r) => r.read<int>('c')).getSingle();
      expect(countAfterSync, 0);

      final finalReminders = await fileReminders.active();
      expect(finalReminders, hasLength(1));
      expect(finalReminders.single.id, rActive.id);
    });

    test('4. Successful full pull: surviving memories keep reminders with same notification IDs',
        () async {
      final mem1 = await save('Memori 1 untuk pull berjaya');
      final mem2 = await save('Memori 2 untuk pull berjaya');
      await engine.sync(userA);

      final r1 = (await reminders.create(
        memoryId: mem1,
        at: LocalDateTime.parse('2027-03-01', '10:00')!,
      )).valueOrNull!;
      final r2 = (await reminders.create(
        memoryId: mem2,
        at: LocalDateTime.parse('2027-04-01', '14:00')!,
      )).valueOrNull!;

      // Full pull after 81 days
      clock.value = clock.value.add(const Duration(days: 81));
      final result = await engine.sync(userA);
      expect(result, SyncResult.upToDate);

      // Memories intact
      expect(await rowOf(mem1), isNotNull);
      expect(await rowOf(mem2), isNotNull);

      // Reminders intact with exact notification IDs and timestamps
      final active = await reminders.active();
      expect(active, hasLength(2));
      final active1 = active.singleWhere((x) => x.id == r1.id);
      final active2 = active.singleWhere((x) => x.id == r2.id);
      expect(active1.notificationId, r1.notificationId);
      expect(active2.notificationId, r2.notificationId);
      expect(active1.at.date, '2027-03-01');
      expect(active2.at.date, '2027-04-01');
    });

    test('5. Remote deletion: purged memory deleted and OS alarm cancelled',
        () async {
      final cancelledSchedulerAlarms = <int>[];
      final testEngine = SyncEngine(
        store: store,
        api: cloud,
        clock: clock,
        onAlarmsCancelled: (alarmIds) async {
          cancelledSchedulerAlarms.addAll(alarmIds);
        },
      );

      final keptId = await save('Memori kekal di cloud');
      final purgedId = await save('Memori akan dipurge dari cloud');
      await testEngine.sync(userA);

      final rKept = (await reminders.create(
        memoryId: keptId,
        at: LocalDateTime.parse('2027-05-01', '09:00')!,
      )).valueOrNull!;
      final rPurged = (await reminders.create(
        memoryId: purgedId,
        at: LocalDateTime.parse('2027-05-02', '09:00')!,
      )).valueOrNull!;

      expect(await reminders.active(), hasLength(2));

      // Cloud purges purgedId (server 90-day tombstone purge)
      cloud.rows.remove(purgedId);

      clock.value = clock.value.add(const Duration(days: 81));
      final result = await testEngine.sync(userA);
      expect(result, SyncResult.upToDate);

      // keptId survives with reminder
      expect(await rowOf(keptId), isNotNull);
      final active = await reminders.active();
      expect(active, hasLength(1));
      expect(active.single.memoryId, keptId);

      // purgedId is deleted and its reminder is gone from SQLite
      expect(await rowOf(purgedId), isNull);
      final allReminders = await (db.select(db.reminders)
            ..where((r) => r.id.equals(rPurged.id)))
          .get();
      expect(allReminders, isEmpty);

      // Scheduler OS-level verification:
      // The purged reminder's alarm ID must be in cancelledSchedulerAlarms!
      expect(cancelledSchedulerAlarms, contains(rPurged.notificationId),
          reason: 'Purged reminder alarm must be cancelled at the OS scheduler');
      // The kept reminder's alarm ID must NOT be cancelled!
      expect(cancelledSchedulerAlarms, isNot(contains(rKept.notificationId)),
          reason: 'Valid surviving reminder alarm must NOT be cancelled');
    });

    test('6. Pending local mutations are preserved across full pull',
        () async {
      final syncedId = await save('Memori yang sudah disync');
      await engine.sync(userA);

      // User creates a new memory locally while offline
      cloud.offline = true;
      final pendingId = await save('Memori baharu luar talian (pending)');
      expect((await rowOf(pendingId))!.syncStatus, 'pending');

      // Now advance clock past 80 days and go online
      clock.value = clock.value.add(const Duration(days: 81));
      cloud.offline = false;

      // Sync runs: push first sends the pending memory, full pull reconciles
      final result = await engine.sync(userA);
      expect(result, SyncResult.upToDate);

      // Both memories exist in local database
      expect(await rowOf(syncedId), isNotNull);
      final pendingRow = await rowOf(pendingId);
      expect(pendingRow, isNotNull);
      expect(pendingRow!.syncStatus, 'synced');
      expect(cloud.rows[pendingId], isNotNull);
    });

    test('7. Cursor integrity: cursor does not jump forward on sync failure',
        () async {
      final pagedEngine = SyncEngine(
        store: store,
        api: cloud,
        clock: clock,
        pageSize: 1,
      );

      await save('Item A');
      await save('Item B');
      await engine.sync(userA);

      final cursorBefore = await store.cursor(userA);
      expect(cursorBefore, isNotNull);

      // Advance clock past 80 days
      clock.value = clock.value.add(const Duration(days: 81));

      // Pull fails on page 2
      cloud.resetPageFailure();
      cloud.fullPullFailOnPage = 2;
      final result = await pagedEngine.sync(userA);
      expect(result, SyncResult.offline);

      // Cursor must remain unchanged
      final cursorAfter = await store.cursor(userA);
      expect(cursorAfter?.encode(), cursorBefore?.encode());

      // When network recovers, full pull succeeds and cursor updates
      cloud.fullPullFailOnPage = null;
      cloud.resetPageFailure();
      final retryResult = await pagedEngine.sync(userA);
      expect(retryResult, SyncResult.upToDate);
      final finalCursor = await store.cursor(userA);
      expect(finalCursor, isNotNull);
    });

    test('8. Multi-user staging isolation: User B attempt does not touch User A',
        () async {
      const memUserAId = 'aaaa0001-0000-4000-8000-000000000000';
      const memUserBId = 'bbbb0001-0000-4000-8000-000000000000';

      // User A stages incomplete data
      await store.startFullPull(userA, 'attempt_user_a');
      await store.stageFullPullPage(userA, 'attempt_user_a', 0, <CloudMemory>[
        remote(memUserAId, 'User A secret item'),
      ]);

      // User B runs a full pull
      cloud.sessionUser = userB;
      final userBMem = remote(memUserBId, 'User B item');
      cloud.insertDirect(userB, userBMem);

      // Advance clock for User B
      await store.saveLastPullAt(userB, clock.now().subtract(const Duration(days: 90)));
      final result = await engine.sync(userB);
      expect(result, SyncResult.upToDate);

      // User B has their memory synced
      expect(await rowOf(memUserBId), isNotNull);

      // User A staging was NOT committed or mixed into User B
      expect(await rowOf(memUserAId), isNull);

      // Clean staging for User A explicitly
      await store.cleanStaging(userA);
      final countA = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sync_meta WHERE key LIKE 'stage:$userA:%'",
      ).map((r) => r.read<int>('c')).getSingle();
      expect(countA, 0);
    });

    test('9. Sign-out staging cleanup: all JSON serialized content keys removed',
        () async {
      // 1. User A has synced data and an uncommitted staging session with private text
      await save('Memori Peribadi User A');
      await engine.sync(userA);

      await store.startFullPull(userA, 'attempt_private_123');
      await store.stageFullPullPage(userA, 'attempt_private_123', 0, <CloudMemory>[
        remote('private-staged-id', 'Teks rahsia dalam staging JSON'),
      ]);

      // User B also has staging keys
      await store.startFullPull(userB, 'attempt_user_b_456');
      await store.stageFullPullPage(userB, 'attempt_user_b_456', 0, <CloudMemory>[
        remote('user-b-id', 'Teks User B'),
      ]);

      // Verify User A staging exists in SQLite before sign-out
      final userAKeysBefore = await db.customSelect(
        "SELECT key, value FROM sync_meta WHERE key LIKE 'stage:$userA:%'",
      ).get();
      expect(userAKeysBefore, isNotEmpty);
      expect(userAKeysBefore.any((r) => r.read<String>('value').contains('Teks rahsia')), isTrue);

      // 2. User A signs out through the real purgeAccountIfSafe path
      final purgeResult = await store.purgeAccountIfSafe(userA);
      expect(purgeResult.purged, isTrue);

      // 3. Verify ALL User A staging keys and JSON contents are completely deleted!
      final userAKeysAfter = await db.customSelect(
        "SELECT key, value FROM sync_meta WHERE key LIKE 'stage:$userA:%'",
      ).get();
      expect(userAKeysAfter, isEmpty,
          reason: 'All staging keys and JSON content for User A must be purged on sign-out');

      // 4. Verify User B staging keys were NOT touched or deleted!
      final userBKeysAfter = await db.customSelect(
        "SELECT key FROM sync_meta WHERE key LIKE 'stage:$userB:%'",
      ).get();
      expect(userBKeysAfter, isNotEmpty,
          reason: 'User B staging keys must remain completely unaffected');

      // Clean up User B
      await store.cleanStaging(userB);
    });

    test('10. PD-055: onAlarmsCancelled failure logs error without content and keeps sync successful',
        () async {
      final logged = <String>[];
      AppLogger.testSink = (name, message) => logged.add('$name:$message');
      addTearDown(() => AppLogger.testSink = null);

      final receivedAlarmIds = <int>[];
      final failingAlarmEngine = SyncEngine(
        store: store,
        api: cloud,
        clock: clock,
        onAlarmsCancelled: (alarmIds) async {
          receivedAlarmIds.addAll(alarmIds);
          throw StateError('OS alarm scheduler failed for RAHSIA_TOKEN');
        },
      );

      final keptId = await save('Memori sah RAHSIA kekal');
      final purgedId = await save('Memori RAHSIA dipurge dari cloud');
      await failingAlarmEngine.sync(userA);

      final rKept = (await reminders.create(
        memoryId: keptId,
        at: LocalDateTime.parse('2027-06-01', '09:00')!,
      )).valueOrNull!;
      final rPurged = (await reminders.create(
        memoryId: purgedId,
        at: LocalDateTime.parse('2027-06-02', '09:00')!,
      )).valueOrNull!;

      // Add a newer remote memory so cursor movement can be verified
      const newRemoteId = 'cccc0001-0000-4000-8000-000000000000';
      final cursorBefore = await store.cursor(userA);
      expect(cursorBefore, isNotNull);

      // Cloud purges purgedId and adds a newer memory
      cloud.rows.remove(purgedId);
      clock.value = clock.value.add(const Duration(days: 81));
      final expectedPullTime = clock.now().toUtc();
      cloud.insertDirect(
        userA,
        remote(newRemoteId, 'Memori baharu dari cloud'),
      );
      final expectedRemoteUpdatedAt = cloud.rows[newRemoteId]!.updatedAt;

      logged.clear();
      final result = await failingAlarmEngine.sync(userA);

      // 1. Sync still completes as upToDate (success, not failed)
      expect(result, SyncResult.upToDate);

      // 2. Only the deleted/purged reminder alarm was passed to onAlarmsCancelled;
      //    valid surviving reminder alarm was NOT passed.
      expect(receivedAlarmIds, <int>[rPurged.notificationId]);
      expect(receivedAlarmIds, isNot(contains(rKept.notificationId)));

      // 3. Committed dataset, surviving reminder, cursor, and lastPullAt remain intact
      expect(await rowOf(keptId), isNotNull);
      expect(await rowOf(newRemoteId), isNotNull);
      expect(await rowOf(purgedId), isNull);

      final activeReminders = await reminders.active();
      expect(activeReminders, hasLength(1));
      expect(activeReminders.single.id, rKept.id);
      expect(activeReminders.single.notificationId, rKept.notificationId);

      final cursorAfter = await store.cursor(userA);
      expect(cursorAfter, isNotNull);
      expect(cursorAfter!.id, newRemoteId);
      expect(cursorAfter.updatedAt, expectedRemoteUpdatedAt);
      expect(await store.lastPullAt(userA), expectedPullTime);

      // 4. Error was logged with safe diagnostic code and no user content or sensitive text
      expect(
        logged.any((line) => line.contains('sync_alarm_cancel_failed_StateError')),
        isTrue,
      );
      for (final line in logged) {
        expect(line, isNot(contains('RAHSIA')));
        expect(line, isNot(contains('Memori')));
      }
    });
  });

  group('runs', () {
    test('requests during a run are served by one more run, not many',
        () async {
      await save('first');
      final followUps = <Future<SyncResult>>[];
      cloud.duringPush = (_) async {
        // Three requests while the first run is still pushing.
        followUps
          ..add(engine.sync(userA))
          ..add(engine.sync(userA))
          ..add(engine.sync(userA));
      };

      await engine.sync(userA);
      cloud.duringPush = null;
      await Future.wait(followUps);

      expect(identical(followUps[0], followUps[1]), isTrue);
      expect(identical(followUps[1], followUps[2]), isTrue);
      // The first run and exactly one follow-up.
      expect(cloud.pullRequests, 2);
    });

    test('sync failures log no content', () async {
      final logged = <String>[];
      AppLogger.testSink = (name, message) => logged.add(message);
      addTearDown(() => AppLogger.testSink = null);

      final id = await save('RAHSIA 012-3456789');
      cloud.rejectIds.add(id);
      await engine.sync(userA);
      cloud.sessionUser = userB;
      await engine.sync(userA);

      expect(logged, isNotEmpty);
      for (final line in logged) {
        expect(line, isNot(contains('RAHSIA')));
        expect(line, isNot(contains('3456789')));
      }
    });
  });

  group('sign-out purge — ADR-031', () {
    test('refuses while anything is pending, and deletes nothing', () async {
      await save('pending');
      final guest = await save('guest', as: null);

      expect((await store.purgeAccountIfSafe(userA)).purged, isFalse);
      expect(await db.select(db.memories).get(), hasLength(2));
      expect(await rowOf(guest), isNotNull);
    });

    test('once synced, removes the account rows and sync state, and keeps '
        'guest rows', () async {
      final mine = await save('mine');
      final guest = await save('guest', as: null);
      await engine.sync(userA);

      expect((await store.purgeAccountIfSafe(userA)).purged, isTrue);

      expect(await rowOf(mine), isNull);
      expect(await rowOf(guest), isNotNull);
      expect(await store.cursor(userA), isNull);
      expect(await store.lastPullAt(userA), isNull);
    });
  });
}

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  DateTime today() => DateTime(value.year, value.month, value.day);
}
