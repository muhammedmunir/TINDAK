import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/reminders/data/notification_permission.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_reconciler.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// What happened when the user set, changed or cancelled a reminder.
enum ReminderOutcome {
  /// Set, and the device will deliver it.
  set,

  /// Set and kept, but notifications are off, so nothing will alert
  /// (PD-026). Never reported as a failure.
  setWithoutNotifications,

  /// The chosen time has already passed (B-3).
  timeInPast,

  /// The memory already has an active reminder; change that one instead.
  alreadyExists,

  /// Nothing was written.
  failed,
}

/// One reminder action, as the UI sees it.
final class ReminderActionResult {
  const ReminderActionResult(this.outcome, {this.reminder});

  final ReminderOutcome outcome;
  final ReminderRecord? reminder;

  bool get isSet =>
      outcome == ReminderOutcome.set ||
      outcome == ReminderOutcome.setWithoutNotifications;
}

/// Ties the reminder rules to the device: permission, then the database, then
/// the alarm.
///
/// The order matters. The reminder is committed before anything is scheduled,
/// and a refused permission or a failed alarm never discards it — the
/// reconciler repairs the alarm later, and a reminder with notifications off
/// still exists and still shows on the memory (PD-026).
final class ReminderService {
  const ReminderService({
    required ReminderRepository repository,
    required ReminderScheduler scheduler,
    required NotificationPermissionGateway permission,
    required ReminderReconciler reconciler,
  }) : _repository = repository,
       _scheduler = scheduler,
       _permission = permission,
       _reconciler = reconciler;

  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final NotificationPermissionGateway _permission;
  final ReminderReconciler _reconciler;

  /// Sets a reminder on a saved memory.
  Future<ReminderActionResult> set({
    required String memoryId,
    required LocalDateTime at,
  }) => _commit(
    () => _repository.create(memoryId: memoryId, at: at),
  );

  /// Sets a reminder on a result that has not been saved: the memory is saved
  /// with it, in one transaction. The user sees one confirmation, not two.
  Future<ReminderActionResult> setOnUnsaved({
    required IncomingText incoming,
    required UnderstandingResult understanding,
    required LocalDateTime at,
  }) => _commit(
    () => _repository.createWithMemory(
      incoming: incoming,
      understanding: understanding,
      at: at,
    ),
  );

  /// Moves an existing reminder. The old one stays in force until the new one
  /// is committed, and its alarm is replaced only afterwards (B-7).
  Future<ReminderActionResult> change({
    required String reminderId,
    required LocalDateTime at,
  }) => _commit(() => _repository.replace(reminderId: reminderId, at: at));

  /// Cancels a reminder and removes its alarm. The memory is untouched.
  Future<bool> cancel(ReminderRecord reminder) async {
    final result = await _repository.cancel(reminder.id);
    if (result.isErr) return false;
    // Cancelled here rather than left to the reconciler, so an alarm cannot
    // fire between the tap and the next app start.
    await _scheduler.cancel(reminder.notificationId);
    return true;
  }

  /// Cancels the alarms behind a memory's reminders, after the memory itself
  /// was deleted.
  Future<void> cancelForMemory(String memoryId) async {
    for (final id in await _repository.cancelForMemory(memoryId)) {
      await _scheduler.cancel(id);
    }
  }

  /// Cancels and removes an account's reminders at sign-out (ADR-031).
  Future<void> purgeAccount(String userId) async {
    for (final id in await _repository.purgeAccount(userId)) {
      await _scheduler.cancel(id);
    }
  }

  /// Cancels alarms whose reminder rows are already gone — the sign-out purge
  /// deletes them by cascade, so it hands the ids over instead.
  Future<void> cancelAlarms(List<int> notificationIds) async {
    for (final id in notificationIds) {
      await _scheduler.cancel(id);
    }
  }

  /// Brings the device's alarms back in line with the database: at app start,
  /// on resume, and after a reboot.
  Future<ReconcileReport> reconcile() => _reconciler.reconcile();

  Future<ReminderPermissionState> permissionState() async =>
      switch (await _permission.status()) {
        NotificationPermission.denied => ReminderPermissionState.off,
        _ => ReminderPermissionState.on,
      };

  Future<void> openNotificationSettings() => _permission.openSettings();

  Future<ReminderActionResult> _commit(
    Future<Result<ReminderRecord>> Function() write,
  ) async {
    // Asked here, in the reminder flow, and nowhere else (PD-026).
    final permission = await _permission.request();

    final result = await write();
    return switch (result) {
      Err<ReminderRecord>(failure: ReminderTimeInPastFailure()) =>
        const ReminderActionResult(ReminderOutcome.timeInPast),
      Err<ReminderRecord>(failure: ReminderAlreadyExistsFailure()) =>
        const ReminderActionResult(ReminderOutcome.alreadyExists),
      Err<ReminderRecord>() => const ReminderActionResult(
        ReminderOutcome.failed,
      ),
      Ok<ReminderRecord>(value: final reminder) => await _schedule(
        reminder,
        permission,
      ),
    };
  }

  Future<ReminderActionResult> _schedule(
    ReminderRecord reminder,
    NotificationPermission permission,
  ) async {
    final at = reminder.at.resolve();
    final scheduled = await _scheduler.schedule(
      notificationId: reminder.notificationId,
      at: at,
      memoryId: reminder.memoryId,
    );
    if (scheduled) await _repository.markScheduled(reminder.id, at);

    return ReminderActionResult(
      permission == NotificationPermission.denied
          ? ReminderOutcome.setWithoutNotifications
          : ReminderOutcome.set,
      reminder: reminder,
    );
  }
}

/// Whether this device will deliver reminders, for the UI to say so.
enum ReminderPermissionState { on, off }
