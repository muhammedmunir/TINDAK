import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

/// What a person sees for money and dates, and which button belongs to which
/// entity when a message carries all four kinds (M6b).
void main() {
  const resolver = ActionResolver();
  final engine = UnderstandingEngine.withClock(
    FixedClock(DateTime(2026, 9, 10)),
  );

  Future<List<ActionDescriptor>> pumpEntities(
    WidgetTester tester,
    String input,
  ) async {
    final tapped = <ActionDescriptor>[];
    final entities = engine.understand(input).entities;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              for (final entity in entities)
                EntityRow(
                  entity: entity,
                  actions: resolver.resolve(entity),
                  onAction: tapped.add,
                ),
            ],
          ),
        ),
      ),
    );
    return tapped;
  }

  testWidgets('money shows the canonical amount, labelled Wang, with Salin',
      (tester) async {
    await pumpEntities(tester, 'bayar rm25 sekarang');

    expect(find.text('RM25.00'), findsOneWidget);
    expect(find.text('Wang'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Salin'), findsOneWidget);
  });

  testWidgets('a date shows the full resolved date, labelled Tarikh, with '
      'Ingatkan', (tester) async {
    await pumpEntities(tester, 'Temujanji 25/09/2026');

    expect(find.text('25 September 2026'), findsOneWidget);
    expect(find.text('Tarikh'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ingatkan'), findsOneWidget);
  });

  testWidgets('a date with no year shows the year TINDAK resolved',
      (tester) async {
    await pumpEntities(tester, 'Mesyuarat 25 Ogos');

    expect(find.text('25 Ogos 2027'), findsOneWidget);
  });

  testWidgets('all four kinds, each with its own actions', (tester) async {
    await pumpEntities(
      tester,
      'Bayar bil TNB RM183.50 sebelum 25/09/2026. '
      'Hubungi 012-345 6789 atau buka https://tnb.com.my',
    );

    expect(find.text('Wang'), findsOneWidget);
    expect(find.text('Tarikh'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('Pautan'), findsOneWidget);

    expect(find.widgetWithText(OutlinedButton, 'Salin'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ingatkan'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Panggil'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'WhatsApp'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Buka'), findsOneWidget);
  });

  testWidgets('each button carries its own entity', (tester) async {
    final tapped = await pumpEntities(
      tester,
      'RM25 pada 25/09/2026 dan RM50 kemudian',
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Salin').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salin').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ingatkan'));
    await tester.pump();

    expect(tapped.map((a) => a.kind), <ActionKind>[
      ActionKind.copy,
      ActionKind.copy,
      ActionKind.remind,
    ]);
    // The first Salin can only ever copy the first amount.
    expect(tapped[0].entity.normalizedValue, 'MYR2500');
    expect(tapped[1].entity.normalizedValue, 'MYR5000');
    expect(tapped[2].entity.normalizedValue, '2026-09-25');
  });

  testWidgets('nothing is tapped on its own', (tester) async {
    final tapped = await pumpEntities(
      tester,
      'RM183.50 pada 25/09/2026',
    );
    await tester.pump(const Duration(seconds: 2));

    expect(tapped, isEmpty);
  });

  testWidgets('a summary row shows the canonical forms', (tester) async {
    final entities = engine
        .understand('RM1,500 pada 3/4/2026')
        .entities
        .toList();

    expect(
      entities.map(EntityRow.displayValue),
      <String>['RM1,500.00', '3 April 2026'],
    );
  });

  testWidgets('an entity prints no value', (tester) async {
    final entity = engine.understand('RM183.50').entities.single;

    expect(entity.toString(), isNot(contains('183.50')));
    expect(entity.toString(), isNot(contains('18350')));
  });

  test('approved copy is exactly as Product Direction wrote it', () {
    expect(
      reminderComingSoonMessage,
      'Peringatan akan tersedia dalam kemas kini akan datang.',
    );
    expect(copiedMessage, 'Disalin.');
  });
}
