import 'package:flutter/material.dart';

import 'package:tindak/features/share/shared_text.dart';

/// Shows the text TINDAK just received.
///
/// M2 proves the entry point and nothing more. There is no detection, no
/// action and no Save on this screen yet — those arrive at M3, M4 and M5a.
///
/// Full-screen, not an overlay over the source app (PD-013).
///
/// The text is untrusted input from another app. It is rendered as plain
/// characters through a [Text] widget: no markup is interpreted, no link is
/// made tappable, and there is no WebView anywhere in TINDAK.
class ShareResultScreen extends StatelessWidget {
  const ShareResultScreen({required this.share, this.onClose, super.key});

  /// Beyond this, only the first [displayLimit] characters are drawn.
  ///
  /// Matches the understanding cap in PD-028. An intent can carry a very large
  /// string, and laying all of it out in one text run would drop frames for no
  /// benefit — nobody reads 200,000 characters on a phone.
  static const int displayLimit = 10000;

  final SharedText share;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClipped = share.characterCount > displayLimit;
    final shown = isClipped
        ? share.text.substring(0, displayLimit)
        : share.text;

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
              SelectableText(
                shown,
                style: theme.textTheme.bodyLarge,
              ),
              if (isClipped) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Menunjukkan $displayLimit aksara pertama '
                  'daripada ${share.characterCount}.',
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
