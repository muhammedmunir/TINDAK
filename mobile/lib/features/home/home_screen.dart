import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/intake/intake_controller.dart';

/// Home and empty state.
///
/// Minimal by design. UX flows section 4 and PRD section 19 both rule out a
/// dashboard: the product's entry points are the Android share sheet and the
/// Tampal control on this screen, not a place users come to browse.
///
/// Until M5a there is nothing saved to list, so this screen shows only the
/// empty state. The copy is the approved wording from docs/03_UX_FLOWS.md
/// section 4.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Shown when the clipboard holds nothing TINDAK can use.
  ///
  /// One quiet line for every unusable case — empty, whitespace, an image, or a
  /// clipboard that could not be read. The user does not need TINDAK's
  /// taxonomy of failure, and a dramatic error here would be out of proportion
  /// to pressing a button and nothing happening.
  static const String nothingToPasteMessage = 'Tiada teks untuk ditampal.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('TINDAK')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.share_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Jumpa maklumat penting?',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Share ke TINDAK, atau salin teks\ndan tampal di sini.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _paste(context, ref),
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('Tampal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The only path in TINDAK that reads the clipboard, and it runs only from
  /// this button (PD-033, ADR-004).
  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(intakeControllerProvider.notifier).paste();

    if (outcome == PasteOutcome.accepted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(nothingToPasteMessage)),
      );
  }
}
