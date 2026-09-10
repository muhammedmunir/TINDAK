import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/app/tindak_app.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/share/share_channel.dart';
import 'package:tindak/features/share/share_controller.dart';
import 'package:tindak/features/share/share_result_screen.dart';
import 'package:tindak/features/share/shared_text.dart';

/// A share channel under test control, with no platform behind it.
final class FakeShareChannel implements ShareChannel {
  FakeShareChannel({this.initial});

  SharedText? initial;
  void Function(SharedText share)? _handler;

  @override
  Future<SharedText?> initialShare() async {
    final share = initial;
    initial = null;
    return share;
  }

  @override
  void onShareReceived(void Function(SharedText share) handler) {
    _handler = handler;
  }

  void emit(SharedText share) => _handler?.call(share);
}

SharedText share(int sequence, String text) => SharedText(
  sequence: sequence,
  text: text,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(sequence * 1000),
);

Future<void> pumpApp(WidgetTester tester, FakeShareChannel channel) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [shareChannelProvider.overrideWithValue(channel)],
      child: const TindakApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TindakApp', () {
    testWidgets('boots to Home when nothing was shared', (tester) async {
      await pumpApp(tester, FakeShareChannel());

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ShareResultScreen), findsNothing);
    });

    testWidgets('shows the approved empty-state copy', (tester) async {
      // docs/03_UX_FLOWS.md section 4.
      await pumpApp(tester, FakeShareChannel());

      expect(find.text('Jumpa maklumat penting?'), findsOneWidget);
      expect(
        find.text(
          'Tekan Share dalam WhatsApp, browser\natau app lain dan pilih TINDAK.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('starts with no account prompt and no permission wall',
        (tester) async {
      // PD-001 guest-first, UX section 3: no forced registration and no
      // permission wall before first value.
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

  group('share entry point', () {
    testWidgets('cold start with a share opens the result screen',
        (tester) async {
      final channel = FakeShareChannel(
        initial: share(1, 'Bayar bil TNB RM183.50'),
      );

      await pumpApp(tester, channel);

      expect(find.byType(ShareResultScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Bayar bil TNB RM183.50'), findsOneWidget);
    });

    testWidgets('a share while running opens the result screen',
        (tester) async {
      final channel = FakeShareChannel();
      await pumpApp(tester, channel);
      expect(find.byType(HomeScreen), findsOneWidget);

      channel.emit(share(1, 'Hubungi 012-3456789'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareResultScreen), findsOneWidget);
      expect(find.text('Hubungi 012-3456789'), findsOneWidget);
    });

    testWidgets('a second share replaces the result rather than stacking',
        (tester) async {
      // docs/10_ARCHITECTURE.md section 9.3.
      final channel = FakeShareChannel(initial: share(1, 'first share'));
      await pumpApp(tester, channel);

      channel.emit(share(2, 'second share'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareResultScreen), findsOneWidget);
      expect(find.text('second share'), findsOneWidget);
      expect(find.text('first share'), findsNothing);
    });

    testWidgets('the same share delivered twice renders once', (tester) async {
      final channel = FakeShareChannel();
      await pumpApp(tester, channel);

      final duplicate = share(7, 'only once');
      channel.emit(duplicate);
      await tester.pumpAndSettle();
      channel.emit(duplicate);
      await tester.pumpAndSettle();

      expect(find.text('only once'), findsOneWidget);
      expect(find.byType(ShareResultScreen), findsOneWidget);
    });

    testWidgets('closing the result returns to Home', (tester) async {
      final channel = FakeShareChannel(initial: share(1, 'Bayar bil TNB'));
      await pumpApp(tester, channel);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ShareResultScreen), findsNothing);
    });

    testWidgets('a closed share is not redelivered by a lifecycle replay',
        (tester) async {
      final channel = FakeShareChannel(initial: share(1, 'Bayar bil TNB'));
      await pumpApp(tester, channel);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      channel.emit(share(1, 'Bayar bil TNB'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
