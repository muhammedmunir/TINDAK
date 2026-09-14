import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/clipboard_reader.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/share/share_channel.dart';

/// Supplies the Android share channel. Overridden in tests with a fake.
final Provider<ShareChannel> shareChannelProvider = Provider<ShareChannel>(
  (ref) => MethodChannelShareChannel(),
);

/// Supplies the clipboard reader. Overridden in tests with a fake that counts
/// how many times it was read.
final Provider<ClipboardReader> clipboardReaderProvider =
    Provider<ClipboardReader>((ref) => const SystemClipboardReader());

final NotifierProvider<IntakeController, IncomingText?> intakeControllerProvider =
    NotifierProvider<IntakeController, IncomingText?>(IntakeController.new);

/// What happened when the user pressed Tampal.
enum PasteOutcome {
  /// Text was read and is now on screen.
  accepted,

  /// The clipboard held no usable text — empty, whitespace, or not text.
  empty,

  /// The clipboard could not be read at all.
  unavailable,
}

/// Holds the text currently on screen, from either intake path.
///
/// Its one hard job is making sure a single user action produces a single
/// result, and that TINDAK never reads the clipboard the user did not ask it to
/// read.
class IntakeController extends Notifier<IncomingText?> {
  /// Tracks share deliveries only.
  ///
  /// Kept separate from paste on purpose. A paste must never be able to raise
  /// this bar, because that would silently swallow a genuine later share whose
  /// Android-assigned sequence is lower.
  int _lastShareSequence = 0;

  static const AppLogger _log = AppLogger('intake');

  @override
  IncomingText? build() => null;

  /// Subscribes to Android shares and collects the one that launched the app.
  ///
  /// Called once from the app shell. **Reads no clipboard.** Nothing in this
  /// method, or anywhere else on a lifecycle path, may.
  Future<void> start() async {
    try {
      final channel = ref.read(shareChannelProvider);
      channel.onShareReceived(acceptShare);
      final initial = await channel.initialShare();
      if (initial != null) acceptShare(initial);
    } catch (error, stackTrace) {
      // Never throw into the widget tree. Text that cannot be read leaves the
      // user on Home, which is a working app, not a crash.
      _log.failure('share_start_failed', error: error, stackTrace: stackTrace);
    }
  }

  /// Accepts a share unless it repeats or precedes one already handled.
  ///
  /// Visible for testing so the duplicate rules can be exercised without a
  /// platform channel.
  void acceptShare(IncomingText share) {
    if (share.sequence <= _lastShareSequence) return;
    _lastShareSequence = share.sequence;
    state = share;
  }

  /// Reads the clipboard once, because the user just asked for it.
  ///
  /// This is the **only** place in TINDAK that touches the clipboard, and it
  /// runs only from the Tampal control (PD-033, ADR-004).
  Future<PasteOutcome> paste() async {
    final String? text;
    try {
      text = await ref.read(clipboardReaderProvider).readPlainText();
    } catch (error, stackTrace) {
      _log.failure('paste_failed', error: error, stackTrace: stackTrace);
      return PasteOutcome.unavailable;
    }

    if (text == null) return PasteOutcome.unavailable;
    if (text.trim().isEmpty) return PasteOutcome.empty;

    // Stored exactly as copied. Trimming is only ever a test for emptiness.
    state = IncomingText.pasted(text, at: ref.read(clockProvider).now());
    return PasteOutcome.accepted;
  }

  /// Clears the current text, e.g. when the user leaves the result screen.
  ///
  /// Does not rewind the share sequence, so the share just dismissed cannot be
  /// redelivered by a lifecycle event.
  void clear() => state = null;
}
