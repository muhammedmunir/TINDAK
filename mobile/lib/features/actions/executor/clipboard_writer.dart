import 'package:flutter/services.dart';

import 'package:tindak/core/logging/app_logger.dart';

/// Puts text on the system clipboard.
///
/// Writing is not reading. ADR-004 forbids TINDAK from **reading** the
/// clipboard except on the Tampal press; putting a value the user asked to copy
/// onto it carries none of that risk.
///
/// **Called from the Salin button's `onPressed` and from nowhere else.** An
/// interface, like [ClipboardReader], so a test can assert exactly what was
/// written and that nothing is written without a tap.
abstract interface class ClipboardWriter {
  /// Returns false when the platform refused. Never throws.
  Future<bool> writePlainText(String text);
}

final class SystemClipboardWriter implements ClipboardWriter {
  const SystemClipboardWriter();

  @override
  Future<bool> writePlainText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } on PlatformException catch (error, stackTrace) {
      // The clipboard is a shared system surface and a write can be refused.
      // The value itself is never logged — it is user content.
      const AppLogger('actions').failure(
        'clipboard_write_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      const AppLogger('actions').failure(
        'clipboard_unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
