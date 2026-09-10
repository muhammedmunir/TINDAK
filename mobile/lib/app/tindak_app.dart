import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/share/share_controller.dart';
import 'package:tindak/features/share/share_result_screen.dart';
import 'package:tindak/features/share/shared_text.dart';

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
    // Subscribes to shares and collects the one that launched the app.
    // Deliberately not awaited: the shell paints immediately and the share
    // arrives when the platform answers.
    unawaited(ref.read(shareControllerProvider.notifier).start());
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
        Routes.home: (_) => const ShareGate(),
      },
    );
  }
}

/// Shows the share result when there is one, otherwise Home.
///
/// A swap rather than a pushed route, so a second share while a result is on
/// screen replaces it instead of stacking another screen behind it
/// (docs/10_ARCHITECTURE.md section 9.3).
class ShareGate extends ConsumerWidget {
  const ShareGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SharedText? share = ref.watch(shareControllerProvider);

    if (share == null) return const HomeScreen();

    return ShareResultScreen(
      share: share,
      onClose: () => ref.read(shareControllerProvider.notifier).clear(),
    );
  }
}
