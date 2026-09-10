import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/share/share_channel.dart';
import 'package:tindak/features/share/shared_text.dart';

/// Supplies the platform channel. Overridden in tests with a fake.
final Provider<ShareChannel> shareChannelProvider = Provider<ShareChannel>(
  (ref) => MethodChannelShareChannel(),
);

final NotifierProvider<ShareController, SharedText?> shareControllerProvider =
    NotifierProvider<ShareController, SharedText?>(ShareController.new);

/// Holds the share currently on screen.
///
/// Its one real job is making sure a single user action produces a single
/// result. During cold start the initial-share request and a new-intent
/// callback can both describe the same share, so every payload carries a
/// monotonic sequence and anything not newer than the last accepted one is
/// dropped.
class ShareController extends Notifier<SharedText?> {
  int _lastSequence = 0;

  @override
  SharedText? build() => null;

  /// Subscribes to shares and collects the one that started the app.
  ///
  /// Called once from the app shell. Safe to await; a failure to read a share
  /// leaves the app on Home rather than throwing.
  Future<void> start() async {
    try {
      final channel = ref.read(shareChannelProvider);
      channel.onShareReceived(accept);
      final initial = await channel.initialShare();
      if (initial != null) accept(initial);
    } catch (error, stackTrace) {
      // Never throw into the widget tree. A share that cannot be read leaves
      // the user on Home, which is a working app, not a crash.
      const AppLogger(
        'share',
      ).failure('share_start_failed', error: error, stackTrace: stackTrace);
    }
  }

  /// Accepts a share unless it repeats or precedes one already handled.
  ///
  /// Visible for testing so the duplicate rules can be exercised without a
  /// platform channel.
  void accept(SharedText share) {
    if (share.sequence <= _lastSequence) return;
    _lastSequence = share.sequence;
    state = share;
  }

  /// Clears the current share, e.g. when the user leaves the result screen.
  ///
  /// Does not rewind the sequence, so the share just dismissed cannot be
  /// redelivered by a lifecycle event.
  void clear() => state = null;
}
