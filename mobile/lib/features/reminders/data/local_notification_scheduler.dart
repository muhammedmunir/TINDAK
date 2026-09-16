import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';

/// Fires reminders through Android's notification service (M7b).
///
/// The only file that talks to `flutter_local_notifications`, so every rule
/// around it stays testable against the fake in M7a. **Inexact
/// allow-while-idle** scheduling (ADR-024): TINDAK asks for no exact-alarm
/// permission, and the UI never promises delivery to the minute.
///
/// **The notification carries no content** — not the memory's text, a phone
/// number, a link or an amount. Title and body are fixed, and the payload is
/// the memory id, so a locked screen shows nothing private.
final class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AppLogger _log = AppLogger('reminders');

  /// Approved copy. Deliberately says nothing about which item it is.
  static const String notificationTitle = 'Peringatan TINDAK';
  static const String notificationBody =
      'Anda mempunyai peringatan yang dijadualkan.';

  static const String channelId = 'tindak_reminders';
  static const String channelName = 'Peringatan';
  static const String channelDescription =
      'Peringatan yang anda tetapkan dalam TINDAK.';

  /// Loads the timezone database.
  ///
  /// TINDAK does not look up the device's IANA zone name, and does not add a
  /// package to do so. It does not need one: the chosen local clock time is
  /// authoritative (B-2), and Dart already applies the device's own rules —
  /// daylight saving included — when it resolves that time to an instant.
  /// Scheduling then uses the **instant**, expressed in UTC.
  ///
  /// The zone name matters to the plugin, which hands it to Java's
  /// `ZoneId.of`: an invented name is rejected outright, and a guessed one
  /// could carry daylight-saving rules the device does not follow. `UTC` is
  /// accepted everywhere and has no rules to disagree about.
  ///
  /// A later zone or offset change is handled where it belongs: the reconciler
  /// recomputes the instant from the chosen local time and reschedules.
  static void prepareTimeZones() => tz_data.initializeTimeZones();

  @override
  Future<bool> schedule({
    required int notificationId,
    required DateTime at,
    required String memoryId,
  }) async {
    try {
      await _plugin.zonedSchedule(
        notificationId,
        notificationTitle,
        notificationBody,
        // The same moment, written in a zone the platform will accept. `at`
        // already came from the device's own clock rules.
        tz.TZDateTime.from(at.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            // Nothing private on the lock screen, even if the device is set to
            // show notification content there.
            visibility: NotificationVisibility.private,
          ),
        ),
        // ADR-024. Android may delay this in Doze; a reminder is not an alarm
        // clock, and TINDAK does not request the restricted permission that
        // would make it exact.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: memoryId,
      );
      return true;
    } on Object catch (error, stackTrace) {
      // The reminder itself survives; the reconciler tries again later.
      _log.failure(
        'reminder_schedule_failed_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> cancel(int notificationId) async {
    try {
      await _plugin.cancel(notificationId);
    } on Object catch (error, stackTrace) {
      _log.failure(
        'reminder_cancel_failed_${error.runtimeType}',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Set<int>> pending() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return requests.map((r) => r.id).toSet();
    } on Object catch (error, stackTrace) {
      _log.failure(
        'reminder_pending_failed_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      // An empty set makes the reconciler reschedule everything, which is
      // safe: scheduling by id replaces rather than duplicates.
      return const <int>{};
    }
  }
}
