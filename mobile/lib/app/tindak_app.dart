import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/intake/intake_understanding.dart';

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
      understanding: ref.watch(intakeUnderstandingProvider),
      onAction: (action) => _runAction(context, ref, action),
      onClose: () => ref.read(intakeControllerProvider.notifier).clear(),
    );
  }

  /// Shown when an action could not be carried out.
  ///
  /// One quiet line. TINDAK stays open and the result stays on screen, so the
  /// user can still read the number or link and use it another way.
  static const String actionUnavailableMessage =
      'Tindakan ini tidak dapat dibuka pada peranti ini.';

  /// Runs an action because the user pressed its button — the only path by
  /// which TINDAK launches another app.
  ///
  /// TINDAK is never closed afterwards. Android keeps it in recents and the
  /// back gesture returns to this result (PD-014).
  static Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    ActionDescriptor action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(actionRunnerProvider).run(action);

    switch (outcome) {
      case ActionOutcome.launched:
      case ActionOutcome.busy:
        return;
      case ActionOutcome.rejected:
      case ActionOutcome.unavailable:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(actionUnavailableMessage)),
          );
    }
  }
}
