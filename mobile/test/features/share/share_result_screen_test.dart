import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/share/share_result_screen.dart';
import 'package:tindak/features/share/shared_text.dart';

SharedText shareOf(String text) => SharedText(
  sequence: 1,
  text: text,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

Future<void> pump(WidgetTester tester, SharedText share,
    {VoidCallback? onClose}) async {
  await tester.pumpWidget(
    MaterialApp(home: ShareResultScreen(share: share, onClose: onClose)),
  );
}

void main() {
  group('ShareResultScreen', () {
    testWidgets('shows the received text', (tester) async {
      await pump(tester, shareOf('Bayar bil TNB RM183.50 sebelum 25 September'));

      expect(
        find.text('Bayar bil TNB RM183.50 sebelum 25 September'),
        findsOneWidget,
      );
    });

    testWidgets('shows no detection, action or Save yet', (tester) async {
      // M2 proves the entry point only. Those arrive at M3, M4 and M5a, and
      // adding them early would be scope creep past the milestone gate.
      await pump(tester, shareOf('012-3456789'));

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
      await pump(tester, shareOf(markup));

      expect(find.text(markup), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders unicode and emoji without error', (tester) async {
      const text = 'Bayar RM1,500 sebelum 25 Ogos 你好 مرحبا 🇲🇾💰';
      await pump(tester, shareOf(text));

      expect(find.text(text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls long text instead of overflowing', (tester) async {
      final long = List<String>.generate(200, (i) => 'Baris $i').join('\n');
      await pump(tester, shareOf(long));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('clips a very large share and says so', (tester) async {
      final huge = 'a' * (ShareResultScreen.displayLimit + 500);
      await pump(tester, shareOf(huge));

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('${ShareResultScreen.displayLimit} aksara pertama'),
        findsOneWidget,
      );
      expect(find.textContaining('${huge.length}'), findsOneWidget);
    });

    testWidgets('does not clip text at the limit', (tester) async {
      final exact = 'a' * ShareResultScreen.displayLimit;
      await pump(tester, shareOf(exact));

      expect(find.textContaining('aksara pertama'), findsNothing);
    });

    testWidgets('offers a close control only when one is supplied',
        (tester) async {
      await pump(tester, shareOf('x'));
      expect(find.byIcon(Icons.close), findsNothing);

      var closed = false;
      await pump(tester, shareOf('x'), onClose: () => closed = true);
      await tester.tap(find.byIcon(Icons.close));

      expect(closed, isTrue);
    });

    testWidgets('renders in a narrow viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester, shareOf('Bayar bil TNB RM183.50 sebelum 25 September'));

      expect(tester.takeException(), isNull);
    });
  });
}
