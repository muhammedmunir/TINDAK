import 'package:flutter/material.dart';

/// Home and empty state.
///
/// Minimal by design. UX flows section 4 and PRD section 19 both rule out a
/// dashboard: the product's entry point is the Android share sheet, not this
/// screen.
///
/// Until M5a there is nothing saved to list, so this screen shows only the
/// empty state. The copy is the approved wording from docs/03_UX_FLOWS.md
/// section 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                'Tekan Share dalam WhatsApp, browser\natau app lain dan pilih TINDAK.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
