import 'package:flutter/material.dart';

import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/understanding/model/date_value.dart';

/// Reminder copy, approved by Product Direction at the M7 plan gate.
final class ReminderCopy {
  const ReminderCopy._();

  static const String setTitle = 'Tetapkan peringatan';
  static const String timeLabel = 'Masa';
  static const String pickTime = 'Pilih masa';
  static const String confirm = 'Tetapkan';
  static const String cancel = 'Batal';

  static const String remindAction = 'Ingatkan';
  static const String changeAction = 'Ubah';
  static const String cancelReminderAction = 'Batalkan Peringatan';

  static const String sectionTitle = 'Peringatan';
  static const String notificationsOff = 'Notifikasi dimatikan';
  static const String completed = 'Selesai';
  static const String openSettings = 'Buka Tetapan';

  static const String reminderSet = 'Peringatan ditetapkan.';
  static const String reminderSetNoNotifications =
      'Peringatan disimpan, tetapi notifikasi dimatikan.';
  static const String reminderUpdated = 'Peringatan dikemas kini.';
  static const String reminderCancelled = 'Peringatan dibatalkan.';
  static const String timeInPast = 'Pilih masa yang belum berlalu.';
  static const String reminderFailed =
      'Peringatan tidak dapat ditetapkan. Cuba lagi.';

  /// `25 September 2026, 3:30 PTG` — the full resolved date, so a year TINDAK
  /// worked out is visible before anything is committed (PD-025).
  static String dateTimeLabel(LocalDateTime at) {
    final date = DateValue(at.year, at.month, at.day).display;
    return '$date, ${timeLabel12Hour(at.hour, at.minute)}';
  }

  /// Malay 12-hour time: PG before noon, PTG from noon.
  static String timeLabel12Hour(int hour, int minute) {
    final suffix = hour < 12 ? 'PG' : 'PTG';
    final shown = switch (hour % 12) {
      0 => 12,
      final h => h,
    };
    return '$shown:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

/// Asks for the time, and nothing else.
///
/// The date is already decided — it came from the text the user shared, or
/// from the reminder being changed. Only the time is missing, and TINDAK never
/// invents one (PD-007): **Tetapkan stays disabled until a time is chosen.**
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({required this.date, this.initialTime, super.key});

  /// The resolved date, shown in full.
  final DateValue date;

  /// The current time when an existing reminder is being changed (B-7).
  final TimeOfDay? initialTime;

  /// Returns the chosen date and time, or null if the user backed out.
  static Future<LocalDateTime?> show(
    BuildContext context, {
    required DateValue date,
    TimeOfDay? initialTime,
  }) => showModalBottomSheet<LocalDateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReminderSheet(date: date, initialTime: initialTime),
  );

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _confirm() {
    final time = _time;
    if (time == null) return;
    Navigator.of(context).pop(
      LocalDateTime(
        year: widget.date.year,
        month: widget.date.month,
        day: widget.date.day,
        hour: time.hour,
        minute: time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = _time;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ReminderCopy.setTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // The full date, including a year TINDAK inferred, before anything
            // is committed.
            Text(widget.date.display, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text(
              ReminderCopy.timeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>('reminder-pick-time'),
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_outlined),
              label: Text(
                time == null
                    ? ReminderCopy.pickTime
                    : ReminderCopy.timeLabel12Hour(time.hour, time.minute),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(ReminderCopy.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey<String>('reminder-confirm'),
                  // No time, no reminder: TINDAK does not choose one.
                  onPressed: time == null ? null : _confirm,
                  child: const Text(ReminderCopy.confirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
