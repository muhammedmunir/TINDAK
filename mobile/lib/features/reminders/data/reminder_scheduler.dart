/// The device's alarm scheduler, as the domain sees it.
///
/// M7a defines the contract and tests every rule against a fake. The real
/// implementation — `flutter_local_notifications` with an inexact
/// allow-while-idle schedule (ADR-024) — arrives with M7b, behind this same
/// interface.
///
/// The database is the source of truth; whatever the scheduler holds is a
/// cache of it that `ReminderReconciler` repairs.
abstract interface class ReminderScheduler {
  /// Schedules, or replaces, the alarm with this id. Returns false when the
  /// platform refused; the reminder still exists, and the reconciler retries.
  Future<bool> schedule({
    required int notificationId,
    required DateTime at,
    required String memoryId,
  });

  Future<void> cancel(int notificationId);

  /// Alarm ids the device currently holds.
  Future<Set<int>> pending();
}

/// Schedules nothing. Used until M7b, and wherever a test needs a reminder
/// stored without an alarm behind it.
final class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> schedule({
    required int notificationId,
    required DateTime at,
    required String memoryId,
  }) async => true;

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<Set<int>> pending() async => const <int>{};
}
