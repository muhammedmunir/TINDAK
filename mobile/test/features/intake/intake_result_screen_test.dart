import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';

IncomingText sharedOf(String text) => IncomingText(
  text: text,
  source: IntakeSource.share,
  sequence: 1,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

IncomingText pastedOf(String text) => IncomingText.pasted(
  text,
  at: DateTime.fromMillisecondsSinceEpoch(0),
);

Future<void> pump(
  WidgetTester tester,
  IncomingText incoming, {
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IntakeResultScreen(incoming: incoming, onClose: onClose),
    ),
  );
}

void main() {
  group('IntakeResultScreen', () {
    testWidgets('shows the received text', (tester) async {
      await pump(
        tester,
        sharedOf('Bayar bil TNB RM183.50 sebelum 25 September'),
      );

      expect(
        find.text('Bayar bil TNB RM183.50 sebelum 25 September'),
        findsOneWidget,
      );
    });

    testWidgets('looks the same for a paste as for a share', (tester) async {
      // The user is looking at their own text and does not need to be told
      // which door it came through.
      const text = 'Bayar bil TNB RM183.50';

      await pump(tester, sharedOf(text));
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Share'), findsNothing);

      await pump(tester, pastedOf(text));
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Tampal'), findsNothing);
      expect(find.textContaining('clipboard'), findsNothing);
    });

    testWidgets('shows no detection, action or Save yet', (tester) async {
      // M2.1 proves the entry points only. Those arrive at M3, M4 and M5a.
      await pump(tester, sharedOf('012-3456789'));

      expect(find.text('Save'), findsNothing);
      expect(find.text('Simpan'), findsNothing);
      expect(find.text('Call'), findsNothing);
      expect(find.text('Open'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders markup as literal characters', (tester) async {
      // Untrusted input. Nothing is interpreted; there is no WebView and no
      // rich-text parsing anywhere in TINDAK.
      const markup = '<script>alert(1)</script>';
      await pump(tester, pastedOf(markup));

      expect(find.text(markup), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders unicode and emoji without error', (tester) async {
      const text = 'Bayar RM1,500 sebelum 25 Ogos 你好 مرحبا 🇲🇾💰';
      await pump(tester, sharedOf(text));

      expect(find.text(text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls long text instead of overflowing', (tester) async {
      final long = List<String>.generate(200, (i) => 'Baris $i').join('\n');
      await pump(tester, pastedOf(long));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('clips a very large intake and says so', (tester) async {
      final huge = 'a' * (IntakeResultScreen.displayLimit + 500);
      await pump(tester, pastedOf(huge));

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining(
          '${IntakeResultScreen.displayLimit} aksara pertama',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('${huge.length}'), findsOneWidget);
    });

    testWidgets('applies the same limit to a share and a paste',
        (tester) async {
      final huge = 'a' * (IntakeResultScreen.displayLimit + 1);

      await pump(tester, sharedOf(huge));
      expect(find.textContaining('aksara pertama'), findsOneWidget);

      await pump(tester, pastedOf(huge));
      expect(find.textContaining('aksara pertama'), findsOneWidget);
    });

    testWidgets('does not clip text at the limit', (tester) async {
      final exact = 'a' * IntakeResultScreen.displayLimit;
      await pump(tester, sharedOf(exact));

      expect(find.textContaining('aksara pertama'), findsNothing);
    });

    testWidgets('offers a close control only when one is supplied',
        (tester) async {
      await pump(tester, sharedOf('x'));
      expect(find.byIcon(Icons.close), findsNothing);

      var closed = false;
      await pump(tester, sharedOf('x'), onClose: () => closed = true);
      await tester.tap(find.byIcon(Icons.close));

      expect(closed, isTrue);
    });

    testWidgets('renders in a narrow viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(
        tester,
        sharedOf('Bayar bil TNB RM183.50 sebelum 25 September'),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
