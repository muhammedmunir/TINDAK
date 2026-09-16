import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/widgets/reminder_sheet.dart';
import 'package:tindak/features/understanding/model/date_value.dart';

/// The time picker (M7b). TINDAK never chooses a time for the user (PD-007),
/// and the resolved date — including a year TINDAK worked out — is visible
/// before anything is committed (PD-025).
void main() {
  Future<LocalDateTime?> openSheet(
    WidgetTester tester, {
    required DateValue date,
    TimeOfDay? initialTime,
  }) async {
    LocalDateTime? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await ReminderSheet.show(
                  context,
                  date: date,
                  initialTime: initialTime,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('shows the full resolved date', (tester) async {
    await openSheet(tester, date: const DateValue(2026, 9, 25));

    expect(find.text('25 September 2026'), findsOneWidget);
    expect(find.text(ReminderCopy.setTitle), findsOneWidget);
  });

  testWidgets('a year TINDAK inferred is shown before committing', (tester) async {
    // "25 Ogos" with no year resolved to 2027; the user sees which year.
    await openSheet(tester, date: const DateValue(2027, 8, 25));

    expect(find.text('25 Ogos 2027'), findsOneWidget);
  });

  testWidgets('Tetapkan is disabled until a time is chosen (PD-007)',
      (tester) async {
    await openSheet(tester, date: const DateValue(2026, 9, 25));

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('reminder-confirm')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(ReminderCopy.pickTime), findsOneWidget);
  });

  testWidgets('choosing a time enables Tetapkan and returns it',
      (tester) async {
    LocalDateTime? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await ReminderSheet.show(
                  context,
                  date: const DateValue(2026, 9, 25),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('reminder-pick-time')));
    await tester.pumpAndSettle();
    // The dialog opens on 9:00; accept it.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('reminder-confirm')),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey<String>('reminder-confirm')));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.date, '2026-09-25');
    expect(chosen!.time, '09:00');
  });

  testWidgets('Ubah opens on the time the reminder already has (B-7)',
      (tester) async {
    await openSheet(
      tester,
      date: const DateValue(2026, 9, 25),
      initialTime: const TimeOfDay(hour: 15, minute: 30),
    );

    expect(find.text('3:30 PTG'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('reminder-confirm')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Batal returns nothing', (tester) async {
    final chosen = await openSheet(
      tester,
      date: const DateValue(2026, 9, 25),
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    await tester.tap(find.text(ReminderCopy.cancel));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
  });

  group('copy', () {
    test('is exactly what Product Direction approved', () {
      expect(ReminderCopy.reminderSet, 'Peringatan ditetapkan.');
      expect(
        ReminderCopy.reminderSetNoNotifications,
        'Peringatan disimpan, tetapi notifikasi dimatikan.',
      );
      expect(ReminderCopy.reminderUpdated, 'Peringatan dikemas kini.');
      expect(ReminderCopy.reminderCancelled, 'Peringatan dibatalkan.');
      expect(ReminderCopy.timeInPast, 'Pilih masa yang belum berlalu.');
      expect(ReminderCopy.cancelReminderAction, 'Batalkan Peringatan');
      expect(ReminderCopy.openSettings, 'Buka Tetapan');
      expect(ReminderCopy.notificationsOff, 'Notifikasi dimatikan');
      expect(ReminderCopy.completed, 'Selesai');
    });

    test('times read the way a Malay speaker says them', () {
      expect(ReminderCopy.timeLabel12Hour(15, 30), '3:30 PTG');
      expect(ReminderCopy.timeLabel12Hour(9, 0), '9:00 PG');
      expect(ReminderCopy.timeLabel12Hour(0, 5), '12:05 PG');
      expect(ReminderCopy.timeLabel12Hour(12, 0), '12:00 PTG');
      expect(ReminderCopy.timeLabel12Hour(23, 59), '11:59 PTG');
    });

    test('a reminder reads as a full date and time', () {
      expect(
        ReminderCopy.dateTimeLabel(
          const LocalDateTime(
            year: 2026,
            month: 9,
            day: 25,
            hour: 15,
            minute: 30,
          ),
        ),
        '25 September 2026, 3:30 PTG',
      );
    });
  });
}
