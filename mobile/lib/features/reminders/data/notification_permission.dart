import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:tindak/core/logging/app_logger.dart';

/// Whether this device will actually deliver a reminder.
enum NotificationPermission {
  /// Notifications will be delivered.
  granted,

  /// The user refused, or notifications are off for TINDAK. The reminder is
  /// still kept (PD-026) — it simply cannot alert.
  denied,

  /// No permission is needed on this Android version.
  notRequired,
}

/// Asks for the notification permission, and only in the reminder flow.
///
/// **Never at launch, never on onboarding, never because a date was
/// detected** (PD-026). Android 13 and later require POST_NOTIFICATIONS at
/// runtime; older versions grant it at install.
abstract interface class NotificationPermissionGateway {
  /// The current state, without prompting.
  Future<NotificationPermission> status();

  /// Asks once, in response to the user setting a reminder. Returns the state
  /// afterwards. Android itself stops repeating the prompt once refused.
  Future<NotificationPermission> request();

  /// Opens the system notification settings for TINDAK, for the
  /// **Buka Tetapan** action after a refusal.
  Future<void> openSettings();
}

final class AndroidNotificationPermission
    implements NotificationPermissionGateway {
  const AndroidNotificationPermission(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AppLogger _log = AppLogger('reminders');

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<NotificationPermission> status() async {
    final android = _android;
    if (android == null) return NotificationPermission.notRequired;
    try {
      final enabled = await android.areNotificationsEnabled();
      return (enabled ?? true)
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } on Object catch (error) {
      _log.failure('notification_status_${error.runtimeType}');
      return NotificationPermission.denied;
    }
  }

  @override
  Future<NotificationPermission> request() async {
    final android = _android;
    if (android == null) return NotificationPermission.notRequired;
    try {
      final granted = await android.requestNotificationsPermission();
      return (granted ?? false)
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } on Object catch (error) {
      _log.failure('notification_request_${error.runtimeType}');
      return NotificationPermission.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    // The plugin has no settings intent, so asking again is the closest thing
    // Android offers from inside the app. Once the user has refused twice,
    // Android stops showing the dialog and the switch in system settings is
    // the only way back — which the copy tells them.
    await request();
  }
}

/// Used where no platform exists: tests, and any build without notifications.
final class AlwaysGrantedNotificationPermission
    implements NotificationPermissionGateway {
  const AlwaysGrantedNotificationPermission();

  @override
  Future<NotificationPermission> status() async =>
      NotificationPermission.notRequired;

  @override
  Future<NotificationPermission> request() async =>
      NotificationPermission.notRequired;

  @override
  Future<void> openSettings() async {}
}
