import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/reminders/data/notification_permission.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';
import 'package:tindak/features/reminders/reminder_providers.dart';
import 'package:tindak/features/reminders/widgets/reminder_sheet.dart';

import '../../app/tindak_app_test.dart' show FakeShareChannel, pumpApp, shareOf;
import '../../support/test_database.dart';

/// The reminder flow through the real screens (M7b): share, Ingatkan, pick a
/// time, Tetapkan — then the reminder on the memory, changed and cancelled.
void main() {
  late TindakDatabase db;
  late _FakeScheduler scheduler;
  late _FakePermission permission;
  final today = DateTime(2026, 9, 16, 10);

  setUp(() {
    db = openTestDatabase();
    scheduler = _FakeScheduler();
    permission = _FakePermission();
  });

  List<Override> overrides() => <Override>[
    clockProvider.overrideWithValue(FixedClock(today)),
    reminderSchedulerProvider.overrideWithValue(scheduler),
    notificationPermissionProvider.overrideWithValue(permission),
  ];

  /// Shares text with a date in it and taps Ingatkan.
  Future<void> shareAndTapRemind(WidgetTester tester, String text) async {
    final channel = FakeShareChannel(initial: shareOf(1, text));
    await pumpApp(tester, channel, database: db, overrides: overrides());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ingatkan'));
    await tester.pumpAndSettle();
  }

  Future<void> pickTimeAndConfirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('reminder-pick-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('reminder-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('Ingatkan on a shared date saves the memory and sets the '
      'reminder, with one confirmation', (tester) async {
    await shareAndTapRemind(tester, 'Bayar bil TNB sebelum 25/09/2026');

    expect(find.text('25 September 2026'), findsWidgets);
    await pickTimeAndConfirm(tester);

    // One message, not "Disimpan." and then this.
    expect(find.text(ReminderCopy.reminderSet), findsOneWidget);
    expect(find.text('Disimpan pada peranti ini.'), findsNothing);

    final memories = await db.select(db.memories).get();
    expect(memories.single.content, 'Bayar bil TNB sebelum 25/09/2026');
    final reminders = await db.select(db.reminders).get();
    expect(reminders.single.status, 'scheduled');
    expect(reminders.single.localTime, '09:00');
    expect(scheduler.scheduled, hasLength(1));
  });

  testWidgets('a refused notification permission still keeps the reminder',
      (tester) async {
    permission.state = NotificationPermission.denied;

    await shareAndTapRemind(tester, 'Mesyuarat 25/09/2026');
    await pickTimeAndConfirm(tester);

    expect(
      find.text(ReminderCopy.reminderSetNoNotifications),
      findsOneWidget,
    );
    expect(find.text(ReminderCopy.openSettings), findsOneWidget);
    expect(await db.select(db.reminders).get(), hasLength(1));
  });

  testWidgets('permission is asked in this flow, not at launch',
      (tester) async {
    final channel = FakeShareChannel(
      initial: shareOf(1, 'Mesyuarat 25/09/2026'),
    );
    await pumpApp(tester, channel, database: db, overrides: overrides());

    expect(permission.requests, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ingatkan'));
    await tester.pumpAndSettle();
    await pickTimeAndConfirm(tester);

    expect(permission.requests, 1);
  });

  testWidgets('backing out of the sheet sets nothing and saves nothing',
      (tester) async {
    await shareAndTapRemind(tester, 'Mesyuarat 25/09/2026');

    await tester.tap(find.text(ReminderCopy.cancel));
    await tester.pumpAndSettle();

    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.memories).get(), isEmpty);
    expect(scheduler.scheduled, isEmpty);
  });

  testWidgets('the memory then shows its reminder, which can be changed and '
      'cancelled', (tester) async {
    await shareAndTapRemind(tester, 'Bayar bil 25/09/2026');
    await pickTimeAndConfirm(tester);

    // Close the result and open the saved memory.
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bayar bil').first);
    await tester.pumpAndSettle();

    expect(find.text(ReminderCopy.sectionTitle), findsOneWidget);
    expect(find.text('25 September 2026, 9:00 PG'), findsOneWidget);

    // Ubah opens on the existing time and replaces it.
    await tester.tap(find.byKey(const ValueKey<String>('reminder-change')));
    await tester.pumpAndSettle();
    expect(find.text('9:00 PG'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('reminder-pick-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('reminder-confirm')));
    await tester.pumpAndSettle();

    expect(find.text(ReminderCopy.reminderUpdated), findsOneWidget);
    expect(scheduler.scheduled, hasLength(1));
    expect(await db.select(db.reminders).get(), hasLength(1));

    // Batalkan Peringatan leaves the memory alone.
    await tester.tap(find.byKey(const ValueKey<String>('reminder-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(ReminderCopy.reminderCancelled), findsOneWidget);
    expect(scheduler.scheduled, isEmpty);
    expect(await db.select(db.memories).get(), hasLength(1));
    expect((await db.select(db.reminders).get()).single.status, 'cancelled');
  });

  testWidgets('deleting the memory cancels the alarm', (tester) async {
    await shareAndTapRemind(tester, 'Akan dipadam 25/09/2026');
    await pickTimeAndConfirm(tester);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Akan dipadam').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Padam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Padam'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled, isEmpty);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.memories).get(), isEmpty);
  });

  testWidgets('the app reconciles at start', (tester) async {
    final channel = FakeShareChannel();
    await pumpApp(tester, channel, database: db, overrides: overrides());

    expect(scheduler.reconcileReads, greaterThan(0));
  });
}

final class _FakeScheduler implements ReminderScheduler {
  final Map<int, DateTime> scheduled = <int, DateTime>{};
  int reconcileReads = 0;

  @override
  Future<bool> schedule({
    required int notificationId,
    required DateTime at,
    required String memoryId,
  }) async {
    scheduled[notificationId] = at;
    return true;
  }

  @override
  Future<void> cancel(int notificationId) async =>
      scheduled.remove(notificationId);

  @override
  Future<Set<int>> pending() async {
    reconcileReads++;
    return scheduled.keys.toSet();
  }
}

final class _FakePermission implements NotificationPermissionGateway {
  NotificationPermission state = NotificationPermission.granted;
  int requests = 0;

  @override
  Future<NotificationPermission> status() async => state;

  @override
  Future<NotificationPermission> request() async {
    requests++;
    return state;
  }

  @override
  Future<void> openSettings() async {}
}
