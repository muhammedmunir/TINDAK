import 'package:flutter/material.dart';

import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/ai/ai_copy.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/ai/model/ai_result.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// What the AI found, if anything.
///
/// Every row here is an ordinary [EntityRow] with ordinary actions, resolved by
/// the ordinary [ActionResolver]. That is the point: an AI-derived phone number
/// reaches Panggil through exactly the code a locally detected one does, and
/// meets exactly the same refusals at `ActionUriBuilder`.
///
/// The screen shows the span from the user's own message as the value, so what
/// is on screen is always something they wrote or received — never the model's
/// paraphrase of it.
class AiResultScreen extends StatelessWidget {
  const AiResultScreen({
    required this.pending,
    required this.onAction,
    this.resolver = const ActionResolver(),
    super.key,
  });

  static Route<void> route({
    required Future<AiResult> pending,
    required void Function(
      BuildContext context,
      ActionDescriptor action,
      List<DetectedEntity> aiEntities,
    )
    onAction,
  }) => MaterialPageRoute<void>(
    builder: (_) => AiResultScreen(pending: pending, onAction: onAction),
  );

  final Future<AiResult> pending;
  final void Function(
    BuildContext context,
    ActionDescriptor action,
    List<DetectedEntity> aiEntities,
  )
  onAction;
  final ActionResolver resolver;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(AiCopy.title),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: AiCopy.closeAction,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<AiResult>(
        future: pending,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) return const _Working();
          return _Body(
            result: result,
            resolver: resolver,
            onAction: onAction,
          );
        },
      ),
    ),
  );
}

class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 16),
        Text(AiCopy.working, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.result,
    required this.resolver,
    required this.onAction,
  });

  final AiResult result;
  final ActionResolver resolver;
  final void Function(
    BuildContext context,
    ActionDescriptor action,
    List<DetectedEntity> aiEntities,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String? message = switch (result) {
      AiNothingUsable() => AiCopy.nothingFound,
      AiUnavailableResult(failure: final failure) => AiCopy.failure(failure),
      // A gate closed after the request was already on its way — the text was
      // never sent, and the honest line is the one for that gate.
      AiBlocked(blocker: final blocker) => switch (blocker) {
        AiBlocker.notConfigured => AiCopy.notConfigured,
        AiBlocker.tooLong => AiCopy.tooLong,
        AiBlocker.signInRequired => AiCopy.signInRequired,
        AiBlocker.consentRequired => AiCopy.notConfigured,
      },
      AiEntitiesFound() => null,
    };

    if (message != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final entities = (result as AiEntitiesFound).entities;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AiCopy.resultHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final entity in entities)
            EntityRow(
              entity: entity,
              actions: resolver.resolve(entity),
              onAction: (action) => onAction(context, action, entities),
            ),
          const SizedBox(height: 24),
          Text(
            AiCopy.disclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
