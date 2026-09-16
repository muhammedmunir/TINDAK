import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/executor/clipboard_writer.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/actions/resolver/action_uri_builder.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// Salin and Ingatkan (M6b).
///
/// Money copies the canonical amount; a date says plainly that reminders are
/// not here yet and schedules nothing.
void main() {
  const resolver = ActionResolver();
  const builder = ActionUriBuilder();

  DetectedEntity money(String sen) => DetectedEntity(
    type: EntityType.money,
    rawValue: 'RM183.50',
    normalizedValue: 'MYR$sen',
    confidence: 0.95,
    start: 0,
    end: 8,
  );

  DetectedEntity date(String iso) => DetectedEntity(
    type: EntityType.date,
    rawValue: '25/09/2026',
    normalizedValue: iso,
    confidence: 0.95,
    start: 0,
    end: 10,
  );

  group('resolver', () {
    test('money offers Salin, and nothing else', () {
      final actions = resolver.resolve(money('18350'));

      expect(actions.map((a) => a.kind), <ActionKind>[ActionKind.copy]);
    });

    test('date offers Ingatkan, and nothing else', () {
      final actions = resolver.resolve(date('2026-09-25'));

      expect(actions.map((a) => a.kind), <ActionKind>[ActionKind.remind]);
    });

    test('phone and URL actions are unchanged (M4)', () {
      final phone = DetectedEntity(
        type: EntityType.phone,
        rawValue: '012-345 6789',
        normalizedValue: '+60123456789',
        confidence: 0.95,
        start: 0,
        end: 12,
      );
      final url = DetectedEntity(
        type: EntityType.url,
        rawValue: 'https://tnb.com.my',
        normalizedValue: 'https://tnb.com.my',
        confidence: 0.95,
        start: 0,
        end: 18,
      );

      expect(resolver.resolve(phone).map((a) => a.kind), <ActionKind>[
        ActionKind.call,
        ActionKind.whatsapp,
      ]);
      expect(resolver.resolve(url).map((a) => a.kind), <ActionKind>[
        ActionKind.openUrl,
      ]);
    });

    test('an action always carries its own entity', () {
      final first = money('2500');
      final second = money('5000');

      expect(resolver.resolve(first).single.entity, first);
      expect(resolver.resolve(second).single.entity, second);
    });
  });

  group('no URI is ever built for these', () {
    test('Salin and Ingatkan launch nothing', () {
      expect(
        builder.build(
          ActionDescriptor(kind: ActionKind.copy, entity: money('18350')),
        ),
        isNull,
      );
      expect(
        builder.build(
          ActionDescriptor(kind: ActionKind.remind, entity: date('2026-09-25')),
        ),
        isNull,
      );
    });
  });

  group('Salin', () {
    test('copies the canonical amount, not the raw span', () async {
      final clipboard = _RecordingClipboard();
      final launcher = _RecordingLauncher();
      final runner = ActionRunner(launcher, clipboard: clipboard);

      final outcome = await runner.run(
        ActionDescriptor(kind: ActionKind.copy, entity: money('2500')),
      );

      expect(outcome, ActionOutcome.copied);
      expect(clipboard.written, <String>['RM25.00']);
      expect(launcher.launched, isEmpty);
    });

    test('copies grouped thousands as displayed', () async {
      final clipboard = _RecordingClipboard();
      final runner = ActionRunner(_RecordingLauncher(), clipboard: clipboard);

      await runner.run(
        ActionDescriptor(kind: ActionKind.copy, entity: money('150000')),
      );

      expect(clipboard.written.single, 'RM1,500.00');
    });

    test('a refused clipboard is reported, never claimed as done', () async {
      final clipboard = _RecordingClipboard(succeeds: false);
      final runner = ActionRunner(_RecordingLauncher(), clipboard: clipboard);

      final outcome = await runner.run(
        ActionDescriptor(kind: ActionKind.copy, entity: money('2500')),
      );

      expect(outcome, ActionOutcome.unavailable);
    });

    test('a clipboard that throws does not crash the app', () async {
      final runner = ActionRunner(
        _RecordingLauncher(),
        clipboard: _ThrowingClipboard(),
      );

      expect(
        await runner.run(
          ActionDescriptor(kind: ActionKind.copy, entity: money('2500')),
        ),
        ActionOutcome.unavailable,
      );
    });

    test('an unreadable amount is refused, and nothing is copied', () async {
      final clipboard = _RecordingClipboard();
      final runner = ActionRunner(_RecordingLauncher(), clipboard: clipboard);
      final broken = DetectedEntity(
        type: EntityType.money,
        rawValue: 'RM1',
        normalizedValue: 'USD100',
        confidence: 0.9,
        start: 0,
        end: 3,
      );

      final outcome = await runner.run(
        ActionDescriptor(kind: ActionKind.copy, entity: broken),
      );

      expect(outcome, ActionOutcome.rejected);
      expect(clipboard.written, isEmpty);
    });

    test('a failure logs no amount', () async {
      final logged = <String>[];
      AppLogger.testSink = (name, message) => logged.add(message);
      addTearDown(() => AppLogger.testSink = null);

      final runner = ActionRunner(
        _RecordingLauncher(),
        clipboard: _RecordingClipboard(succeeds: false),
      );
      await runner.run(
        ActionDescriptor(kind: ActionKind.copy, entity: money('18350')),
      );

      expect(logged, isNotEmpty);
      for (final line in logged) {
        expect(line, isNot(contains('183.50')));
        expect(line, isNot(contains('18350')));
      }
    });
  });

  group('Ingatkan', () {
    test('schedules nothing, launches nothing, copies nothing', () async {
      final clipboard = _RecordingClipboard();
      final launcher = _RecordingLauncher();
      final runner = ActionRunner(launcher, clipboard: clipboard);

      final outcome = await runner.run(
        ActionDescriptor(kind: ActionKind.remind, entity: date('2026-09-25')),
      );

      expect(outcome, ActionOutcome.notYetAvailable);
      expect(launcher.launched, isEmpty);
      expect(clipboard.written, isEmpty);
    });

    test('is repeatable and leaves no state behind', () async {
      final runner = ActionRunner(
        _RecordingLauncher(),
        clipboard: _RecordingClipboard(),
      );
      final action = ActionDescriptor(
        kind: ActionKind.remind,
        entity: date('2026-09-25'),
      );

      expect(await runner.run(action), ActionOutcome.notYetAvailable);
      expect(await runner.run(action), ActionOutcome.notYetAvailable);
    });
  });

  group('nothing runs without a tap', () {
    test('resolving actions writes nothing to the clipboard', () {
      final clipboard = _RecordingClipboard();
      ActionRunner(_RecordingLauncher(), clipboard: clipboard);

      resolver
        ..resolve(money('18350'))
        ..resolve(date('2026-09-25'));

      expect(clipboard.written, isEmpty);
    });
  });
}

final class _RecordingClipboard implements ClipboardWriter {
  _RecordingClipboard({this.succeeds = true});

  final bool succeeds;
  final List<String> written = <String>[];

  @override
  Future<bool> writePlainText(String text) async {
    if (!succeeds) return false;
    written.add(text);
    return true;
  }
}

final class _ThrowingClipboard implements ClipboardWriter {
  @override
  Future<bool> writePlainText(String text) async => throw StateError('refused');
}

final class _RecordingLauncher implements ExternalLauncher {
  final List<String> launched = <String>[];

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri.toString());
    return true;
  }
}
