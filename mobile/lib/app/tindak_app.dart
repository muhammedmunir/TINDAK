import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';

/// The application shell.
class TindakApp extends ConsumerStatefulWidget {
  const TindakApp({super.key});

  @override
  ConsumerState<TindakApp> createState() => _TindakAppState();
}

class _TindakAppState extends ConsumerState<TindakApp> {
  @override
  void initState() {
    super.initState();
    // Subscribes to Android shares and collects the one that launched the app.
    // Deliberately not awaited: the shell paints immediately and the share
    // arrives when the platform answers.
    //
    // This reads no clipboard, and nothing on a lifecycle path may (ADR-004).
    unawaited(ref.read(intakeControllerProvider.notifier).start());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TINDAK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: Routes.home,
      routes: <String, WidgetBuilder>{
        Routes.home: (_) => const IntakeGate(),
      },
    );
  }
}

/// Shows the result when text has arrived, otherwise Home.
///
/// A swap rather than a pushed route, so a second share while a result is on
/// screen replaces it instead of stacking another screen behind it
/// (docs/10_ARCHITECTURE.md section 9.3).
class IntakeGate extends ConsumerWidget {
  const IntakeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IncomingText? incoming = ref.watch(intakeControllerProvider);

    if (incoming == null) return const HomeScreen();

    return IntakeResultScreen(
      incoming: incoming,
      onClose: () => ref.read(intakeControllerProvider.notifier).clear(),
    );
  }
}
