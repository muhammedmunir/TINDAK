import 'package:flutter/material.dart';

import 'package:tindak/features/intake/incoming_text.dart';

/// Shows the text TINDAK just received, from either intake path.
///
/// Identical presentation for a share and a paste — the user is looking at
/// their own text and does not need to be told which door it came through.
///
/// M2 and M2.1 prove the entry points and nothing more. There is no detection,
/// no action and no Save on this screen yet: those arrive at M3, M4 and M5a.
///
/// Full-screen, not an overlay over the source app (PD-013).
///
/// The text is untrusted input from another app or from the clipboard. It is
/// rendered as plain characters through a [Text] widget: no markup is
/// interpreted, no link is made tappable, and there is no WebView anywhere in
/// TINDAK.
class IntakeResultScreen extends StatelessWidget {
  const IntakeResultScreen({required this.incoming, this.onClose, super.key});

  /// Beyond this, only the first [displayLimit] characters are drawn.
  ///
  /// Matches the understanding cap in PD-028, and applies to both intake paths
  /// — a clipboard can hold as much as an intent can. Laying out a very large
  /// string in one text run would drop frames for no benefit; nobody reads
  /// 200,000 characters on a phone.
  static const int displayLimit = 10000;

  final IncomingText incoming;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClipped = incoming.characterCount > displayLimit;
    final shown = isClipped
        ? incoming.text.substring(0, displayLimit)
        : incoming.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TINDAK'),
        leading: onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Tutup',
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Diterima',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(shown, style: theme.textTheme.bodyLarge),
              if (isClipped) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Menunjukkan $displayLimit aksara pertama '
                  'daripada ${incoming.characterCount}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
