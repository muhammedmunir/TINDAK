import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

DetectedEntity only(String text) =>
    const UnderstandingEngine().understand(text).entities.single;

void main() {
  const resolver = ActionResolver();

  List<ActionKind> kinds(DetectedEntity e) =>
      resolver.resolve(e).map((a) => a.kind).toList();

  group('ActionResolver — M4 scope', () {
    test('a mobile offers Call and WhatsApp', () {
      expect(kinds(only('012-3456789')), <ActionKind>[
        ActionKind.call,
        ActionKind.whatsapp,
      ]);
    });

    test('an eleven-digit mobile offers Call and WhatsApp', () {
      expect(kinds(only('011-12345678')), <ActionKind>[
        ActionKind.call,
        ActionKind.whatsapp,
      ]);
    });

    test('a landline offers Call only — no WhatsApp behind it', () {
      expect(kinds(only('03-1234 5678')), <ActionKind>[ActionKind.call]);
      expect(kinds(only('082-123456')), <ActionKind>[ActionKind.call]);
    });

    test('a link offers Open', () {
      expect(kinds(only('https://example.com')), <ActionKind>[
        ActionKind.openUrl,
      ]);
    });

    test('every action is bound to the entity it came from', () {
      final entities = const UnderstandingEngine()
          .understand('0123456789 0198765432 https://a.com')
          .entities;

      for (final e in entities) {
        for (final a in resolver.resolve(e)) {
          expect(identical(a.entity, e) || a.entity == e, isTrue);
        }
      }
    });

    test('offers nothing beyond the shipped milestones', () {
      // M4 shipped the first three, M6b added Salin and Ingatkan. A real
      // reminder is M7, Security Check M8, Try AI M9 — none of them may
      // appear here early.
      expect(ActionKind.values, <ActionKind>[
        ActionKind.call,
        ActionKind.whatsapp,
        ActionKind.openUrl,
        ActionKind.copy,
        ActionKind.remind,
      ]);
    });
  });

  test('ActionDescriptor toString omits the value', () {
    final a = resolver.resolve(only('012-3456789')).first;

    expect(a.toString(), isNot(contains('3456789')));
    expect(a.toString(), contains('call'));
  });
}
