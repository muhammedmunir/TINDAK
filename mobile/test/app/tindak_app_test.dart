import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/app/tindak_app.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/clipboard_reader.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/share/share_channel.dart';

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

Future<void> pumpApp(
  WidgetTester tester,
  FakeShareChannel channel, {
  FakeClipboardReader? clipboard,
  RecordingLauncher? launcher,
}) async {
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
      ],
      child: const TindakApp(),
    ),
  );
  await tester.pumpAndSettle();
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Call').first);
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Call').at(1));
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

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Open'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Open'));
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Open'));
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Call').first);
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Call').first);
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
}
