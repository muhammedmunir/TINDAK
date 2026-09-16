import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// What a check found, and what the user can do about it (M8a).
///
/// Decision support, not a verdict the app acts on: TINDAK shows the level and
/// the reasons, and the person decides. Nothing here blocks a link — a link
/// with signs of risk asks once more, and then opens through the same M4 path
/// as any other (PD-014).
class SecurityResultScreen extends ConsumerStatefulWidget {
  const SecurityResultScreen({
    required this.entity,
    required this.assessment,
    this.pending,
    super.key,
  });

  final DetectedEntity entity;

  /// What the local checks found. Shown immediately.
  final SecurityAssessment assessment;

  /// The full check, when an online one is running. The screen shows the
  /// local result while it waits (M8b).
  final Future<SecurityAssessment>? pending;

  static Route<void> route({
    required DetectedEntity entity,
    required SecurityAssessment assessment,
    Future<SecurityAssessment>? pending,
  }) => MaterialPageRoute<void>(
    settings: const RouteSettings(name: Routes.securityResult),
    builder: (_) => SecurityResultScreen(
      entity: entity,
      assessment: assessment,
      pending: pending,
    ),
  );

  @override
  ConsumerState<SecurityResultScreen> createState() =>
      _SecurityResultScreenState();
}

class _SecurityResultScreenState extends ConsumerState<SecurityResultScreen> {
  late SecurityAssessment assessment = widget.assessment;
  bool _waiting = false;

  DetectedEntity get entity => widget.entity;

  @override
  void initState() {
    super.initState();
    final pending = widget.pending;
    if (pending == null) return;

    _waiting = true;
    pending.then((result) {
      if (!mounted) return;
      setState(() {
        assessment = result;
        _waiting = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = switch (assessment.level) {
      RiskLevel.low => scheme.primary,
      RiskLevel.caution => scheme.tertiary,
      RiskLevel.suspicious || RiskLevel.high => scheme.error,
    };

    return Scaffold(
      appBar: AppBar(title: const Text(SecurityCopy.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            SelectableText(
              EntityRow.hostOf(assessment.url),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              assessment.url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              SecurityCopy.levelLabel(assessment.level),
              key: const ValueKey<String>('security-level'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colour,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              SecurityCopy.reasonsHeading,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (assessment.findings.isEmpty)
              const _Line(SecurityCopy.noLocalFindings)
            else
              for (final finding in assessment.findings)
                _Line(SecurityCopy.reason(finding.code)),
            if (assessment.onlineFinding case final OnlineFindingCode code)
              _Line(SecurityCopy.onlineReason(code)),
            // Availability, stated separately from the risk level (C-1).
            _Line(
              _waiting
                  ? SecurityCopy.checking
                  : SecurityCopy.onlineStatus(assessment.onlineStatus),
            ),
            if (assessment.onlineStatus ==
                OnlineCheckStatus.signInRequired) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey<String>('security-sign-in'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.signIn),
                  child: const Text(SecurityCopy.signInAction),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              SecurityCopy.disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>('security-open'),
                  onPressed: () => _open(context, ref),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(SecurityCopy.openAction),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(SecurityCopy.closeAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the link through the **existing M4 path** (docs/12_SECURITY.md
  /// section 7). A clean check is never permission to open something M4
  /// refuses, and a risky one only adds a question — it does not block.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (assessment.needsConfirmationToOpen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text(SecurityCopy.riskyOpenQuestion),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(SecurityCopy.cancelAction),
            ),
            FilledButton(
              key: const ValueKey<String>('security-open-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(SecurityCopy.openAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    await runActionWithFeedback(
      context,
      ref,
      ActionDescriptor(kind: ActionKind.openUrl, entity: entity),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('•  ', style: theme.textTheme.bodyMedium),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
