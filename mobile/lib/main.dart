import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:tindak/app/cloud_bootstrap.dart';
import 'package:tindak/app/reminder_bootstrap.dart';
import 'package:tindak/app/tindak_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloud = await CloudBootstrap.start();
  final reminders = await ReminderBootstrap.start();

  runApp(
    ProviderScope(
      overrides: <Override>[...cloud, ...reminders.overrides],
      child: TindakApp(openedMemoryId: reminders.openedMemoryId),
    ),
  );
}
