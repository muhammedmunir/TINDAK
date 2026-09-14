import 'package:flutter/material.dart';

import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Shows the text TINDAK received, what it understood, what the user can do
/// with each thing it found, and the option to keep it.
///
/// Identical presentation for a share and a paste — the user is looking at
/// their own text and does not need to be told which door it came through.
///
/// **Every external action, and saving, is a visible button the user
/// presses.** Nothing launches or saves on render, on detection, or on resume.
/// The entity row itself is not a tap target.
///
/// Full-screen, not an overlay over the source app (PD-013).
///
/// All text here is untrusted input from another app or the clipboard, and is
/// rendered as plain characters through [Text] widgets. No markup is
/// interpreted and there is no WebView anywhere in TINDAK.
class IntakeResultScreen extends StatelessWidget {
  const IntakeResultScreen({
    required this.incoming,
    this.understanding,
    this.onAction,
    this.onSave,
    this.onClose,
    this.resolver = const ActionResolver(),
    super.key,
  });

  /// Beyond this, only the first [displayLimit] characters are drawn.
  ///
  /// Matches the understanding cap in PD-028 and applies to both intake paths.
  static const int displayLimit = 10000;

  /// Approved copy, PRD section 18.
  static const String nothingDetectedMessage =
      'TINDAK belum dapat mengenal pasti tindakan untuk kandungan ini.';

  static const String saveLabel = 'Simpan';

  final IncomingText incoming;
  final UnderstandingResult? understanding;

  /// Called when the user presses an action button. When null, no action
  /// buttons are shown at all.
  final void Function(ActionDescriptor action)? onAction;

  /// Called when the user presses Simpan. When null, Simpan is not shown.
  final VoidCallback? onSave;

  final VoidCallback? onClose;
  final ActionResolver resolver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClipped = incoming.characterCount > displayLimit;
    final shown = isClipped
        ? incoming.text.substring(0, displayLimit)
        : incoming.text;
    final result = understanding;

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
              const _SectionLabel('Diterima'),
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
              if (result != null) ...<Widget>[
                const SizedBox(height: 28),
                if (result.isEmpty)
                  Text(
                    nothingDetectedMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...<Widget>[
                  const _SectionLabel('Dikesan'),
                  const SizedBox(height: 8),
                  for (final entity in result.entities)
                    EntityRow(
                      entity: entity,
                      actions: onAction == null
                          ? const <ActionDescriptor>[]
                          : resolver.resolve(entity),
                      onAction: onAction,
                    ),
                ],
              ],
              // Saving is offered whether or not anything was detected: plain
              // text is worth remembering too (PRD section 18).
              if (onSave != null) ...<Widget>[
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text(saveLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
