import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_providers.dart';
import 'package:tindak/features/reminders/reminder_service.dart';
import 'package:tindak/features/reminders/widgets/reminder_actions.dart';
import 'package:tindak/features/reminders/widgets/reminder_sheet.dart';

/// The reminder on a saved memory: the active one with its actions, or the
/// last one that fired, shown as Selesai so it never looks lost (B-4).
///
/// Deliberately not a history screen. Only the reminder that matters now, and
/// the most recent completed one.
class ReminderSection extends ConsumerWidget {
  const ReminderSection({required this.memoryId, super.key});

  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminders =
        ref.watch(remindersForMemoryProvider(memoryId)).value ??
        const <ReminderRecord>[];
    if (reminders.isEmpty) return const SizedBox.shrink();

    final active = reminders.where((r) => r.isActive).firstOrNull;
    final shown = active ?? reminders.first;
    if (!shown.isActive && shown.status != ReminderStatus.fired) {
      // A cancelled reminder with nothing active is simply gone from view.
      return const SizedBox.shrink();
    }

    final notificationsOff =
        ref.watch(reminderPermissionProvider).value ==
        ReminderPermissionState.off;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 28),
        Text(
          ReminderCopy.sectionTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ReminderCopy.dateTimeLabel(shown.at),
          style: theme.textTheme.bodyMedium,
        ),
        if (shown.isActive && notificationsOff) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            ReminderCopy.notificationsOff,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (!shown.isActive) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            ReminderCopy.completed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (shown.isActive) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('reminder-change'),
                onPressed: () => changeReminder(context, ref, shown),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text(ReminderCopy.changeAction),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('reminder-cancel'),
                onPressed: () => cancelReminder(context, ref, shown),
                icon: const Icon(Icons.notifications_off_outlined, size: 18),
                label: const Text(ReminderCopy.cancelReminderAction),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
