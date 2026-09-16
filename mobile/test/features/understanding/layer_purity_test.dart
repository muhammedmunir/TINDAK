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
      'lib/features/security/data/edge_reputation_provider.dart',
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

  test('Protect reaches the network in one file only (M8)', () {
    // The adapter below is the single door out: it calls TINDAK's own Edge
    // Function, which holds the Web Risk key. Everything else in Protect —
    // the analyser, the combination rules, the screen — stays offline, and a
    // background scanner would arrive as one of these imports first.
    const adapter = 'lib/features/security/data/edge_reputation_provider.dart';
    final forbidden = <RegExp>[
      RegExp(r'''import\s+['"]package:supabase'''),
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'''import\s+['"]dart:io'''),
      RegExp(r'''import\s+['"]package:tindak/features/ai/'''),
      RegExp(r'HttpClient'),
      RegExp(r'Timer\('),
      RegExp(r'Clipboard\.'),
    ];

    final found = <String>[];
    for (final entity in Directory('lib/features/security').listSync(
      recursive: true,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('edge_reputation_provider.dart')) continue;

      final source = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(source)) found.add('$path: ${pattern.pattern}');
      }
    }

    expect(found, isEmpty);
    expect(File(adapter).existsSync(), isTrue);
  });

  test('the local analyser cannot reach HIGH RISK', () {
    // Enforced in code as well as in tests: nothing on the device is strong
    // enough evidence to call a link dangerous (M8 plan, section 3.1).
    final code = File('lib/features/security/analyzer/url_safety_analyzer.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(' ');

    expect(code.contains('RiskLevel.high'), isFalse);
  });

  test('the AI domain, validation and service layers are pure (M9a)', () {
    // The entire safety argument for AI lives in these three directories:
    // grounding a claim in the user's own text, agreeing with what TINDAK
    // derives for itself, and the per-type rules. Keeping them pure Dart is
    // what makes that argument a unit test rather than an integration one.
    for (final directory in <String>[
      'lib/features/ai/model',
      'lib/features/ai/validation',
      'lib/features/ai/service',
    ]) {
      expect(violations(directory, impure), isEmpty, reason: directory);
    }
  });

  test('no build can pretend AI is available (M9a)', () {
    // PD-048 leaves the provider unconfigured, and M9a ships no implementation
    // of the interface at all — not behind a flag, not behind a debug switch.
    // The fake lives under test/, where a release build cannot reach it.
    final implementations = <String>[];
    final implementsIt = RegExp(r'implements\s+AiUnderstandingProvider');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (implementsIt.hasMatch(source) || source.contains('FakeAiProvider')) {
        implementations.add(entity.path.replaceAll(r'\', '/'));
      }
    }

    expect(implementations, isEmpty);
  });

  test('the AI feature cannot act on its own (M9a)', () {
    // A model returns claims. Everything that reaches the outside world — a
    // dial, a link, the clipboard, a scheduled alarm — is reached by the user
    // pressing a button, through the code that already existed. AI may call
    // the shared action and reminder *entry points*, and may not reach past
    // them into the repositories or the scheduler.
    final forbidden = <RegExp>[
      RegExp(r'''import\s+['"]package:url_launcher/'''),
      RegExp(r'''import\s+['"]package:supabase'''),
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'''import\s+['"]dart:io'''),
      RegExp(r'\bClipboard\.'),
      RegExp(r'''import\s+['"]package:tindak/features/reminders/data/'''),
      RegExp(
        r'''import\s+['"]package:tindak/features/reminders/reminder_service''',
      ),
      RegExp(r'''import\s+['"]package:tindak/features/memory/data/'''),
    ];

    expect(violations('lib/features/ai', forbidden), isEmpty);
  });

  test('the clipboard is touched in exactly two files', () {
    // ADR-004 and PD-033: one file reads the clipboard, and only on the Tampal
    // press; one file writes it, and only on the Salin press. A third file
    // touching the clipboard is how background reading would arrive.
    const approved = <String>{
      'lib/features/intake/clipboard_reader.dart',
      'lib/features/actions/executor/clipboard_writer.dart',
    };
    final clipboard = RegExp(r'\bClipboard\.(getData|setData)\b');
    final users = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (clipboard.hasMatch(entity.readAsStringSync())) {
        users.add(entity.path.replaceAll(r'\', '/'));
      }
    }

    expect(users.toSet(), approved);
  });
}
