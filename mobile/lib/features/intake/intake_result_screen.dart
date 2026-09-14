import 'package:flutter/material.dart';

import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Shows the text TINDAK received and what it understood.
///
/// Identical presentation for a share and a paste — the user is looking at
/// their own text and does not need to be told which door it came through.
///
/// **M3 displays understanding only.** Nothing on this screen calls, opens a
/// link, checks security, or saves. No detected value is tappable. Those are
/// M4, M5a and M8; this milestone proves TINDAK understands, the next proves
/// it acts.
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
    this.onClose,
    super.key,
  });

  /// Beyond this, only the first [displayLimit] characters are drawn.
  ///
  /// Matches the understanding cap in PD-028 and applies to both intake paths.
  /// Laying out a very large string in one text run would drop frames for no
  /// benefit; nobody reads 200,000 characters on a phone.
  static const int displayLimit = 10000;

  /// Approved copy, PRD section 18.
  static const String nothingDetectedMessage =
      'TINDAK belum dapat mengenal pasti tindakan untuk kandungan ini.';

  final IncomingText incoming;
  final UnderstandingResult? understanding;
  final VoidCallback? onClose;

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
              _SectionLabel('Diterima'),
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
                  _SectionLabel('Dikesan'),
                  const SizedBox(height: 8),
                  for (final entity in result.entities)
                    _EntityRow(entity: entity),
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

/// One detected entity. Display only: no tap target, no action (M3 boundary).
class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.entity});

  final DetectedEntity entity;

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
          Icon(icon, size: 22, color: theme.colorScheme.primary),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hostOf(String url) {
    final host = Uri.tryParse(url)?.host;
    return (host == null || host.isEmpty) ? url : host;
  }
}
