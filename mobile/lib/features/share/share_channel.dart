import 'package:flutter/services.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/incoming_text.dart';

/// The boundary between Android share intents and Dart.
///
/// One of TINDAK's two intake paths (PD-033). An interface so the controller
/// can be tested on the Dart VM with no platform channel and no emulator.
abstract interface class ShareChannel {
  /// The share that started the app, if it was launched by one.
  ///
  /// Answers once. A second call returns null rather than replaying.
  Future<IncomingText?> initialShare();

  /// Called when a share arrives while the app is already running.
  void onShareReceived(void Function(IncomingText share) handler);
}

/// Talks to `MainActivity` over a method channel.
final class MethodChannelShareChannel implements ShareChannel {
  MethodChannelShareChannel([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(_name);

  static const String _name = 'my.tindak.app/share';

  final MethodChannel _channel;
  final AppLogger _log = const AppLogger('share');

  @override
  Future<IncomingText?> initialShare() async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>(
        'getInitialShare',
      );
      final share = IncomingText.fromSharePayload(payload);
      if (payload != null && share == null) {
        _log.failure('share_payload_malformed');
      }
      return share;
    } on PlatformException catch (error, stackTrace) {
      // Landing on Home is the safe failure. Never crash the app because a
      // share could not be read.
      _log.failure('share_initial_failed', error: error, stackTrace: stackTrace);
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      _log.failure('share_channel_missing', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  void onShareReceived(void Function(IncomingText share) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onShareReceived') return null;

      final share = IncomingText.fromSharePayload(call.arguments);
      if (share == null) {
        _log.failure('share_payload_malformed');
        return null;
      }
      handler(share);
      return null;
    });
  }
}
