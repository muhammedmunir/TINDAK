import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';

/// What one reconciliation pass changed. Counts only — never a reminder's
/// time or the memory it belongs to.
final class ReconcileReport {
  const ReconcileReport({
    this.scheduled = 0,
    this.cancelled = 0,
    this.fired = 0,
    this.failed = 0,
  });

  /// Alarms the device was missing and now has.
  final int scheduled;

  /// Alarms the device held for reminders that no longer exist.
  final int cancelled;

  /// Reminders whose time had passed while the app was not running.
  final int fired;

  /// Alarms the platform refused. They are retried next pass.
  final int failed;

  bool get changedNothing =>
      scheduled == 0 && cancelled == 0 && fired == 0 && failed == 0;

  @override
  String toString() =>
      'ReconcileReport(scheduled: $scheduled, cancelled: $cancelled, '
      'fired: $fired, failed: $failed)';
}

/// Brings the device's alarms back in line with the database.
///
/// The database is the source of truth; the alarms are a cache of it. The two
/// cannot be written in one transaction, so instead of trying to keep them
/// perfectly in step, TINDAK repairs the difference — at app start, on resume,
/// and after a reboot.
///
/// That single mechanism covers: a schedule that failed after the row was
/// written, alarms Android dropped at reboot, a reminder cancelled while the
/// app was closed, a memory deleted on another screen, and a time zone change
/// that moved a reminder's instant (B-2).
///
/// It is idempotent. Running it twice changes nothing the second time.
final class ReminderReconciler {
  const ReminderReconciler({
    required ReminderRepository repository,
    required ReminderScheduler scheduler,
    required Clock clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _clock = clock;

  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final Clock _clock;

  static const AppLogger _log = AppLogger('reminders');

  Future<ReconcileReport> reconcile() async {
    final now = _clock.now();
    var scheduled = 0;
    var cancelled = 0;
    var fired = 0;
    var failed = 0;

    final active = await _repository.active();
    final pending = await _scheduler.pending();
    final wanted = <int>{};

    for (final reminder in active) {
      // The instant is recomputed from the time the user chose, so a device
      // that has changed time zone reschedules to the same clock time (B-2).
      final at = reminder.at.resolve();

      if (!at.isAfter(now)) {
        // Its moment passed while the app was not running. It has had whatever
        // alert it was going to get; it becomes history rather than firing late
        // or lingering as active (B-4).
        await _repository.markFired(reminder.id);
        if (pending.contains(reminder.notificationId)) {
          await _scheduler.cancel(reminder.notificationId);
        }
        fired++;
        continue;
      }

      wanted.add(reminder.notificationId);
      // Android reports which alarms it holds, never when they fire, so the
      // comparison is against what it was last told.
      final alreadyHeld =
          pending.contains(reminder.notificationId) &&
          reminder.scheduledAt?.millisecondsSinceEpoch ==
              at.millisecondsSinceEpoch;
      if (alreadyHeld) continue;

      final ok = await _scheduler.schedule(
        notificationId: reminder.notificationId,
        at: at,
        memoryId: reminder.memoryId,
      );
      if (ok) {
        await _repository.markScheduled(reminder.id, at);
        scheduled++;
      } else {
        // The reminder stays; only its alarm is missing, and the next pass
        // tries again.
        failed++;
      }
    }

    for (final id in pending) {
      if (wanted.contains(id)) continue;
      // An alarm with no reminder behind it: cancelled, deleted, or belonging
      // to an account that has signed out. It must never be allowed to fire.
      await _scheduler.cancel(id);
      cancelled++;
    }

    final report = ReconcileReport(
      scheduled: scheduled,
      cancelled: cancelled,
      fired: fired,
      failed: failed,
    );
    if (!report.changedNothing) _log.event('reminder_reconciled');
    return report;
  }
}
