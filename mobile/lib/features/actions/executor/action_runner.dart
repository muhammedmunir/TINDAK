import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/actions/executor/clipboard_writer.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/resolver/action_uri_builder.dart';
import 'package:tindak/features/understanding/model/money_value.dart';

final Provider<ExternalLauncher> externalLauncherProvider =
    Provider<ExternalLauncher>((ref) => const UrlLauncherExternalLauncher());

final Provider<ClipboardWriter> clipboardWriterProvider =
    Provider<ClipboardWriter>((ref) => const SystemClipboardWriter());

final Provider<ActionResolver> actionResolverProvider =
    Provider<ActionResolver>((ref) => const ActionResolver());

final Provider<ActionRunner> actionRunnerProvider = Provider<ActionRunner>(
  (ref) => ActionRunner(
    ref.watch(externalLauncherProvider),
    clipboard: ref.watch(clipboardWriterProvider),
  ),
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

  /// The value is on the clipboard (M6b).
  copied,

  /// The action exists but its milestone has not shipped: today only the date
  /// reminder, which M7 builds. Nothing was scheduled and nothing was claimed.
  notYetAvailable,
}

/// Runs an action the user explicitly tapped.
///
/// **This is called from a button's `onPressed` and from nowhere else.** Not on
/// render, not on resume, not when an entity is detected, not when a share
/// arrives. Detection offers actions; only a tap takes one.
final class ActionRunner {
  ActionRunner(
    this._launcher, {
    ClipboardWriter clipboard = const SystemClipboardWriter(),
    ActionUriBuilder builder = const ActionUriBuilder(),
  }) : _clipboard = clipboard,
       _builder = builder;

  final ExternalLauncher _launcher;
  final ClipboardWriter _clipboard;
  final ActionUriBuilder _builder;

  bool _inFlight = false;

  static const AppLogger _log = AppLogger('actions');

  /// Copies the amount as the user sees it — `RM183.50`, not `MYR18350` and
  /// not the raw span — because that is what they will paste somewhere else
  /// (PD approval A-6).
  Future<ActionOutcome> _copy(ActionDescriptor action) async {
    final money = MoneyValue.parse(action.entity.normalizedValue);
    if (money == null) {
      _log.failure('action_rejected_copy');
      return ActionOutcome.rejected;
    }

    _inFlight = true;
    try {
      final written = await _clipboard.writePlainText(money.display);
      if (!written) _log.failure('action_unavailable_copy');
      return written ? ActionOutcome.copied : ActionOutcome.unavailable;
    } catch (error, stackTrace) {
      _log.failure(
        'action_failed_copy_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return ActionOutcome.unavailable;
    } finally {
      _inFlight = false;
    }
  }

  Future<ActionOutcome> run(ActionDescriptor action) async {
    // A double tap must open one dialer, not two.
    if (_inFlight) return ActionOutcome.busy;

    // Neither of these starts another app, so neither goes through the URI
    // builder or the launcher.
    if (action.kind == ActionKind.copy) return _copy(action);
    if (action.kind == ActionKind.remind) {
      // M6 deliberately does nothing here. No reminder, no permission prompt,
      // no stored state — the UI says so in plain words.
      return ActionOutcome.notYetAvailable;
    }

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
