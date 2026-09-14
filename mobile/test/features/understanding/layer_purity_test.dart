import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/10_ARCHITECTURE.md section 3: understanding and action *resolution*
/// are pure Dart. Action *execution* is the one impure part, and it is fenced
/// into `features/actions/executor`.
///
/// No Flutter, no Riverpod, no platform channels, no I/O, no launcher in the
/// pure layers. That keeps the most failure-prone logic testable on the Dart VM
/// without an emulator — and it means a detector or resolver physically cannot
/// launch an intent, because it cannot import anything that would.
///
/// A rule that lives only in a document erodes. This one fails the build.
void main() {
  final impure = <RegExp>[
    RegExp(r'''import\s+['"]package:flutter/'''),
    RegExp(r'''import\s+['"]package:flutter_riverpod/'''),
    RegExp(r'''import\s+['"]dart:io['"]'''),
    RegExp(r'''import\s+['"]dart:ui['"]'''),
    RegExp(r'''import\s+['"]package:url_launcher/'''),
    RegExp(r'''import\s+['"]package:supabase'''),
    RegExp(r'''import\s+['"]package:http/'''),
  ];

  List<String> violations(String directory, List<RegExp> forbidden) {
    final root = Directory(directory);
    expect(root.existsSync(), isTrue, reason: 'run from the mobile/ directory');

    final found = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(source)) {
          found.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }
    return found;
  }

  test('features/understanding imports nothing impure', () {
    expect(
      violations('lib/features/understanding', <RegExp>[
        ...impure,
        // Understanding depends on nothing else in the app.
        RegExp(r'''import\s+['"]package:tindak/features/(?!understanding/)'''),
      ]),
      isEmpty,
    );
  });

  test('features/actions/model imports nothing impure', () {
    expect(
      violations('lib/features/actions/model', <RegExp>[
        ...impure,
        RegExp(r'''import\s+['"]package:tindak/features/actions/executor/'''),
      ]),
      isEmpty,
    );
  });

  test('features/actions/resolver imports nothing impure', () {
    expect(
      violations('lib/features/actions/resolver', <RegExp>[
        ...impure,
        // Resolving an action must never be able to reach the code that runs
        // one.
        RegExp(r'''import\s+['"]package:tindak/features/actions/executor/'''),
      ]),
      isEmpty,
    );
  });

  test('url_launcher is used in exactly one file', () {
    // docs/10_ARCHITECTURE.md section 6: the executor is the only place that
    // touches url_launcher.
    final users = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('package:url_launcher/')) {
        users.add(entity.path.replaceAll(r'\', '/'));
      }
    }

    expect(users, <String>['lib/features/actions/executor/external_launcher.dart']);
  });
}
