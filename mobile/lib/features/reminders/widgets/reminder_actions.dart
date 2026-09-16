import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_providers.dart';
import 'package:tindak/features/reminders/reminder_service.dart';
import 'package:tindak/features/reminders/widgets/reminder_sheet.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Runs the reminder flow from a tap on Ingatkan, Ubah or Batalkan Peringatan.
///
/// Nothing here schedules anything itself: it asks for the time, hands the
/// decision to `ReminderService`, and reports what happened in the approved
/// words.

/// Ingatkan on a detected date. [incoming] and [understanding] are supplied
/// when the memory has not been saved yet, in which case setting the reminder
/// saves it too — one press, one confirmation.
Future<void> setReminderForEntity(
  BuildContext context,
  WidgetRef ref,
  DetectedEntity entity, {
  String? memoryId,
  IncomingText? incoming,
  UnderstandingResult? understanding,
}) async {
  final date = DateValue.parse(entity.normalizedValue);
  if (date == null) return;

  final at = await ReminderSheet.show(context, date: date);
  if (at == null || !context.mounted) return;

  final service = ref.read(reminderServiceProvider);
  final result = memoryId != null
      ? await service.set(memoryId: memoryId, at: at)
      : await service.setOnUnsaved(
          incoming: incoming!,
          understanding: understanding!,
          at: at,
        );

  if (!context.mounted) return;
  _report(context, ref, result, updated: false);
}

/// Ubah: shows the time the reminder already has, then replaces it.
Future<void> changeReminder(
  BuildContext context,
  WidgetRef ref,
  ReminderRecord reminder,
) async {
  final at = await ReminderSheet.show(
    context,
    date: DateValue(reminder.at.year, reminder.at.month, reminder.at.day),
    initialTime: TimeOfDay(
      hour: reminder.at.hour,
      minute: reminder.at.minute,
    ),
  );
  if (at == null || !context.mounted) return;

  final result = await ref
      .read(reminderServiceProvider)
      .change(reminderId: reminder.id, at: at);

  if (!context.mounted) return;
  _report(context, ref, result, updated: true);
}

/// Batalkan Peringatan. The memory stays; only the reminder goes.
Future<void> cancelReminder(
  BuildContext context,
  WidgetRef ref,
  ReminderRecord reminder,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final cancelled = await ref
      .read(reminderServiceProvider)
      .cancel(reminder);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          cancelled
              ? ReminderCopy.reminderCancelled
              : ReminderCopy.reminderFailed,
        ),
      ),
    );
}

void _report(
  BuildContext context,
  WidgetRef ref,
  ReminderActionResult result, {
  required bool updated,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  switch (result.outcome) {
    case ReminderOutcome.set:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? ReminderCopy.reminderUpdated
                : ReminderCopy.reminderSet,
          ),
        ),
      );
    case ReminderOutcome.setWithoutNotifications:
      // The reminder exists and is kept; only delivery is off (PD-026). The
      // action offers the way back rather than leaving it to the user to find.
      messenger.showSnackBar(
        SnackBar(
          content: const Text(ReminderCopy.reminderSetNoNotifications),
          action: SnackBarAction(
            label: ReminderCopy.openSettings,
            onPressed: () =>
                ref.read(reminderServiceProvider).openNotificationSettings(),
          ),
        ),
      );
    case ReminderOutcome.timeInPast:
      messenger.showSnackBar(
        const SnackBar(content: Text(ReminderCopy.timeInPast)),
      );
    case ReminderOutcome.alreadyExists:
    case ReminderOutcome.failed:
      messenger.showSnackBar(
        const SnackBar(content: Text(ReminderCopy.reminderFailed)),
      );
  }
}
