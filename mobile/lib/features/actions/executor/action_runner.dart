import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/resolver/action_uri_builder.dart';

final Provider<ExternalLauncher> externalLauncherProvider =
    Provider<ExternalLauncher>((ref) => const UrlLauncherExternalLauncher());

final Provider<ActionResolver> actionResolverProvider =
    Provider<ActionResolver>((ref) => const ActionResolver());

final Provider<ActionRunner> actionRunnerProvider = Provider<ActionRunner>(
  (ref) => ActionRunner(ref.watch(externalLauncherProvider)),
);

/// What happened when the user tapped an action.
enum ActionOutcome {
  /// Android started an app for it.
  launched,

  /// The value failed validation. Nothing was launched.
  rejected,

  /// No app could handle it, or the platform refused. Nothing was launched.
  unavailable,

  /// Another action was still starting. Ignored rather than launched twice.
  busy,
}

/// Runs an action the user explicitly tapped.
///
/// **This is called from a button's `onPressed` and from nowhere else.** Not on
/// render, not on resume, not when an entity is detected, not when a share
/// arrives. Detection offers actions; only a tap takes one.
final class ActionRunner {
  ActionRunner(this._launcher, {ActionUriBuilder builder = const ActionUriBuilder()})
    : _builder = builder;

  final ExternalLauncher _launcher;
  final ActionUriBuilder _builder;

  bool _inFlight = false;

  static const AppLogger _log = AppLogger('actions');

  Future<ActionOutcome> run(ActionDescriptor action) async {
    // A double tap must open one dialer, not two.
    if (_inFlight) return ActionOutcome.busy;

    final uri = _builder.build(action);
    if (uri == null) {
      // The value is never logged — it is a phone number or a link.
      _log.failure('action_rejected_${action.kind.name}');
      return ActionOutcome.rejected;
    }

    _inFlight = true;
    try {
      final launched = await _launcher.launch(uri);
      if (!launched) _log.failure('action_unavailable_${action.kind.name}');
      return launched ? ActionOutcome.launched : ActionOutcome.unavailable;
    } catch (error, stackTrace) {
      // No handler, or the platform refused. TINDAK stays usable.
      //
      // Only the error's type is logged, not the error. A platform exception's
      // message can echo the URI back — which is a phone number or a link.
      _log.failure(
        'action_failed_${action.kind.name}_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return ActionOutcome.unavailable;
    } finally {
      _inFlight = false;
    }
  }
}
