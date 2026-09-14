import 'package:flutter/material.dart';

import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Shows the text TINDAK received, what it understood, and what the user can
/// do with each thing it found.
///
/// Identical presentation for a share and a paste — the user is looking at
/// their own text and does not need to be told which door it came through.
///
/// **Every external action is a visible, labelled button the user presses.**
/// Nothing launches on render, on detection, or on resume. The entity row
/// itself is not a tap target: a user who taps a phone number to read it must
/// not find the dialer open. Save, Security Check and Try AI are later
/// milestones and do not appear here.
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

  final IncomingText incoming;
  final UnderstandingResult? understanding;

  /// Called when the user presses an action button. When null, no action
  /// buttons are shown at all.
  final void Function(ActionDescriptor action)? onAction;
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
                    _EntityRow(
                      entity: entity,
                      actions: onAction == null
                          ? const <ActionDescriptor>[]
                          : resolver.resolve(entity),
                      onAction: onAction,
                    ),
                ],
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

/// One detected entity and its actions.
///
/// The row is not tappable. Only the labelled buttons beneath it act, and each
/// button carries its own entity — so in a message with two numbers, Call on
/// the second row can only dial the second number.
class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.entity,
    required this.actions,
    required this.onAction,
  });

  final DetectedEntity entity;
  final List<ActionDescriptor> actions;
  final void Function(ActionDescriptor action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String label, String value) = switch (entity.type) {
      EntityType.phone => (Icons.phone_outlined, 'Telefon', entity.rawValue),
      // UX section 6 shows the host. It is the part of a link that decides
      // where it really goes, and the part a lookalike tries to disguise.
      EntityType.url => (Icons.link, 'Pautan', _hostOf(entity.normalizedValue)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: theme.textTheme.bodyLarge),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final action in actions)
                        OutlinedButton.icon(
                          key: ValueKey<String>(
                            'action-${action.kind.name}-${entity.start}',
                          ),
                          onPressed: () => onAction?.call(action),
                          icon: Icon(_iconFor(action.kind), size: 18),
                          label: Text(_labelFor(action.kind)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Malay labels, approved by Product Direction at the M4 review (PD-037).
  /// WhatsApp is a brand name and stays as it is.
  static String _labelFor(ActionKind kind) => switch (kind) {
    ActionKind.call => 'Panggil',
    ActionKind.whatsapp => 'WhatsApp',
    ActionKind.openUrl => 'Buka',
  };

  static IconData _iconFor(ActionKind kind) => switch (kind) {
    ActionKind.call => Icons.call_outlined,
    ActionKind.whatsapp => Icons.chat_outlined,
    ActionKind.openUrl => Icons.open_in_new,
  };

  static String _hostOf(String url) {
    final host = Uri.tryParse(url)?.host;
    return (host == null || host.isEmpty) ? url : host;
  }
}
