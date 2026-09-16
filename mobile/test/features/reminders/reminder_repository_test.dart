import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

import '../../support/test_database.dart';

/// Reminder rules (M7a). Everything here runs on the Dart VM with a pinned
/// clock and no scheduler: these are the rules that can lose a reminder, so
/// they are tested without an emulator in the way.
void main() {
  late TindakDatabase db;
  late DriftReminderRepository reminders;
  late DriftMemoryRepository memories;
  late _MovableClock clock;
  late UnderstandingEngine engine;
  String? signedIn;

  final now = DateTime(2026, 9, 16, 10);

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    clock = _MovableClock(now);
    signedIn = null;
    engine = UnderstandingEngine.withClock(clock);
    memories = DriftMemoryRepository(
      db,
      clock: clock,
      currentUserId: () => signedIn,
    );
    reminders = DriftReminderRepository(
      db,
      clock: clock,
      memories: memories,
    );
  });

  Future<String> saveMemory(String text) async {
    final result = await memories.save(
      incoming: IncomingText.pasted(text, at: clock.now()),
      understanding: engine.understand(text),
    );
    return result.valueOrNull!;
  }

  LocalDateTime at(DateTime value) => LocalDateTime.from(value);

  final tomorrowMorning = LocalDateTime(
    year: 2026,
    month: 9,
    day: 17,
    hour: 9,
    minute: 0,
  );

  group('creating', () {
    test('a reminder in the future is created and active', () async {
      final id = await saveMemory('Bayar bil RM183.50');

      final result = await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      );

      final reminder = result.valueOrNull!;
      expect(reminder.status, ReminderStatus.scheduled);
      expect(reminder.at.date, '2026-09-17');
      expect(reminder.at.time, '09:00');
      expect(reminder.memoryId, id);
      expect(await reminders.activeFor(id), isNotNull);
    });

    test('the chosen local time is what is stored, and the instant follows it',
        () async {
      final id = await saveMemory('Mesyuarat');

      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect(reminder.remindAt, DateTime(2026, 9, 17, 9));
      expect(reminder.at.resolve(), DateTime(2026, 9, 17, 9));
    });

    test('a time exactly now is refused (B-3)', () async {
      final id = await saveMemory('Sekarang');

      final result = await reminders.create(memoryId: id, at: at(now));

      expect(result.failureOrNull, isA<ReminderTimeInPastFailure>());
      expect(await reminders.activeFor(id), isNull);
    });

    test('a time in the past is refused, and nothing rolls forward', () async {
      final id = await saveMemory('Semalam');

      final result = await reminders.create(
        memoryId: id,
        at: at(now.subtract(const Duration(minutes: 1))),
      );

      expect(result.failureOrNull, isA<ReminderTimeInPastFailure>());
      expect(await reminders.activeFor(id), isNull);
    });

    test('a time that passes between opening the picker and pressing set is '
        'refused at commit', () async {
      final id = await saveMemory('Hampir tengah malam');
      final chosen = LocalDateTime(
        year: 2026,
        month: 9,
        day: 16,
        hour: 23,
        minute: 59,
      );

      // The user lingers; midnight passes before they press Tetapkan.
      clock.value = DateTime(2026, 9, 17, 0, 1);
      final result = await reminders.create(memoryId: id, at: chosen);

      expect(result.failureOrNull, isA<ReminderTimeInPastFailure>());
    });

    test('a date the calendar does not have is refused', () async {
      final id = await saveMemory('31 Februari');

      final result = await reminders.create(
        memoryId: id,
        at: const LocalDateTime(
          year: 2026,
          month: 2,
          day: 31,
          hour: 9,
          minute: 0,
        ),
      );

      expect(result.failureOrNull, isA<ReminderTimeInPastFailure>());
    });

    test('an unknown or deleted memory gets no reminder', () async {
      final id = await saveMemory('Akan dipadam');
      await memories.delete(id);

      expect(
        (await reminders.create(memoryId: id, at: tomorrowMorning))
            .failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('one active reminder per memory (B-7)', () {
    test('a second reminder is refused while one is active', () async {
      final id = await saveMemory('Satu sahaja');
      await reminders.create(memoryId: id, at: tomorrowMorning);

      final second = await reminders.create(
        memoryId: id,
        at: at(DateTime(2026, 9, 18, 15)),
      );

      expect(second.failureOrNull, isA<ReminderAlreadyExistsFailure>());
      expect(await reminders.watchFor(id).first, hasLength(1));
    });

    test('the database itself refuses two active rows', () async {
      final id = await saveMemory('Dua serentak');
      await reminders.create(memoryId: id, at: tomorrowMorning);

      // Bypassing the repository entirely, as a race between two taps would.
      await expectLater(
        db.customStatement(
          'INSERT INTO reminders (id, memory_id, local_date, local_time, '
          'time_zone, remind_at, status, created_at, updated_at) '
          "VALUES ('11111111-1111-4111-8111-111111111111', ?, '2026-09-18', "
          "'10:00', 'X', 1, 'scheduled', 1, 1)",
          <Object?>[id],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a cancelled reminder frees the slot', () async {
      final id = await saveMemory('Batal dahulu');
      final first = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;
      await reminders.cancel(first.id);

      final second = await reminders.create(
        memoryId: id,
        at: at(DateTime(2026, 9, 18, 15)),
      );

      expect(second.isOk, isTrue);
      expect(await reminders.watchFor(id).first, hasLength(2));
    });

    test('a fired reminder frees the slot and stays as history (B-4)',
        () async {
      final id = await saveMemory('Sudah berlalu');
      final first = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;
      await reminders.markFired(first.id);

      final second = await reminders.create(
        memoryId: id,
        at: at(DateTime(2026, 9, 18, 15)),
      );

      expect(second.isOk, isTrue);
      final all = await reminders.watchFor(id).first;
      expect(all.map((r) => r.status), containsAll(<ReminderStatus>[
        ReminderStatus.fired,
        ReminderStatus.scheduled,
      ]));
      expect(await reminders.activeFor(id), isNotNull);
    });
  });

  group('replacing', () {
    test('moves the reminder to the new time', () async {
      final id = await saveMemory('Ubah masa');
      final original = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      final replaced = await reminders.replace(
        reminderId: original.id,
        at: at(DateTime(2026, 9, 17, 17)),
      );

      expect(replaced.valueOrNull!.at.time, '17:00');
      expect(await reminders.watchFor(id).first, hasLength(1));
      // The same alarm id, so rescheduling replaces rather than adds.
      expect(replaced.valueOrNull!.notificationId, original.notificationId);
    });

    test('a refused new time leaves the old reminder exactly as it was',
        () async {
      final id = await saveMemory('Jangan hilang');
      final original = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      final refused = await reminders.replace(
        reminderId: original.id,
        at: at(now.subtract(const Duration(hours: 1))),
      );

      expect(refused.failureOrNull, isA<ReminderTimeInPastFailure>());
      final still = await reminders.activeFor(id);
      expect(still!.id, original.id);
      expect(still.at.time, '09:00');
      expect(still.status, ReminderStatus.scheduled);
    });

    test('a cancelled reminder cannot be replaced', () async {
      final id = await saveMemory('Sudah batal');
      final original = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;
      await reminders.cancel(original.id);

      expect(
        (await reminders.replace(
          reminderId: original.id,
          at: at(DateTime(2026, 9, 18, 9)),
        )).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('cancelling', () {
    test('cancels the reminder and keeps the memory', () async {
      final id = await saveMemory('Kekal ada');
      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect((await reminders.cancel(reminder.id)).isOk, isTrue);

      expect(await reminders.activeFor(id), isNull);
      expect((await memories.findById(id)).isOk, isTrue);
      expect((await reminders.watchFor(id).first).single.status,
          ReminderStatus.cancelled);
    });

    test('cancelling twice fails safely', () async {
      final id = await saveMemory('Dua kali');
      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;
      await reminders.cancel(reminder.id);

      expect((await reminders.cancel(reminder.id)).isErr, isTrue);
    });
  });

  group('deleting a memory', () {
    test('a guest memory takes its reminder with it', () async {
      final id = await saveMemory('Tetamu');
      await reminders.create(memoryId: id, at: tomorrowMorning);

      await memories.delete(id);

      expect(await db.select(db.reminders).get(), isEmpty);
    });

    test('an account memory keeps the row but cancels the reminder', () async {
      signedIn = 'user-a';
      final id = await saveMemory('Akaun');
      await reminders.create(memoryId: id, at: tomorrowMorning);
      await db.customStatement(
        "UPDATE memories SET sync_status = 'synced', server_updated_at = 5 "
        'WHERE id = ?',
        <Object?>[id],
      );

      await memories.delete(id);

      // The memory is a tombstone, so nothing cascades — but the reminder must
      // never alert for something the user deleted.
      expect(await reminders.activeFor(id), isNull);
      expect((await db.select(db.reminders).get()).single.status, 'cancelled');
    });

    test('cancelForMemory returns the alarms that must be cancelled', () async {
      final id = await saveMemory('Kembalikan id');
      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect(await reminders.cancelForMemory(id), <int>[
        reminder.notificationId,
      ]);
      expect(await reminders.cancelForMemory(id), isEmpty);
    });
  });

  group('implicit Save', () {
    test('setting a reminder on an unsaved result saves the memory too',
        () async {
      const text = 'Bayar bil TNB RM183.50 sebelum 25/09/2026';

      final result = await reminders.createWithMemory(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: engine.understand(text),
        at: tomorrowMorning,
      );

      final reminder = result.valueOrNull!;
      final saved = (await memories.findById(reminder.memoryId)).valueOrNull!;
      expect(saved.content, text);
      expect(saved.entities, isNotEmpty);
      expect(await reminders.activeFor(reminder.memoryId), isNotNull);
    });

    test('a refused time saves no memory at all', () async {
      const text = 'Tidak patut disimpan';

      final result = await reminders.createWithMemory(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: engine.understand(text),
        at: at(now.subtract(const Duration(days: 1))),
      );

      expect(result.failureOrNull, isA<ReminderTimeInPastFailure>());
      expect(await memories.watch().first, isEmpty);
      expect(await db.select(db.reminders).get(), isEmpty);
    });

    test('works with no network involved at all', () async {
      // Nothing in this path touches the cloud: reminders never sync (B-5),
      // and Save is local-first. The absence of any network dependency is what
      // makes this test meaningful offline.
      const text = 'Luar talian RM20';

      final result = await reminders.createWithMemory(
        incoming: IncomingText.pasted(text, at: clock.now()),
        understanding: engine.understand(text),
        at: tomorrowMorning,
      );

      expect(result.isOk, isTrue);
    });
  });

  group('ownership', () {
    test('a guest reminder has no owner', () async {
      final id = await saveMemory('Tetamu');

      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect(reminder.ownerUserId, isNull);
    });

    test('a signed-in save gives the reminder the same owner', () async {
      signedIn = 'user-a';
      final id = await saveMemory('Akaun');

      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect(reminder.ownerUserId, 'user-a');
    });

    test('guest migration moves reminders with their memories', () async {
      final id = await saveMemory('Akan dipindah');
      await reminders.create(memoryId: id, at: tomorrowMorning);

      // The memory moves first, as the migration does.
      await db.customStatement(
        "UPDATE memories SET owner_user_id = 'user-a', "
        "sync_status = 'pending' WHERE owner_user_id IS NULL",
      );
      expect(await reminders.adoptGuestReminders('user-a'), 1);

      final moved = await reminders.activeFor(id);
      expect(moved!.ownerUserId, 'user-a');
      // Same device, same alarm: nothing is rescheduled.
      expect(moved.status, ReminderStatus.scheduled);
    });

    test('migration leaves another account\'s reminders alone', () async {
      signedIn = 'user-b';
      final theirs = await saveMemory('Milik B');
      await reminders.create(memoryId: theirs, at: tomorrowMorning);

      expect(await reminders.adoptGuestReminders('user-a'), 0);
      expect((await reminders.activeFor(theirs))!.ownerUserId, 'user-b');
    });
  });

  group('sign-out', () {
    test('removes the account\'s reminders and reports their alarms', () async {
      signedIn = 'user-a';
      final mine = await saveMemory('Akaun saya');
      final reminder = (await reminders.create(
        memoryId: mine,
        at: tomorrowMorning,
      )).valueOrNull!;
      signedIn = null;
      final guest = await saveMemory('Tetamu');
      await reminders.create(memoryId: guest, at: tomorrowMorning);

      final cancelled = await reminders.purgeAccount('user-a');

      expect(cancelled, <int>[reminder.notificationId]);
      final left = await db.select(db.reminders).get();
      expect(left.single.memoryId, guest);
    });

    test('a cancelled account reminder needs no alarm cancelled', () async {
      signedIn = 'user-a';
      final id = await saveMemory('Sudah batal');
      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;
      await reminders.cancel(reminder.id);

      expect(await reminders.purgeAccount('user-a'), isEmpty);
      expect(await db.select(db.reminders).get(), isEmpty);
    });
  });

  group('privacy', () {
    test('a reminder prints no memory content', () async {
      final id = await saveMemory('RAHSIA 012-3456789');
      final reminder = (await reminders.create(
        memoryId: id,
        at: tomorrowMorning,
      )).valueOrNull!;

      expect(reminder.toString(), isNot(contains('RAHSIA')));
      expect(reminder.toString(), isNot(contains('3456789')));
    });
  });
}

/// A clock a test can move, for the cases where time passes mid-flow.
final class _MovableClock implements Clock {
  _MovableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;

  @override
  DateTime today() => DateTime(value.year, value.month, value.day);
}
