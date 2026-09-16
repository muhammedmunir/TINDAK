import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/money_value.dart';

/// Shown when an action could not be carried out (PD-037).
///
/// One quiet line. The screen stays open, so the user can still read the
/// number or link and use it another way.
const String actionUnavailableMessage =
    'Tindakan ini tidak dapat dibuka pada peranti ini.';

/// Shown only after the clipboard has actually accepted the value (M6b).
const String copiedMessage = 'Disalin.';

/// Kept only for the case where a date action arrives with no reminder flow
/// behind it, which no shipped screen does since M7b.
const String reminderComingSoonMessage =
    'Peringatan akan tersedia dalam kemas kini akan datang.';

/// Runs an action because the user pressed its button, and reports a failure
/// quietly. Shared by the result screen and Memory detail, so a saved number
/// behaves exactly like a freshly shared one.
///
/// TINDAK is never closed afterwards (PD-014).
Future<void> runActionWithFeedback(
  BuildContext context,
  WidgetRef ref,
  ActionDescriptor action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await ref.read(actionRunnerProvider).run(action);

  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  switch (outcome) {
    case ActionOutcome.launched:
    case ActionOutcome.busy:
      return;
    // Said after the write succeeded, never before it (M6b).
    case ActionOutcome.copied:
      say(copiedMessage);
    case ActionOutcome.notYetAvailable:
      say(reminderComingSoonMessage);
    case ActionOutcome.rejected:
    case ActionOutcome.unavailable:
      say(actionUnavailableMessage);
  }
}

/// One detected entity and its actions.
///
/// The row is not tappable. Only the labelled buttons beneath it act, and each
/// button carries its own entity — so in a message with two numbers, Panggil on
/// the second row can only dial the second number.
class EntityRow extends StatelessWidget {
  const EntityRow({
    required this.entity,
    required this.actions,
    required this.onAction,
    super.key,
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
      EntityType.url => (Icons.link, 'Pautan', hostOf(entity.normalizedValue)),
      EntityType.money => (
        Icons.payments_outlined,
        'Wang',
        displayValue(entity),
      ),
      EntityType.date => (
        Icons.event_outlined,
        'Tarikh',
        displayValue(entity),
      ),
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

  /// What a person sees for an entity in a compact summary, e.g. a Memory list
  /// row.
  static String displayValue(DetectedEntity entity) => switch (entity.type) {
    EntityType.phone => entity.rawValue,
    EntityType.url => hostOf(entity.normalizedValue),
    // Canonical, not as typed: `rm25` reads as `RM25.00`, and a date always
    // shows its full resolved year (PD approvals A-2 and A-3). A value this
    // build cannot read falls back to the text the user wrote.
    EntityType.money =>
      MoneyValue.parse(entity.normalizedValue)?.display ?? entity.rawValue,
    EntityType.date =>
      DateValue.parse(entity.normalizedValue)?.display ?? entity.rawValue,
  };

  static String hostOf(String url) {
    final host = Uri.tryParse(url)?.host;
    return (host == null || host.isEmpty) ? url : host;
  }

  /// Malay labels, approved by Product Direction at the M4 review (PD-037).
  /// WhatsApp is a brand name and stays as it is.
  static String _labelFor(ActionKind kind) => switch (kind) {
    ActionKind.call => 'Panggil',
    ActionKind.whatsapp => 'WhatsApp',
    ActionKind.openUrl => 'Buka',
    ActionKind.copy => 'Salin',
    ActionKind.remind => 'Ingatkan',
    ActionKind.securityCheck => SecurityCopy.checkAction,
  };

  static IconData _iconFor(ActionKind kind) => switch (kind) {
    ActionKind.call => Icons.call_outlined,
    ActionKind.whatsapp => Icons.chat_outlined,
    ActionKind.openUrl => Icons.open_in_new,
    ActionKind.copy => Icons.content_copy_outlined,
    ActionKind.remind => Icons.notifications_none,
    ActionKind.securityCheck => Icons.shield_outlined,
  };
}
