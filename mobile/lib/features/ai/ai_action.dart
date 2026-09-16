import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart' as actions;
import 'package:tindak/features/ai/ai_copy.dart';
import 'package:tindak/features/ai/ai_providers.dart';
import 'package:tindak/features/ai/ai_result_screen.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/ai/service/ai_understanding_service.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/reminders/widgets/reminder_actions.dart';
import 'package:tindak/features/security/security_check_action.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Runs an AI request because the user pressed **Cuba dengan AI**.
///
/// **Only from that button.** Not on share, not on paste, not on detection, not
/// on save, not on resume, and never in the background. AI is a fallback the
/// user chooses, not a stage in the pipeline (ADR-006).
///
/// The order here is the privacy contract, and it is checked before a single
/// character is prepared:
///
/// ```text
/// provider configured? → short enough? → signed in? → agreed? → send
/// ```
///
/// A build with no provider never asks anyone to sign in, because a sign-in
/// prompt is a promise TINDAK could not keep. Text over the cap is refused
/// before sign-in for the same reason. Consent is asked last, immediately
/// before the only moment it means anything.
Future<void> runAiUnderstanding(
  BuildContext context,
  WidgetRef ref, {
  required IncomingText incoming,
  required UnderstandingResult understanding,
}) async {
  final service = ref.read(aiUnderstandingServiceProvider);

  // The text that is measured is the text that is sent, and it is the text the
  // disclosure described: normalised once, by the engine, and not re-derived
  // here (brief §6).
  final text = understanding.content.text;

  var blocker = await service.blocker(text);
  if (!context.mounted) return;

  if (blocker == AiBlocker.signInRequired) {
    if (!await _askSignIn(context)) return;
    if (!context.mounted) return;

    final signedIn = await Navigator.of(context).pushNamed<bool>(Routes.signIn);
    if (!context.mounted || signedIn != true) return;

    blocker = await service.blocker(text);
    if (!context.mounted) return;
  }

  if (blocker == AiBlocker.consentRequired) {
    final agreed = await _askDisclosure(context);
    if (!context.mounted) return;
    if (!agreed) {
      // Nothing has been sent and nothing is remembered: the screen stands as
      // it was, and the sheet appears again next time.
      return;
    }
    await ref.read(aiDisclosureProvider).accept();
    if (!context.mounted) return;
    blocker = null;
  }

  if (blocker != null) {
    _say(context, _blockedMessage(blocker));
    return;
  }

  // Only now does anything leave the device. The screen opens immediately and
  // fills in when the answer arrives, so a slow provider never leaves the user
  // looking at nothing.
  await Navigator.of(context).push(
    AiResultScreen.route(
      pending: service.understand(text),
      onAction: (actionContext, action, aiEntities) => _runAction(
        actionContext,
        ref,
        action,
        aiEntities,
        incoming: incoming,
        understanding: understanding,
      ),
    ),
  );
}

String _blockedMessage(AiBlocker blocker) => switch (blocker) {
  AiBlocker.notConfigured => AiCopy.notConfigured,
  AiBlocker.tooLong => AiCopy.tooLong,
  AiBlocker.signInRequired => AiCopy.signInRequired,
  AiBlocker.consentRequired => AiCopy.notConfigured,
};

/// An AI entity takes exactly the same road out as a locally detected one.
///
/// When the action is one that persists — a reminder — the memory is saved with
/// the AI entity included, because that is the entity the user acted on
/// (brief §16: AI results become stored data only through the routes that
/// already exist).
Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  ActionDescriptor action,
  List<DetectedEntity> aiEntities, {
  required IncomingText incoming,
  required UnderstandingResult understanding,
}) {
  switch (action.kind) {
    case ActionKind.securityCheck:
      return runSecurityCheck(context, ref, action.entity);
    case ActionKind.remind:
      return setReminderForEntity(
        context,
        ref,
        action.entity,
        incoming: incoming,
        understanding: AiUnderstandingService.merge(understanding, aiEntities),
      );
    case ActionKind.call:
    case ActionKind.whatsapp:
    case ActionKind.openUrl:
    case ActionKind.copy:
      return actions.runActionWithFeedback(context, ref, action);
  }
}

/// PD-023: a guest sees the control and is offered the way in, rather than
/// finding it missing and concluding TINDAK has no AI.
Future<bool> _askSignIn(BuildContext context) async {
  final wants = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text(AiCopy.signInRequired),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('ai-sign-in-not-now'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AiCopy.notNowAction),
        ),
        FilledButton(
          key: const ValueKey<String>('ai-sign-in'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AiCopy.signInAction),
        ),
      ],
    ),
  );
  return wants ?? false;
}

/// PD-011, PD-024. Asked once per installation, and again whenever the promise
/// itself changes — `AiDisclosure.requiredVersion`.
Future<bool> _askDisclosure(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(AiCopy.disclosureTitle),
      content: const Text(AiCopy.disclosureBody),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('ai-disclosure-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AiCopy.cancelAction),
        ),
        FilledButton(
          key: const ValueKey<String>('ai-disclosure-continue'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AiCopy.continueAction),
        ),
      ],
    ),
  );
  return agreed ?? false;
}

void _say(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));
