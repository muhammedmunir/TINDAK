import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/reminders/data/notification_permission.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_reconciler.dart';
import 'package:tindak/features/reminders/reminder_service.dart';
import 'package:tindak/features/sync/data/sync_store.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

import '../../support/test_database.dart';

/// The service is where permission, the database and the device scheduler meet
/// (M7b). The rules themselves are M7a; what matters here is the order of
/// those three, and that a refused permission never costs the user a reminder.
void main() {
  late TindakDatabase db;
  late DriftReminderRepository repository;
  late DriftMemoryRepository memories;
  late _FakeScheduler scheduler;
  late _FakePermission permission;
  late ReminderService service;
  late _MovableClock clock;

  final now = DateTime(2026, 9, 16, 10);
  const tomorrow = LocalDateTime(
    year: 2026,
    month: 9,
    day: 17,
    hour: 15,
    minute: 30,
  );

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    clock = _MovableClock(now);
    scheduler = _FakeScheduler();
    permission = _FakePermission();
    memories = DriftMemoryRepository(db, clock: clock);
    repository = DriftReminderRepository(
      db,
      clock: clock,
      memories: memories,
    );
    service = ReminderService(
      repository: repository,
      scheduler: scheduler,
      permission: permission,
      reconciler: ReminderReconciler(
        repository: repository,
        scheduler: scheduler,
        clock: clock,
      ),
    );
  });

  Future<String> saveMemory([String text = 'Bayar bil']) async {
    final result = await memories.save(
      incoming: IncomingText.pasted(text, at: clock.now()),
      understanding: UnderstandingEngine.withClock(clock).understand(text),
    );
    return result.valueOrNull!;
  }

  group('setting a reminder', () {
    test('commits it and schedules the alarm', () async {
      final memoryId = await saveMemory();

      final result = await service.set(memoryId: memoryId, at: tomorrow);

      expect(result.outcome, ReminderOutcome.set);
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.values.single, DateTime(2026, 9, 17, 15, 30));
      expect(await repository.activeFor(memoryId), isNotNull);
    });

    test('asks for permission in this flow, and only here', () async {
      final memoryId = await saveMemory();
      expect(permission.requests, 0);

      await service.set(memoryId: memoryId, at: tomorrow);

      expect(permission.requests, 1);
    });

    test('a refused permission still keeps the reminder (PD-026)', () async {
      permission.state = NotificationPermission.denied;
      final memoryId = await saveMemory();

      final result = await service.set(memoryId: memoryId, at: tomorrow);

      expect(result.outcome, ReminderOutcome.setWithoutNotifications);
      expect(result.isSet, isTrue);
      expect(await repository.activeFor(memoryId), isNotNull);
      // It is still scheduled: if notifications are switched back on, it works.
      expect(scheduler.scheduled, hasLength(1));
    });

    test('a past time is refused, and nothing is scheduled', () async {
      final memoryId = await saveMemory();

      final result = await service.set(
        memoryId: memoryId,
        at: LocalDateTime.from(now.subtract(const Duration(hours: 1))),
      );

      expect(result.outcome, ReminderOutcome.timeInPast);
      expect(scheduler.scheduled, isEmpty);
      expect(await repository.activeFor(memoryId), isNull);
    });

    test('a second reminder is reported as already existing', () async {
      final memoryId = await saveMemory();
      await service.set(memoryId: memoryId, at: tomorrow);

      final second = await service.set(
        memoryId: memoryId,
        at: const LocalDateTime(
          year: 2026,
          month: 9,
          day: 18,
          hour: 9,
          minute: 0,
        ),
      );

      expect(second.outcome, ReminderOutcome.alreadyExists);
      expect(scheduler.scheduled, hasLength(1));
    });

    test('a refused alarm does not discard the reminder', () async {
      scheduler.accept = false;
      final memoryId = await saveMemory();

      final result = await service.set(memoryId: memoryId, at: tomorrow);

      expect(result.isSet, isTrue);
      expect(await repository.activeFor(memoryId), isNotNull);

      // The reconciler picks it up once the platform accepts again.
      scheduler.accept = true;
      await service.reconcile();
      expect(scheduler.scheduled, hasLength(1));
    });
  });

  group('setting one on an unsaved result', () {
    test('saves the memory and the reminder together', () async {
      const text = 'Bayar bil TNB RM183.50 sebelum 25/09/2026';

      final result = await service.setOnUnsaved(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: UnderstandingEngine.withClock(clock).understand(text),
        at: tomorrow,
      );

      expect(result.outcome, ReminderOutcome.set);
      final saved = await memories.watch().first;
      expect(saved.single.content, text);
      expect(scheduler.scheduled, hasLength(1));
    });

    test('a past time saves neither', () async {
      const text = 'Tidak disimpan';

      final result = await service.setOnUnsaved(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: UnderstandingEngine.withClock(clock).understand(text),
        at: LocalDateTime.from(now.subtract(const Duration(days: 1))),
      );

      expect(result.outcome, ReminderOutcome.timeInPast);
      expect(await memories.watch().first, isEmpty);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('changing', () {
    test('reschedules to the new time, with no duplicate alarm', () async {
      final memoryId = await saveMemory();
      final set = await service.set(memoryId: memoryId, at: tomorrow);
      final reminder = set.reminder!;

      final changed = await service.change(
        reminderId: reminder.id,
        at: const LocalDateTime(
          year: 2026,
          month: 9,
          day: 17,
          hour: 20,
          minute: 0,
        ),
      );

      expect(changed.outcome, ReminderOutcome.set);
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 20));
    });

    test('a refused time leaves the original alarm in place', () async {
      final memoryId = await saveMemory();
      final reminder = (await service.set(
        memoryId: memoryId,
        at: tomorrow,
      )).reminder!;

      final refused = await service.change(
        reminderId: reminder.id,
        at: LocalDateTime.from(now.subtract(const Duration(minutes: 5))),
      );

      expect(refused.outcome, ReminderOutcome.timeInPast);
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 15, 30));
      expect((await repository.activeFor(memoryId))!.at.time, '15:30');
    });
  });

  group('cancelling and deleting', () {
    test('cancel removes the alarm at once, and keeps the memory', () async {
      final memoryId = await saveMemory();
      final reminder = (await service.set(
        memoryId: memoryId,
        at: tomorrow,
      )).reminder!;

      expect(await service.cancel(reminder), isTrue);

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, <int>[reminder.notificationId]);
      expect((await memories.findById(memoryId)).isOk, isTrue);
    });

    test('deleting a memory cancels its alarm', () async {
      final memoryId = await saveMemory();
      await service.set(memoryId: memoryId, at: tomorrow);

      // The alarm is cancelled first: a guest memory's reminder rows go with
      // it by cascade, taking the alarm id with them.
      await service.cancelForMemory(memoryId);
      await memories.delete(memoryId);

      expect(scheduler.scheduled, isEmpty);
    });

    test('an alarm left behind by a delete is cancelled at the next '
        'reconcile', () async {
      final memoryId = await saveMemory();
      await service.set(memoryId: memoryId, at: tomorrow);

      // The cancel-first path missed, for instance because the app was killed
      // between the two steps.
      await memories.delete(memoryId);
      await service.reconcile();

      expect(scheduler.scheduled, isEmpty);
    });

    test('signing out cancels the account\'s alarms', () async {
      var user = 'user-a';
      final owned = DriftMemoryRepository(
        db,
        clock: clock,
        currentUserId: () => user,
      );
      final memoryId = (await owned.save(
        incoming: IncomingText.pasted('Akaun', at: clock.now()),
        understanding: UnderstandingEngine.withClock(clock).understand('Akaun'),
      )).valueOrNull!;
      await service.set(memoryId: memoryId, at: tomorrow);
      user = '';

      await service.purgeAccount('user-a');

      expect(scheduler.scheduled, isEmpty);
      expect(await db.select(db.reminders).get(), isEmpty);
    });
  });

  group('sign-out purge', () {
    Future<String> accountMemory(String text) async {
      final owned = DriftMemoryRepository(
        db,
        clock: clock,
        currentUserId: () => 'user-a',
      );
      final result = await owned.save(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: UnderstandingEngine.withClock(clock).understand(text),
      );
      return result.valueOrNull!;
    }

    test('hands back the alarms its cascade removed', () async {
      // The purge deletes the account's memories, and their reminders go with
      // them by cascade — so the alarm ids must come back from the purge, or
      // nothing could cancel them and a reminder would fire after sign-out for
      // an item no longer on the device.
      final memoryId = await accountMemory('Akaun');
      final reminder = (await service.set(
        memoryId: memoryId,
        at: tomorrow,
      )).reminder!;
      await db.customStatement(
        "UPDATE memories SET sync_status = 'synced', server_updated_at = 5",
      );

      final purge = await SyncStore(db).purgeAccountIfSafe('user-a');
      await service.cancelAlarms(purge.cancelledAlarmIds);

      expect(purge.purged, isTrue);
      expect(purge.cancelledAlarmIds, <int>[reminder.notificationId]);
      expect(scheduler.scheduled, isEmpty);
      expect(await db.select(db.reminders).get(), isEmpty);
    });

    test('a refused purge cancels nothing and keeps everything', () async {
      final memoryId = await accountMemory('Belum disync');
      await service.set(memoryId: memoryId, at: tomorrow);

      // Still pending, so sign-out must change nothing at all (PD-041).
      final purge = await SyncStore(db).purgeAccountIfSafe('user-a');

      expect(purge.purged, isFalse);
      expect(purge.cancelledAlarmIds, isEmpty);
      expect(scheduler.scheduled, hasLength(1));
      expect(await db.select(db.reminders).get(), hasLength(1));
    });
  });

  group('what the device is told', () {
    test('only the memory id travels to the scheduler', () async {
      final memoryId = await saveMemory('RAHSIA 012-3456789 RM50');

      await service.set(memoryId: memoryId, at: tomorrow);

      expect(scheduler.payloads.single, memoryId);
      expect(scheduler.payloads.single, isNot(contains('RAHSIA')));
    });
  });

  group('permission state for the UI', () {
    test('reports off when notifications are refused', () async {
      permission.state = NotificationPermission.denied;

      expect(await service.permissionState(), ReminderPermissionState.off);
    });

    test('reports on when they are allowed or not needed', () async {
      permission.state = NotificationPermission.granted;
      expect(await service.permissionState(), ReminderPermissionState.on);

      permission.state = NotificationPermission.notRequired;
      expect(await service.permissionState(), ReminderPermissionState.on);
    });

    test('Buka Tetapan reaches the platform', () async {
      await service.openNotificationSettings();

      expect(permission.settingsOpened, 1);
    });
  });
}

final class _FakeScheduler implements ReminderScheduler {
  final Map<int, DateTime> scheduled = <int, DateTime>{};
  final List<int> cancelled = <int>[];
  final List<String> payloads = <String>[];
  bool accept = true;

  @override
  Future<bool> schedule({
    required int notificationId,
    required DateTime at,
    required String memoryId,
  }) async {
    if (!accept) return false;
    scheduled[notificationId] = at;
    payloads.add(memoryId);
    return true;
  }

  @override
  Future<void> cancel(int notificationId) async {
    scheduled.remove(notificationId);
    cancelled.add(notificationId);
  }

  @override
  Future<Set<int>> pending() async => scheduled.keys.toSet();
}

final class _FakePermission implements NotificationPermissionGateway {
  NotificationPermission state = NotificationPermission.granted;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<NotificationPermission> status() async => state;

  @override
  Future<NotificationPermission> request() async {
    requests++;
    return state;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

final class _MovableClock implements Clock {
  _MovableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  DateTime today() => DateTime(value.year, value.month, value.day);
}
