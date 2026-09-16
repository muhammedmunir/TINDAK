import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart' as actions;
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/sign_in_screen.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/intake/intake_understanding.dart';
import 'package:tindak/features/memory/memory_detail_screen.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/settings/settings_screen.dart';
import 'package:tindak/features/sync/sync_providers.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// The application shell.
class TindakApp extends ConsumerStatefulWidget {
  const TindakApp({super.key});

  @override
  ConsumerState<TindakApp> createState() => _TindakAppState();
}

class _TindakAppState extends ConsumerState<TindakApp> {
  late final AppLifecycleListener _lifecycle;

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

    // Resume is a sync trigger (docs/10_ARCHITECTURE.md section 8.1). Sync
    // moves only changes the user already made; it reads no clipboard and
    // saves nothing new.
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(ref.read(syncControllerProvider.notifier).requestSync()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the sync controller alive, so a session restored at launch or a
    // new sign-in starts a sync.
    ref.watch(syncControllerProvider);

    return MaterialApp(
      title: 'TINDAK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: Routes.home,
      routes: <String, WidgetBuilder>{
        Routes.home: (_) => const IntakeGate(),
        Routes.settings: (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        // Typed, because the caller awaits a bool. A route from the table
        // above is Route<dynamic>, and pushNamed<bool> on it throws.
        if (settings.name == Routes.signIn) {
          return MaterialPageRoute<bool>(
            settings: settings,
            builder: (_) => const SignInScreen(),
          );
        }
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

  /// Signed in: saved on the device first, then synced (PD-042).
  static const String savedToAccountMessage =
      'Disimpan. Akan disync ke akaun anda.';
  static const String saveFailedMessage = 'Tidak dapat menyimpan. Cuba lagi.';

  /// PD-039. Says what the limit is, so the user knows what to change.
  static const String tooLongMessage =
      'Teks terlalu panjang untuk disimpan. Had ialah 10,000 aksara.';

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
      isSaving: ref.watch(memorySavingProvider),
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
    final signedIn = ref.read(currentAccountProvider) != null;
    final outcome = await ref
        .read(memorySaverProvider)
        .save(incoming: incoming, understanding: understanding);

    switch (outcome) {
      case SaveOutcome.busy:
        return;
      case SaveOutcome.saved:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(signedIn ? savedToAccountMessage : savedMessage),
            ),
          );
        // After the local commit, never before, and never awaited: the save
        // has already succeeded whatever the network does (PD-042).
        unawaited(ref.read(syncControllerProvider.notifier).requestSync());
      case SaveOutcome.tooLong:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(tooLongMessage)));
      case SaveOutcome.failed:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(saveFailedMessage)));
    }
  }
}
