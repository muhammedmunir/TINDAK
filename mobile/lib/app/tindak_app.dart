import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart' as actions;
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/intake/intake_understanding.dart';
import 'package:tindak/features/memory/memory_detail_screen.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

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
    // This reads no clipboard and saves nothing, and nothing on a lifecycle
    // path may (ADR-004, PD-003).
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
      onGenerateRoute: (settings) {
        final id = settings.arguments;
        if (settings.name == Routes.memoryDetail && id is String) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => MemoryDetailScreen(id: id),
          );
        }
        return null;
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

  /// Kept here for existing callers; the message lives with the shared action
  /// feedback.
  static const String actionUnavailableMessage =
      actions.actionUnavailableMessage;

  static const String savedMessage = 'Disimpan pada peranti ini.';
  static const String saveFailedMessage = 'Tidak dapat menyimpan. Cuba lagi.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A share or paste can arrive while a Memory detail is open. Bring the
    // user back to the root so they see what they just sent, instead of it
    // landing out of sight behind the detail screen.
    ref.listen<IncomingText?>(intakeControllerProvider, (previous, next) {
      if (next != null && previous != next) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final IncomingText? incoming = ref.watch(intakeControllerProvider);
    if (incoming == null) return const HomeScreen();

    final understanding = ref.watch(intakeUnderstandingProvider);

    return IntakeResultScreen(
      incoming: incoming,
      understanding: understanding,
      onAction: (action) => actions.runActionWithFeedback(context, ref, action),
      onSave: understanding == null
          ? null
          : () => _save(context, ref, incoming, understanding),
      onClose: () => ref.read(intakeControllerProvider.notifier).clear(),
    );
  }

  /// Saves because the user pressed Simpan — the only path by which a memory
  /// is created (PD-003).
  ///
  /// The result stays on screen afterwards. Pressing Simpan again saves again:
  /// two presses are two decisions, and nothing is deduplicated.
  static Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    IncomingText incoming,
    UnderstandingResult understanding,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(memorySaverProvider)
        .save(incoming: incoming, understanding: understanding);

    switch (outcome) {
      case SaveOutcome.busy:
        return;
      case SaveOutcome.saved:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(savedMessage)));
      case SaveOutcome.failed:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(saveFailedMessage)));
    }
  }
}
