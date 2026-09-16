import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/security/security_providers.dart';
import 'package:tindak/features/security/security_result_screen.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// Runs a security check because the user pressed Semak Keselamatan (PD-012).
///
/// **Only from that button.** Not on detection, not on save, not on open, and
/// never in the background (M8 scope lock).
///
/// The order here is the privacy contract: the local checks run first and
/// always; the online check runs only after an account, an agreement and a
/// provider are all in place — and the agreement is asked for **before** the
/// first URL is ever sent (C-6).
Future<void> runSecurityCheck(
  BuildContext context,
  WidgetRef ref,
  DetectedEntity url,
) async {
  final checker = ref.read(securityCheckerProvider);
  final local = checker.local(url);

  final blocker = await checker.onlineBlocker();
  if (!context.mounted) return;

  if (blocker == OnlineCheckStatus.disclosureRequired) {
    final agreed = await _askDisclosure(context);
    if (!context.mounted) return;

    if (!agreed) {
      // Nothing has been sent, and nothing is remembered: the local result
      // stands on its own and the sheet appears again next time.
      await _show(context, url, _withStatus(local, blocker!));
      return;
    }
    await ref.read(onlineCheckDisclosureProvider).accept();
    if (!context.mounted) return;
  } else if (blocker != null) {
    await _show(context, url, _withStatus(local, blocker));
    return;
  }

  // Only now does the URL leave the device. The screen opens straight away
  // with the local result, and fills in the online line when it arrives, so a
  // slow provider never leaves the user looking at nothing.
  await _show(context, url, local, pending: checker.check(url));
}

Future<bool> _askDisclosure(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(SecurityCopy.disclosureTitle),
      content: const Text(SecurityCopy.disclosureBody),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('disclosure-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(SecurityCopy.cancelAction),
        ),
        FilledButton(
          key: const ValueKey<String>('disclosure-continue'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(SecurityCopy.disclosureContinue),
        ),
      ],
    ),
  );
  return agreed ?? false;
}

SecurityAssessment _withStatus(
  SecurityAssessment local,
  OnlineCheckStatus status,
) => SecurityAssessment(
  url: local.url,
  level: local.level,
  findings: local.findings,
  onlineStatus: status,
);

Future<void> _show(
  BuildContext context,
  DetectedEntity url,
  SecurityAssessment assessment, {
  Future<SecurityAssessment>? pending,
}) => Navigator.of(context).push(
  SecurityResultScreen.route(
    entity: url,
    assessment: assessment,
    pending: pending,
  ),
);
