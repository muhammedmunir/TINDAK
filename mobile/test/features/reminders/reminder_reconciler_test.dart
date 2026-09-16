import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_reconciler.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

import '../../support/test_database.dart';

/// The reconciler is how TINDAK survives everything it cannot control: a
/// schedule that failed, a reboot, a force stop, a time zone change, and a
/// reminder cancelled while the app was closed.
void main() {
  late TindakDatabase db;
  late DriftReminderRepository reminders;
  late DriftMemoryRepository memories;
  late _MovableClock clock;
  late _FakeScheduler scheduler;
  late ReminderReconciler reconciler;

  final start = DateTime(2026, 9, 16, 10);

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    clock = _MovableClock(start);
    scheduler = _FakeScheduler();
    memories = DriftMemoryRepository(db, clock: clock);
    reminders = DriftReminderRepository(db, clock: clock, memories: memories);
    reconciler = ReminderReconciler(
      repository: reminders,
      scheduler: scheduler,
      clock: clock,
    );
  });

  Future<String> saveMemory(String text) async {
    final result = await memories.save(
      incoming: IncomingText.pasted(text, at: clock.now()),
      understanding: UnderstandingEngine.withClock(clock).understand(text),
    );
    return result.valueOrNull!;
  }

  const tomorrow = LocalDateTime(
    year: 2026,
    month: 9,
    day: 17,
    hour: 9,
    minute: 0,
  );

  Future<ReminderRecord> newReminder({LocalDateTime at = tomorrow}) async {
    final memoryId = await saveMemory('Peringatan ujian');
    return (await reminders.create(memoryId: memoryId, at: at)).valueOrNull!;
  }

  group('repairing what the device is missing', () {
    test('a reminder with no alarm is scheduled', () async {
      final reminder = await newReminder();
      expect(scheduler.scheduled, isEmpty);

      final report = await reconciler.reconcile();

      expect(report.scheduled, 1);
      expect(scheduler.scheduled.keys, <int>[reminder.notificationId]);
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 9));
    });

    test('a schedule the platform refuses leaves the reminder, and is retried',
        () async {
      await newReminder();
      scheduler.accept = false;

      final first = await reconciler.reconcile();
      expect(first.failed, 1);
      expect(await reminders.active(), hasLength(1));

      scheduler.accept = true;
      final second = await reconciler.reconcile();
      expect(second.scheduled, 1);
    });

    test('after a reboot drops every alarm, all are restored', () async {
      final a = await newReminder();
      final b = (await reminders.create(
        memoryId: await saveMemory('Kedua'),
        at: const LocalDateTime(
          year: 2026,
          month: 9,
          day: 18,
          hour: 15,
          minute: 30,
        ),
      )).valueOrNull!;
      await reconciler.reconcile();

      scheduler.wipe(); // reboot, or a force stop that cleared the alarms

      final report = await reconciler.reconcile();

      expect(report.scheduled, 2);
      expect(scheduler.scheduled.keys, containsAll(<int>[
        a.notificationId,
        b.notificationId,
      ]));
    });
  });

  group('removing what should not fire', () {
    test('an alarm with no reminder behind it is cancelled', () async {
      scheduler.scheduled[4242] = DateTime(2026, 9, 20);

      final report = await reconciler.reconcile();

      expect(report.cancelled, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancelling while the app was closed removes the alarm', () async {
      final reminder = await newReminder();
      await reconciler.reconcile();

      await reminders.cancel(reminder.id);
      final report = await reconciler.reconcile();

      expect(report.cancelled, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('deleting the memory removes the alarm', () async {
      final memoryId = await saveMemory('Akan dipadam');
      await reminders.create(memoryId: memoryId, at: tomorrow);
      await reconciler.reconcile();

      await memories.delete(memoryId);
      final report = await reconciler.reconcile();

      expect(report.cancelled, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('signing out removes the account\'s alarms', () async {
      var user = 'user-a';
      final owned = DriftMemoryRepository(
        db,
        clock: clock,
        currentUserId: () => user,
      );
      final id = (await owned.save(
        incoming: IncomingText.pasted('Akaun', at: clock.now()),
        understanding: UnderstandingEngine.withClock(clock).understand('Akaun'),
      )).valueOrNull!;
      await reminders.create(memoryId: id, at: tomorrow);
      await reconciler.reconcile();
      expect(scheduler.scheduled, hasLength(1));

      await reminders.purgeAccount('user-a');
      user = '';
      final report = await reconciler.reconcile();

      expect(report.cancelled, 1);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('time passing', () {
    test('a reminder whose moment passed while the app was closed becomes '
        'history, and does not fire late', () async {
      final reminder = await newReminder();
      await reconciler.reconcile();

      clock.value = DateTime(2026, 9, 18, 8); // a day after it was due
      final report = await reconciler.reconcile();

      expect(report.fired, 1);
      expect(scheduler.scheduled, isEmpty);
      expect(await reminders.active(), isEmpty);
      final all = await reminders.watchFor(reminder.memoryId).first;
      expect(all.single.status, ReminderStatus.fired);
    });

    test('a reminder still ahead is left alone', () async {
      await newReminder();
      await reconciler.reconcile();

      clock.value = DateTime(2026, 9, 17, 8, 59);
      final report = await reconciler.reconcile();

      expect(report.fired, 0);
      expect(report.changedNothing, isTrue);
    });
  });

  group('time zone change (B-2)', () {
    test('the alarm follows the clock time the user chose', () async {
      final reminder = await newReminder();
      await reconciler.reconcile();
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 9));

      // The device moved zone. The alarm the OS holds was computed under the
      // old zone, so it now points an hour away from the 09:00 the user chose.
      await db.customStatement(
        'UPDATE reminders SET scheduled_at = ? WHERE id = ?',
        <Object?>[
          DateTime(2026, 9, 17, 10).millisecondsSinceEpoch,
          reminder.id,
        ],
      );

      final report = await reconciler.reconcile();

      expect(report.scheduled, 1);
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 9));
    });
  });

  group('idempotence and duplicates', () {
    test('running twice changes nothing the second time', () async {
      await newReminder();

      final first = await reconciler.reconcile();
      final second = await reconciler.reconcile();

      expect(first.scheduled, 1);
      expect(second.changedNothing, isTrue);
    });

    test('rescheduling replaces the alarm instead of adding one', () async {
      final reminder = await newReminder();
      await reconciler.reconcile();

      await reminders.replace(
        reminderId: reminder.id,
        at: const LocalDateTime(
          year: 2026,
          month: 9,
          day: 17,
          hour: 18,
          minute: 0,
        ),
      );
      await reconciler.reconcile();

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled[reminder.notificationId],
          DateTime(2026, 9, 17, 18));
      expect(scheduler.cancelled, isEmpty);
    });

    test('ten passes leave exactly one alarm', () async {
      await newReminder();

      for (var i = 0; i < 10; i++) {
        await reconciler.reconcile();
      }

      expect(scheduler.scheduled, hasLength(1));
    });
  });

  group('what the scheduler is told', () {
    test('only an id, an instant and the memory id — never content', () async {
      final memoryId = await saveMemory('RAHSIA 012-3456789 RM50');
      await reminders.create(memoryId: memoryId, at: tomorrow);

      await reconciler.reconcile();

      expect(scheduler.payloads.single, memoryId);
      for (final payload in scheduler.payloads) {
        expect(payload, isNot(contains('RAHSIA')));
        expect(payload, isNot(contains('3456789')));
      }
    });
  });
}

/// Stands in for Android's scheduler. Records what it was asked to do, and can
/// refuse or lose everything, the way a device does.
final class _FakeScheduler implements ReminderScheduler {
  final Map<int, DateTime> scheduled = <int, DateTime>{};
  final List<int> cancelled = <int>[];
  final List<String> payloads = <String>[];
  bool accept = true;

  void wipe() => scheduled.clear();

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
    if (!cancelled.contains(notificationId)) cancelled.add(notificationId);
  }

  @override
  Future<Set<int>> pending() async => scheduled.keys.toSet();
}

final class _MovableClock implements Clock {
  _MovableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  DateTime today() => DateTime(value.year, value.month, value.day);
}
