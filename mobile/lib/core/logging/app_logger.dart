import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Application logging.
///
/// **Never pass user content to this class.** Not shared text, not memory
/// content, not a detected entity value, not a URL, not a phone number, not a
/// token. Messages are developer-facing strings and stable codes only.
/// See docs/12_SECURITY.md section 11.
///
/// Detector behaviour is debugged in unit tests, where the input is a fixture
/// rather than a real person's message.
final class AppLogger {
  const AppLogger(this.name);

  /// Receives every message that would be emitted, in tests only.
  ///
  /// Exists so a test can capture what TINDAK logs on a failure path and prove
  /// that no saved text appears in it — a rule that is otherwise only a
  /// comment.
  @visibleForTesting
  static void Function(String name, String message)? testSink;

  /// The subsystem this logger belongs to, e.g. `sync` or `share`.
  final String name;

  /// Developer detail. Dropped entirely in release builds.
  void debug(String message) {
    if (kReleaseMode) return;
    _emit(message, level: 500);
  }

  /// A notable event, identified by a stable code such as `sync_started`.
  /// Dropped in release builds.
  void event(String code) {
    if (kReleaseMode) return;
    _emit(code, level: 800);
  }

  /// A failure, identified by a stable [code] such as `storage` or
  /// `provider_timeout`. Kept in release builds, because a code carries no user
  /// content and is what makes a bug report actionable.
  void failure(String code, {Object? error, StackTrace? stackTrace}) {
    _emit(code, level: 1000, error: error, stackTrace: stackTrace);
  }

  void _emit(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    testSink?.call(name, '$message ${error ?? ''}');
    developer.log(
      message,
      name: 'tindak.$name',
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
