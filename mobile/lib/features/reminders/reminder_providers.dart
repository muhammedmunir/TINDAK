import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/reminders/data/notification_permission.dart';
import 'package:tindak/features/reminders/data/reminder_repository.dart';
import 'package:tindak/features/reminders/data/reminder_scheduler.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/reminders/reminder_reconciler.dart';
import 'package:tindak/features/reminders/reminder_service.dart';

/// The notifications plugin. Overridden in tests, which never touch a
/// platform channel.
final Provider<FlutterLocalNotificationsPlugin> notificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => FlutterLocalNotificationsPlugin(),
    );

/// The device scheduler. `main.dart` overrides this with the real one once
/// the plugin has been initialised; the default schedules nothing, so a build
/// that never initialised notifications cannot pretend to deliver them.
final Provider<ReminderScheduler> reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());

final Provider<NotificationPermissionGateway> notificationPermissionProvider =
    Provider<NotificationPermissionGateway>(
      (ref) => const AlwaysGrantedNotificationPermission(),
    );

final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>(
      (ref) => DriftReminderRepository(
        ref.watch(databaseProvider),
        clock: ref.watch(clockProvider),
        memories: ref.watch(memoryRepositoryProvider),
      ),
    );

final Provider<ReminderReconciler> reminderReconcilerProvider =
    Provider<ReminderReconciler>(
      (ref) => ReminderReconciler(
        repository: ref.watch(reminderRepositoryProvider),
        scheduler: ref.watch(reminderSchedulerProvider),
        clock: ref.watch(clockProvider),
      ),
    );

final Provider<ReminderService> reminderServiceProvider =
    Provider<ReminderService>(
      (ref) => ReminderService(
        repository: ref.watch(reminderRepositoryProvider),
        scheduler: ref.watch(reminderSchedulerProvider),
        permission: ref.watch(notificationPermissionProvider),
        reconciler: ref.watch(reminderReconcilerProvider),
      ),
    );

/// A memory's reminders: the active one, if any, and the history that keeps a
/// fired reminder visible (B-4).
final remindersForMemoryProvider = StreamProvider.autoDispose
    .family<List<ReminderRecord>, String>(
      (ref, memoryId) =>
          ref.watch(reminderRepositoryProvider).watchFor(memoryId),
    );

/// Whether this device will actually deliver reminders.
final FutureProvider<ReminderPermissionState> reminderPermissionProvider =
    FutureProvider<ReminderPermissionState>(
      (ref) => ref.watch(reminderServiceProvider).permissionState(),
    );
