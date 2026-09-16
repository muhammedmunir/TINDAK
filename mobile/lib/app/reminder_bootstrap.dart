import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/reminders/data/local_notification_scheduler.dart';
import 'package:tindak/features/reminders/data/notification_permission.dart';
import 'package:tindak/features/reminders/reminder_providers.dart';

/// Starts the notification plugin and reports how the app was opened.
final class ReminderStartup {
  const ReminderStartup({required this.overrides, this.openedMemoryId});

  /// Provider overrides wiring the real scheduler and permission gateway.
  final List<Override> overrides;

  /// The memory whose notification the user tapped to launch TINDAK, if any.
  final String? openedMemoryId;
}

/// Prepares reminder delivery for the running app.
///
/// Never fatal. If the plugin cannot start, TINDAK runs with no scheduler:
/// reminders can still be created, kept and shown, and the reconciler
/// schedules them once delivery works again. A reminder is a saved decision;
/// the alarm behind it is a device service that may be unavailable.
final class ReminderBootstrap {
  const ReminderBootstrap._();

  static const AppLogger _log = AppLogger('reminders');

  /// Set when the user taps a notification while TINDAK is running. The shell
  /// listens and opens the memory.
  static final ValueNotifier<String?> tappedMemoryId =
      ValueNotifier<String?>(null);

  static Future<ReminderStartup> start() async {
    final plugin = FlutterLocalNotificationsPlugin();

    try {
      LocalNotificationScheduler.prepareTimeZones();

      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        // The payload is a memory id and nothing else: no content, no number,
        // no link (M7 privacy contract).
        onDidReceiveNotificationResponse: (response) =>
            tappedMemoryId.value = response.payload,
      );

      // A notification that started the app cold, rather than while running.
      final launch = await plugin.getNotificationAppLaunchDetails();
      final openedMemoryId =
          (launch?.didNotificationLaunchApp ?? false)
          ? launch?.notificationResponse?.payload
          : null;

      return ReminderStartup(
        overrides: <Override>[
          notificationsPluginProvider.overrideWithValue(plugin),
          reminderSchedulerProvider.overrideWithValue(
            LocalNotificationScheduler(plugin),
          ),
          notificationPermissionProvider.overrideWithValue(
            AndroidNotificationPermission(plugin),
          ),
        ],
        openedMemoryId: openedMemoryId,
      );
    } on Object catch (error, stackTrace) {
      _log.failure(
        'reminder_bootstrap_failed_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return const ReminderStartup(overrides: <Override>[]);
    }
  }
}
