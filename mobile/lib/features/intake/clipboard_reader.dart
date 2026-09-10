import 'package:flutter/services.dart';

import 'package:tindak/core/logging/app_logger.dart';

/// Reads the system clipboard.
///
/// **One read, only in direct response to the user pressing Tampal.** Never at
/// launch, never on resume, never on a timer, and never through a listener
/// (ADR-004, PD-033, docs/12_SECURITY.md section 7.1).
///
/// An interface so tests can count the reads. That count is how the rule above
/// is enforced rather than merely stated: the tests assert it stays at zero
/// until the user acts, including across a lifecycle resume.
abstract interface class ClipboardReader {
  /// The clipboard's plain text, or null when it holds none or cannot be read.
  Future<String?> readPlainText();
}

final class SystemClipboardReader implements ClipboardReader {
  const SystemClipboardReader();

  @override
  Future<String?> readPlainText() async {
    try {
      final ClipboardData? data = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      return data?.text;
    } on PlatformException catch (error, stackTrace) {
      // The clipboard is a shared system surface and a read can be refused.
      // Failing here leaves the user on Home; it never crashes the app.
      const AppLogger('intake').failure(
        'clipboard_read_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      const AppLogger('intake').failure(
        'clipboard_unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
