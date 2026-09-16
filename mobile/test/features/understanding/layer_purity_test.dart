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

  test('only the approved cloud adapters talk to the network (M5b)', () {
    // docs/13_API.md: Supabase is the only network interface. It is reached
    // from exactly these files; everything else — the sync rules included —
    // works through pure interfaces and is testable with no server. A new
    // file importing Supabase must be added here deliberately, in review.
    const approved = <String>{
      'lib/app/cloud_bootstrap.dart',
      'lib/features/auth/data/secure_session_storage.dart',
      'lib/features/auth/data/supabase_auth_gateway.dart',
      'lib/features/sync/data/supabase_cloud_memory_api.dart',
    };
    final supabase = RegExp(r'''import\s+['"]package:supabase''');
    final users = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (supabase.hasMatch(entity.readAsStringSync())) {
        users.add(entity.path.replaceAll(r'\', '/'));
      }
    }
    expect(users.toSet(), approved);
  });

  test('nothing talks to the network except through Supabase', () {
    // No second HTTP stack, no analytics SDK (docs/10_ARCHITECTURE.md
    // section 12).
    final network = <RegExp>[
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'''import\s+['"]package:dio/'''),
      RegExp(r'''import\s+['"]package:web_socket'''),
      RegExp(r'''import\s+['"]package:firebase'''),
      RegExp(r'\bHttpClient\b'),
      RegExp(r'\bSocket\.connect\b'),
    ];

    expect(violations('lib', network), isEmpty);
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
