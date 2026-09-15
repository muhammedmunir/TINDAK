import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/app/tindak_app.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/clipboard_reader.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/memory/memory_detail_screen.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/share/share_channel.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

import '../support/test_database.dart';

final class FakeShareChannel implements ShareChannel {
  FakeShareChannel({this.initial});

  IncomingText? initial;
  void Function(IncomingText share)? _handler;

  @override
  Future<IncomingText?> initialShare() async {
    final share = initial;
    initial = null;
    return share;
  }

  @override
  void onShareReceived(void Function(IncomingText share) handler) {
    _handler = handler;
  }

  void emit(IncomingText share) => _handler?.call(share);
}

final class FakeClipboardReader implements ClipboardReader {
  FakeClipboardReader({this.text});

  String? text;
  int reads = 0;

  @override
  Future<String?> readPlainText() async {
    reads += 1;
    return text;
  }
}

IncomingText shareOf(int sequence, String text) => IncomingText(
  text: text,
  source: IntakeSource.share,
  sequence: sequence,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(sequence * 1000),
);

/// Records every URI TINDAK hands to Android.
final class RecordingLauncher implements ExternalLauncher {
  final List<String> launched = <String>[];
  bool result = true;

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri.toString());
    return result;
  }
}

Future<TindakDatabase> pumpApp(
  WidgetTester tester,
  FakeShareChannel channel, {
  FakeClipboardReader? clipboard,
  RecordingLauncher? launcher,
  TindakDatabase? database,
  MemoryRepository? repository,
  List<Override> overrides = const <Override>[],
}) async {
  final db = database ?? openTestDatabase();
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareChannelProvider.overrideWithValue(channel),
        clipboardReaderProvider.overrideWithValue(
          clipboard ?? FakeClipboardReader(),
        ),
        externalLauncherProvider.overrideWithValue(
          launcher ?? RecordingLauncher(),
        ),
        databaseProvider.overrideWithValue(db),
        if (repository != null)
          memoryRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
      child: const TindakApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Drives the app through a full background-and-return cycle.
void cycleLifecycle(WidgetTester tester) {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  group('TindakApp', () {
    testWidgets('boots to Home when nothing has arrived', (tester) async {
      await pumpApp(tester, FakeShareChannel());

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(IntakeResultScreen), findsNothing);
    });

    testWidgets('shows the approved empty-state copy', (tester) async {
      // docs/03_UX_FLOWS.md section 4. The old copy told users to share a
      // WhatsApp message, which they cannot do (PD-033).
      await pumpApp(tester, FakeShareChannel());

      expect(find.text('Jumpa maklumat penting?'), findsOneWidget);
      expect(
        find.text('Share ke TINDAK, atau salin teks\ndan tampal di sini.'),
        findsOneWidget,
      );
      expect(find.textContaining('Tekan Share dalam WhatsApp'), findsNothing);
    });

    testWidgets('offers the Tampal control', (tester) async {
      await pumpApp(tester, FakeShareChannel());

      expect(find.widgetWithText(FilledButton, 'Tampal'), findsOneWidget);
    });

    testWidgets('starts with no account prompt and no permission wall',
        (tester) async {
      // PD-001 guest-first, UX section 3.
      await pumpApp(tester, FakeShareChannel());

      expect(find.textContaining('Sign in'), findsNothing);
      expect(find.textContaining('Log masuk'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('renders in dark theme without error', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester, FakeShareChannel());

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('share intake', () {
    testWidgets('cold start with a share opens the result screen',
        (tester) async {
      final channel = FakeShareChannel(
        initial: shareOf(1, 'Bayar bil TNB RM183.50'),
      );

      await pumpApp(tester, channel);

      expect(find.byType(IntakeResultScreen), findsOneWidget);
      expect(find.text('Bayar bil TNB RM183.50'), findsOneWidget);
    });

    testWidgets('a shared message is understood end to end', (tester) async {
      final channel = FakeShareChannel(
        initial: shareOf(1, 'Hubungi 012-3456789 atau https://example.com'),
      );

      await pumpApp(tester, channel);

      expect(find.text('Dikesan'), findsOneWidget);
      expect(find.text('012-3456789'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('a second share is understood afresh', (tester) async {
      final channel = FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789'));
      await pumpApp(tester, channel);

      channel.emit(shareOf(2, 'Tiada apa-apa'));
      await tester.pumpAndSettle();

      expect(find.text('Telefon'), findsNothing);
      expect(
        find.text(IntakeResultScreen.nothingDetectedMessage),
        findsOneWidget,
      );
    });

    testWidgets('a share while running opens the result screen',
        (tester) async {
      final channel = FakeShareChannel();
      await pumpApp(tester, channel);

      channel.emit(shareOf(1, 'Hubungi 012-3456789'));
      await tester.pumpAndSettle();

      expect(find.text('Hubungi 012-3456789'), findsOneWidget);
    });

    testWidgets('a second share replaces the result rather than stacking',
        (tester) async {
      final channel = FakeShareChannel(initial: shareOf(1, 'first share'));
      await pumpApp(tester, channel);

      channel.emit(shareOf(2, 'second share'));
      await tester.pumpAndSettle();

      expect(find.byType(IntakeResultScreen), findsOneWidget);
      expect(find.text('second share'), findsOneWidget);
      expect(find.text('first share'), findsNothing);
    });

    testWidgets('the same share delivered twice renders once', (tester) async {
      final channel = FakeShareChannel();
      await pumpApp(tester, channel);

      final duplicate = shareOf(7, 'only once');
      channel.emit(duplicate);
      await tester.pumpAndSettle();
      channel.emit(duplicate);
      await tester.pumpAndSettle();

      expect(find.text('only once'), findsOneWidget);
    });

    testWidgets('closing the result returns to Home', (tester) async {
      final channel = FakeShareChannel(initial: shareOf(1, 'Bayar bil TNB'));
      await pumpApp(tester, channel);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a closed share is not redelivered by a lifecycle replay',
        (tester) async {
      final channel = FakeShareChannel(initial: shareOf(1, 'Bayar bil TNB'));
      await pumpApp(tester, channel);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      channel.emit(shareOf(1, 'Bayar bil TNB'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('paste intake', () {
    testWidgets('Tampal opens the result screen with the clipboard text',
        (tester) async {
      final clipboard = FakeClipboardReader(text: 'Bayar bil TNB RM183.50');
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(find.byType(IntakeResultScreen), findsOneWidget);
      expect(find.text('Bayar bil TNB RM183.50'), findsOneWidget);
    });

    testWidgets('an empty clipboard shows a quiet message and stays on Home',
        (tester) async {
      final clipboard = FakeClipboardReader(text: '');
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(HomeScreen.nothingToPasteMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-text clipboard shows the same quiet message',
        (tester) async {
      final clipboard = FakeClipboardReader();
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(find.text(HomeScreen.nothingToPasteMessage), findsOneWidget);
    });

    testWidgets('closing a pasted result returns to Home', (tester) async {
      final clipboard = FakeClipboardReader(text: 'Bayar bil TNB');
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);
      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the clipboard is untouched until Tampal is pressed',
        (tester) async {
      // ADR-004, PD-033. Launching the app, painting Home and settling every
      // frame must not read the clipboard.
      final clipboard = FakeClipboardReader(text: 'secret in the clipboard');
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);

      expect(clipboard.reads, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(clipboard.reads, 1);
    });

    testWidgets('pasted text is understood', (tester) async {
      final clipboard = FakeClipboardReader(text: 'Hubungi 012-3456789');
      await pumpApp(tester, FakeShareChannel(), clipboard: clipboard);

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(find.text('Dikesan'), findsOneWidget);
      expect(find.text('Telefon'), findsOneWidget);
    });

    testWidgets('receiving a share does not read the clipboard',
        (tester) async {
      final clipboard = FakeClipboardReader(text: 'secret in the clipboard');
      final channel = FakeShareChannel();
      await pumpApp(tester, channel, clipboard: clipboard);

      channel.emit(shareOf(1, 'shared text'));
      await tester.pumpAndSettle();

      expect(clipboard.reads, 0);
    });
  });

  group('action engine — M4', () {
    const message = 'Hubungi 012-3456789, pejabat 03-1234 5678, '
        'lihat https://www.tnb.com.my/bayar';

    testWidgets('a cold-start share launches nothing on render',
        (tester) async {
      final launcher = RecordingLauncher();

      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      expect(find.text('Dikesan'), findsOneWidget);
      expect(launcher.launched, isEmpty);
    });

    testWidgets('a share while running launches nothing', (tester) async {
      final launcher = RecordingLauncher();
      final channel = FakeShareChannel();
      await pumpApp(tester, channel, launcher: launcher);

      channel.emit(shareOf(1, message));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('a paste launches nothing', (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(),
        clipboard: FakeClipboardReader(text: message),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('lifecycle events on a result launch nothing', (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      for (var i = 0; i < 3; i++) {
        cycleLifecycle(tester);
        await tester.pumpAndSettle();
      }

      expect(launcher.launched, isEmpty);
    });

    testWidgets('Call on a mobile launches the dialer URI once',
        (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil').first);
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['tel:+60123456789']);
    });

    testWidgets('Call on a landline launches its own number', (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil').at(1));
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['tel:+60312345678']);
    });

    testWidgets('WhatsApp launches wa.me with the normalised mobile',
        (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'WhatsApp'));
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['https://wa.me/60123456789']);
    });

    testWidgets('Open launches the https link', (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Buka'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Buka'));
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['https://www.tnb.com.my/bayar']);
    });

    testWidgets('Open launches an http link', (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, 'http://example.com/a')),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Buka'));
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['http://example.com/a']);
    });

    testWidgets('an action taken is not repeated by lifecycle events',
        (tester) async {
      // The real sequence: tap Call, Android opens the dialer and TINDAK goes
      // to the background, the user comes back. Returning must not dial again.
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil').first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        cycleLifecycle(tester);
        await tester.pumpAndSettle();
      }

      expect(launcher.launched, hasLength(1));
    });

    testWidgets('the result is still on screen after an action (PD-014)',
        (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil').first);
      await tester.pumpAndSettle();
      cycleLifecycle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(IntakeResultScreen), findsOneWidget);
    });

    testWidgets('no app to handle it shows a quiet message and stays open',
        (tester) async {
      final launcher = RecordingLauncher()..result = false;
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, message)),
        launcher: launcher,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.text(IntakeGate.actionUnavailableMessage), findsOneWidget);
      expect(find.byType(IntakeResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an IC number offers no action at all (PD-029)',
        (tester) async {
      final launcher = RecordingLauncher();
      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, 'No IC 900101-03-1234')),
        launcher: launcher,
      );

      expect(find.byType(OutlinedButton), findsNothing);
      expect(launcher.launched, isEmpty);
    });
  });

  group('memory — M5a', () {
    Future<int> memoryCount(TindakDatabase db) async =>
        (await db.select(db.memories).get()).length;

    Future<void> pressSave(WidgetTester tester) async {
      final save = find.widgetWithText(FilledButton, IntakeResultScreen.saveLabel);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    Future<void> closeResult(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }

    group('Save is explicit (PD-003)', () {
      testWidgets('a share, its understanding and an action save nothing',
          (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(
            initial: shareOf(1, 'Hubungi 012-3456789 atau https://a.com.my'),
          ),
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil'));
        await tester.pumpAndSettle();
        cycleLifecycle(tester);
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 0);
      });

      testWidgets('a paste saves nothing', (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(),
          clipboard: FakeClipboardReader(text: 'Hubungi 012-3456789'),
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Tampal'));
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 0);
      });

      testWidgets('Simpan is offered on the result', (tester) async {
        await pumpApp(tester, FakeShareChannel(initial: shareOf(1, 'x')));

        expect(
          find.widgetWithText(FilledButton, IntakeResultScreen.saveLabel),
          findsOneWidget,
        );
      });

      testWidgets('pressing Simpan saves once and says so', (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789')),
        );

        await pressSave(tester);

        expect(await memoryCount(db), 1);
        expect(find.text(IntakeGate.savedMessage), findsOneWidget);
      });

      testWidgets('saving launches nothing', (tester) async {
        final launcher = RecordingLauncher();
        await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789')),
          launcher: launcher,
        );

        await pressSave(tester);

        expect(launcher.launched, isEmpty);
      });

      testWidgets('plain text with nothing detected can be saved',
          (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Beli susu dan roti')),
        );

        await pressSave(tester);

        expect(await memoryCount(db), 1);
      });

      testWidgets('multi-entity text saves every entity', (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(
            initial: shareOf(1, '012-3456789, 03-1234 5678, https://a.com.my'),
          ),
        );

        await pressSave(tester);

        expect(await db.select(db.memoryEntities).get(), hasLength(3));
      });

      testWidgets('two separate presses are two memories', (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789')),
        );

        await pressSave(tester);
        await pressSave(tester);

        expect(await memoryCount(db), 2);
      });

      testWidgets('text over 10,000 characters is refused with the limit '
          '(PD-039)', (tester) async {
        final long = 'a' * (TindakDatabase.maxContentLength + 1);
        final db = await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, long)),
        );

        await pressSave(tester);

        expect(await memoryCount(db), 0);
        expect(find.text(IntakeGate.tooLongMessage), findsOneWidget);
        expect(
          IntakeGate.tooLongMessage,
          'Teks terlalu panjang untuk disimpan. Had ialah 10,000 aksara.',
        );
        // The result stays on screen, so the user still has their text.
        expect(find.byType(IntakeResultScreen), findsOneWidget);
      });

      testWidgets('text of exactly 10,000 characters is saved', (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(
            initial: shareOf(1, 'a' * TindakDatabase.maxContentLength),
          ),
        );

        await pressSave(tester);

        expect(await memoryCount(db), 1);
      });

      testWidgets('oversized intake is still displayed as before', (tester) async {
        // PD-039 changes what may be saved, not what is received and shown
        // (M2's display behaviour is untouched).
        final long = 'a' * (IntakeResultScreen.displayLimit + 500);
        await pumpApp(tester, FakeShareChannel(initial: shareOf(1, long)));

        expect(
          find.textContaining(
            '${IntakeResultScreen.displayLimit} aksara pertama',
          ),
          findsOneWidget,
        );
      });

      testWidgets('Simpan is disabled while a save is in flight (PD-040)',
          (tester) async {
        final repository = _GatedMemoryRepository();
        await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789')),
          repository: repository,
        );
        final save = find.widgetWithText(
          FilledButton,
          IntakeResultScreen.saveLabel,
        );

        await tester.tap(save);
        await tester.pump();

        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // A second tap while the write is still running is not accepted.
        await tester.tap(save, warnIfMissed: false);
        await tester.pump();
        expect(repository.saves, 1);

        repository.gate.complete();
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('lifecycle and rotation after saving do not save again',
          (tester) async {
        final db = await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789')),
        );
        await pressSave(tester);

        for (var i = 0; i < 3; i++) {
          cycleLifecycle(tester);
          await tester.pumpAndSettle();
        }
        tester.view.physicalSize = const Size(2400, 1080);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 1);
      });

      testWidgets('a second share arriving does not save the first',
          (tester) async {
        final channel = FakeShareChannel(initial: shareOf(1, 'first'));
        final db = await pumpApp(tester, channel);

        channel.emit(shareOf(2, 'second'));
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 0);
      });
    });

    group('Memory list', () {
      testWidgets('empty Memory shows the empty state', (tester) async {
        await pumpApp(tester, FakeShareChannel());

        expect(find.text('Jumpa maklumat penting?'), findsOneWidget);
        expect(find.text(HomeScreen.searchHint), findsNothing);
      });

      testWidgets('a saved item appears after closing the result',
          (tester) async {
        await pumpApp(
          tester,
          FakeShareChannel(initial: shareOf(1, 'Bayar bil TNB 012-3456789')),
        );
        await pressSave(tester);

        await closeResult(tester);

        expect(find.text('Bayar bil TNB 012-3456789'), findsOneWidget);
        expect(find.text('Jumpa maklumat penting?'), findsNothing);
      });

      testWidgets('shows the device-only notice (PD-019)', (tester) async {
        await pumpApp(tester, FakeShareChannel(initial: shareOf(1, 'x')));
        await pressSave(tester);
        await closeResult(tester);

        expect(find.text(HomeScreen.deviceOnlyNotice), findsOneWidget);
        expect(find.textContaining('Sign in'), findsNothing);
      });

      testWidgets('Tampal is still reachable once Memory has items',
          (tester) async {
        await pumpApp(tester, FakeShareChannel(initial: shareOf(1, 'x')));
        await pressSave(tester);
        await closeResult(tester);

        expect(find.byTooltip('Tampal'), findsOneWidget);
      });

      testWidgets('memories survive a restart of the app', (tester) async {
        final channel = FakeShareChannel(initial: shareOf(1, 'Simpan saya'));
        final db = openTestDatabase();
        await pumpApp(tester, channel, database: db);
        await pressSave(tester);

        // Throw away the whole widget and provider tree, then start again on
        // the same database — what a relaunch does.
        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, FakeShareChannel(), database: db);

        expect(find.text('Simpan saya'), findsOneWidget);
      });

      testWidgets('an unreadable database shows a quiet message',
          (tester) async {
        final db = openTestDatabase();
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement('DROP TABLE memory_entities');
        await db.customStatement('DROP TABLE memories');

        await pumpApp(tester, FakeShareChannel(), database: db);

        expect(find.text(HomeScreen.unreadableMessage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('search', () {
      Future<void> seed(WidgetTester tester) async {
        final channel = FakeShareChannel(
          initial: shareOf(1, 'Hubungi saya 012-345 6789'),
        );
        await pumpApp(tester, channel);
        await pressSave(tester);
        channel.emit(shareOf(2, 'Bayar bil di https://www.tnb.com.my'));
        await tester.pumpAndSettle();
        await pressSave(tester);
        await closeResult(tester);
      }

      testWidgets('filters by original text', (tester) async {
        await seed(tester);

        await tester.enterText(find.byType(TextField), 'Bayar');
        await tester.pumpAndSettle();

        expect(find.text('Bayar bil di https://www.tnb.com.my'), findsOneWidget);
        expect(find.text('Hubungi saya 012-345 6789'), findsNothing);
      });

      testWidgets('finds a phone however it is typed', (tester) async {
        await seed(tester);

        await tester.enterText(find.byType(TextField), '0123456789');
        await tester.pumpAndSettle();

        expect(find.text('Hubungi saya 012-345 6789'), findsOneWidget);
        expect(find.text('Bayar bil di https://www.tnb.com.my'), findsNothing);
      });

      testWidgets('no match shows the no-results message', (tester) async {
        await seed(tester);

        await tester.enterText(find.byType(TextField), 'tiada langsung');
        await tester.pumpAndSettle();

        expect(find.text(HomeScreen.noMatchesMessage), findsOneWidget);
        // The search field stays, so the user can change the query.
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('clearing the search shows everything again', (tester) async {
        await seed(tester);
        await tester.enterText(find.byType(TextField), 'tiada langsung');
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Kosongkan'));
        await tester.pumpAndSettle();

        expect(find.text('Hubungi saya 012-345 6789'), findsOneWidget);
        expect(find.text('Bayar bil di https://www.tnb.com.my'), findsOneWidget);
      });
    });

    group('detail and delete', () {
      Future<TindakDatabase> seedAndOpen(WidgetTester tester) async {
        final channel = FakeShareChannel(
          initial: shareOf(1, 'Simpan yang ini 012-3456789'),
        );
        final db = await pumpApp(tester, channel);
        await pressSave(tester);
        channel.emit(shareOf(2, 'Dan yang ini juga'));
        await tester.pumpAndSettle();
        await pressSave(tester);
        await closeResult(tester);

        await tester.tap(find.text('Simpan yang ini 012-3456789'));
        await tester.pumpAndSettle();
        return db;
      }

      testWidgets('opens the correct record', (tester) async {
        await seedAndOpen(tester);

        expect(find.byType(MemoryDetailScreen), findsOneWidget);
        expect(find.text('Simpan yang ini 012-3456789'), findsOneWidget);
        expect(find.text('Dan yang ini juga'), findsNothing);
        expect(find.text(MemoryDetailScreen.onDeviceStatus), findsOneWidget);
      });

      testWidgets('a saved number offers the same validated actions',
          (tester) async {
        final launcher = RecordingLauncher();
        final channel = FakeShareChannel(initial: shareOf(1, 'Hubungi 012-3456789'));
        await pumpApp(tester, channel, launcher: launcher);
        await pressSave(tester);
        await closeResult(tester);
        await tester.tap(find.text('Hubungi 012-3456789'));
        await tester.pumpAndSettle();

        expect(launcher.launched, isEmpty);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Panggil'));
        await tester.pumpAndSettle();

        expect(launcher.launched, <String>['tel:+60123456789']);
      });

      testWidgets('delete asks first; cancelling keeps the item',
          (tester) async {
        final db = await seedAndOpen(tester);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Padam'));
        await tester.pumpAndSettle();
        expect(find.text(MemoryDetailScreen.confirmTitle), findsOneWidget);
        expect(find.text(MemoryDetailScreen.confirmBody), findsOneWidget);

        await tester.tap(find.text(MemoryDetailScreen.cancelLabel));
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 2);
        expect(find.byType(MemoryDetailScreen), findsOneWidget);
      });

      testWidgets('confirming deletes the correct item and returns to Memory',
          (tester) async {
        final db = await seedAndOpen(tester);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Padam'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(MemoryDetailScreen.deleteLabel),
          ),
        );
        await tester.pumpAndSettle();

        expect(await memoryCount(db), 1);
        expect(find.byType(MemoryDetailScreen), findsNothing);
        expect(find.text('Simpan yang ini 012-3456789'), findsNothing);
        expect(find.text('Dan yang ini juga'), findsOneWidget);
        expect(find.text(MemoryDetailScreen.deletedMessage), findsOneWidget);
      });

      testWidgets('a deleted item no longer appears in search', (tester) async {
        await seedAndOpen(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Padam'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(MemoryDetailScreen.deleteLabel),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '0123456789');
        await tester.pumpAndSettle();

        expect(find.text(HomeScreen.noMatchesMessage), findsOneWidget);
      });

      testWidgets('offers no Trash, Archive or Restore', (tester) async {
        await seedAndOpen(tester);

        for (final label in <String>[
          'Tong sampah', 'Trash', 'Arkib', 'Archive', 'Pulihkan', 'Restore',
        ]) {
          expect(find.text(label), findsNothing, reason: label);
        }
      });

      testWidgets('a share arriving on the detail screen is shown',
          (tester) async {
        final channel = FakeShareChannel(initial: shareOf(1, 'Simpan ini'));
        await pumpApp(tester, channel);
        await pressSave(tester);
        await closeResult(tester);
        await tester.tap(find.text('Simpan ini'));
        await tester.pumpAndSettle();
        expect(find.byType(MemoryDetailScreen), findsOneWidget);

        channel.emit(shareOf(2, 'Baru sampai'));
        await tester.pumpAndSettle();

        expect(find.byType(MemoryDetailScreen), findsNothing);
        expect(find.text('Baru sampai'), findsOneWidget);
      });
    });
  });
}

/// A Memory repository whose save stays open until the test releases it.
final class _GatedMemoryRepository implements MemoryRepository {
  final Completer<void> gate = Completer<void>();
  int saves = 0;

  @override
  Future<Result<String>> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  }) async {
    saves += 1;
    await gate.future;
    return Result<String>.ok('id-$saves');
  }

  @override
  Stream<List<MemoryRecord>> watch({String query = ''}) =>
      Stream<List<MemoryRecord>>.value(const <MemoryRecord>[]);

  @override
  Future<Result<MemoryRecord>> findById(String id) async =>
      const Result<MemoryRecord>.err(NotFoundFailure());

  @override
  Future<Result<void>> delete(String id) async =>
      const Result<void>.err(NotFoundFailure());
}
