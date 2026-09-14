import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/10_ARCHITECTURE.md section 3: `features/understanding` is pure Dart.
///
/// No Flutter, no Riverpod, no platform channels, no I/O. That is what lets the
/// largest and most failure-prone part of the product run in unit tests on the
/// Dart VM without an emulator, and what keeps M3 from quietly growing an
/// action or a network call.
///
/// A rule that lives only in a document erodes. This one fails the build.
void main() {
  test('features/understanding imports nothing impure', () {
    final root = Directory('lib/features/understanding');
    expect(root.existsSync(), isTrue, reason: 'run from the mobile/ directory');

    final forbidden = <RegExp>[
      RegExp(r'''import\s+['"]package:flutter/'''),
      RegExp(r'''import\s+['"]package:flutter_riverpod/'''),
      RegExp(r'''import\s+['"]dart:io['"]'''),
      RegExp(r'''import\s+['"]dart:ui['"]'''),
      RegExp(r'''import\s+['"]package:url_launcher/'''),
      RegExp(r'''import\s+['"]package:supabase'''),
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'''import\s+['"]package:tindak/features/(?!understanding/)'''),
    ];

    final violations = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(source)) {
          violations.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }

    expect(violations, isEmpty);
  });
}
