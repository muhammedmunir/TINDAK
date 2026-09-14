import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

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
  bool understand = true,
  VoidCallback? onClose,
  void Function(ActionDescriptor action)? onAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IntakeResultScreen(
        incoming: incoming,
        understanding: understand
            ? const UnderstandingEngine().understand(incoming.text)
            : null,
        onAction: onAction,
        onClose: onClose,
      ),
    ),
  );
}

void main() {
  group('IntakeResultScreen — received text', () {
    testWidgets('shows the received text', (tester) async {
      await pump(tester, sharedOf('Bayar bil TNB sebelum 25 September'));

      expect(find.text('Bayar bil TNB sebelum 25 September'), findsOneWidget);
    });

    testWidgets('looks the same for a paste as for a share', (tester) async {
      const text = 'Hubungi 012-3456789';

      await pump(tester, sharedOf(text));
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Share'), findsNothing);

      await pump(tester, pastedOf(text));
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Tampal'), findsNothing);
      expect(find.textContaining('clipboard'), findsNothing);
    });

    testWidgets('renders markup as literal characters', (tester) async {
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
        find.textContaining('${IntakeResultScreen.displayLimit} aksara pertama'),
        findsOneWidget,
      );
    });

    testWidgets('does not clip text at the limit', (tester) async {
      await pump(tester, sharedOf('a' * IntakeResultScreen.displayLimit));

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
        sharedOf('Hubungi 012-3456789 atau https://example.com/panjang/sekali'),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('IntakeResultScreen — understanding (M3)', () {
    testWidgets('shows a detected phone', (tester) async {
      await pump(tester, sharedOf('Hubungi Ahmad 012-345 6789 esok'));

      expect(find.text('Dikesan'), findsOneWidget);
      expect(find.text('012-345 6789'), findsOneWidget);
      expect(find.text('Telefon'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    });

    testWidgets('shows a detected link by its host', (tester) async {
      // UX section 6.
      await pump(tester, sharedOf('Lihat https://example.com/promo/abc'));

      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Pautan'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('shows every entity, not just one (PD-002)', (tester) async {
      await pump(tester, sharedOf('Hubungi 012-3456789 atau https://a.com.my'));

      expect(find.text('Telefon'), findsOneWidget);
      expect(find.text('Pautan'), findsOneWidget);
    });

    testWidgets('a paste is understood exactly like a share', (tester) async {
      await pump(tester, pastedOf('Hubungi 012-3456789'));

      expect(find.text('Telefon'), findsOneWidget);
    });

    testWidgets('shows the approved message when nothing is detected',
        (tester) async {
      await pump(tester, sharedOf('Tiada apa-apa di sini'));

      expect(
        find.text(IntakeResultScreen.nothingDetectedMessage),
        findsOneWidget,
      );
      expect(find.text('Dikesan'), findsNothing);
    });

    testWidgets('an IC number is never shown as a phone (PD-029)',
        (tester) async {
      await pump(tester, sharedOf('No IC 900101-03-1234'));

      expect(find.text('Telefon'), findsNothing);
      expect(
        find.text(IntakeResultScreen.nothingDetectedMessage),
        findsOneWidget,
      );
    });

    testWidgets('a bare domain is not shown as a link (PD-027)',
        (tester) async {
      await pump(tester, sharedOf('Jumpa di kedai.my esok'));

      expect(find.text('Pautan'), findsNothing);
    });

    testWidgets('shows no understanding section when none is supplied',
        (tester) async {
      await pump(tester, sharedOf('012-3456789'), understand: false);

      expect(find.text('Dikesan'), findsNothing);
      expect(
        find.text(IntakeResultScreen.nothingDetectedMessage),
        findsNothing,
      );
    });
  });

  group('IntakeResultScreen — M4 actions', () {
    testWidgets('a mobile offers Call and WhatsApp', (tester) async {
      await pump(tester, sharedOf('012-3456789'), onAction: (_) {});

      expect(find.widgetWithText(OutlinedButton, 'Call'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'WhatsApp'), findsOneWidget);
    });

    testWidgets('a landline offers Call only', (tester) async {
      await pump(tester, sharedOf('03-1234 5678'), onAction: (_) {});

      expect(find.widgetWithText(OutlinedButton, 'Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('a link offers Open', (tester) async {
      await pump(tester, sharedOf('https://example.com'), onAction: (_) {});

      expect(find.widgetWithText(OutlinedButton, 'Open'), findsOneWidget);
    });

    testWidgets('offers nothing outside M4', (tester) async {
      await pump(
        tester,
        sharedOf('Hubungi 012-3456789 atau https://example.com'),
        onAction: (_) {},
      );

      for (final label in <String>[
        'Save', 'Simpan', 'Security Check', 'Semak', 'Reminder', 'Remind',
        'Copy', 'Salin', 'Try AI',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('rendering calls no action', (tester) async {
      final taken = <ActionDescriptor>[];

      await pump(
        tester,
        sharedOf('Hubungi 012-3456789 atau https://example.com'),
        onAction: taken.add,
      );
      await tester.pumpAndSettle();

      expect(taken, isEmpty);
    });

    testWidgets('pressing a button calls exactly that action once',
        (tester) async {
      final taken = <ActionDescriptor>[];
      await pump(tester, sharedOf('012-3456789'), onAction: taken.add);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Call'));
      await tester.pump();

      expect(taken, hasLength(1));
      expect(taken.single.kind, ActionKind.call);
      expect(taken.single.entity.normalizedValue, '+60123456789');
    });

    testWidgets('each row acts on its own entity, never another',
        (tester) async {
      final taken = <ActionDescriptor>[];
      await pump(
        tester,
        sharedOf('Ali 012-3456789, Siti 019-8765432, pejabat 03-1234 5678'),
        onAction: taken.add,
      );

      final calls = find.widgetWithText(OutlinedButton, 'Call');
      expect(calls, findsNWidgets(3));

      await tester.tap(calls.at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'WhatsApp').at(0));
      await tester.pump();
      await tester.tap(calls.at(2));
      await tester.pump();

      expect(taken.map((a) => '${a.kind.name}:${a.entity.normalizedValue}'),
          <String>[
        'call:+60198765432',
        'whatsapp:+60123456789',
        'call:+60312345678',
      ]);
    });

    testWidgets('tapping a detected value does not act', (tester) async {
      // The row is information. A user tapping a number to read it must not
      // find the dialer open.
      final taken = <ActionDescriptor>[];
      await pump(
        tester,
        sharedOf('Hubungi 012-3456789 atau https://example.com'),
        onAction: taken.add,
      );

      await tester.tap(find.text('012-3456789'));
      await tester.tap(find.text('example.com'));
      await tester.tap(find.text('Telefon'));
      await tester.pumpAndSettle();

      expect(taken, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without an action handler no buttons are shown',
        (tester) async {
      await pump(tester, sharedOf('012-3456789'));

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Telefon'), findsOneWidget);
    });

    testWidgets('buttons fit a narrow viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(
        tester,
        sharedOf('011-12345678 https://www.example.com.my/panjang'),
        onAction: (_) {},
      );

      expect(tester.takeException(), isNull);
    });
  });
}
