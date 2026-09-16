import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
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
