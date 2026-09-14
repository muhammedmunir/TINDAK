import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/executor/external_launcher.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// Records every URI handed to Android.
final class RecordingLauncher implements ExternalLauncher {
  final List<Uri> launched = <Uri>[];
  bool result = true;
  Exception? throwException;
  Error? throwError;
  Completer<bool>? gate;

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    if (throwException != null) throw throwException!;
    if (throwError != null) throw throwError!;
    if (gate != null) return gate!.future;
    return result;
  }
}

ActionDescriptor callFor(String e164) => ActionDescriptor(
  kind: ActionKind.call,
  entity: DetectedEntity(
    type: EntityType.phone,
    rawValue: e164,
    normalizedValue: e164,
    confidence: 0.95,
    start: 0,
    end: 1,
  ),
);

void main() {
  late RecordingLauncher launcher;
  late ActionRunner runner;

  setUp(() {
    launcher = RecordingLauncher();
    runner = ActionRunner(launcher);
  });

  test('a valid action launches exactly its URI', () async {
    final outcome = await runner.run(callFor('+60123456789'));

    expect(outcome, ActionOutcome.launched);
    expect(launcher.launched.map((u) => u.toString()), <String>[
      'tel:+60123456789',
    ]);
  });

  test('a rejected value never reaches the launcher', () async {
    final outcome = await runner.run(callFor('*21*0123456789#'));

    expect(outcome, ActionOutcome.rejected);
    expect(launcher.launched, isEmpty);
  });

  test('no app to handle it fails safely', () async {
    launcher.result = false;

    expect(
      await runner.run(callFor('+60123456789')),
      ActionOutcome.unavailable,
    );
  });

  test('a platform exception fails safely', () async {
    launcher.throwException = PlatformException(code: 'ACTIVITY_NOT_FOUND');

    expect(
      await runner.run(callFor('+60123456789')),
      ActionOutcome.unavailable,
    );
  });

  test('any other exception fails safely', () async {
    launcher.throwError = StateError('boom');

    expect(
      await runner.run(callFor('+60123456789')),
      ActionOutcome.unavailable,
    );
  });

  test('a double tap launches once', () async {
    launcher.gate = Completer<bool>();

    final first = runner.run(callFor('+60123456789'));
    final second = await runner.run(callFor('+60123456789'));

    expect(second, ActionOutcome.busy);
    launcher.gate!.complete(true);
    expect(await first, ActionOutcome.launched);
    expect(launcher.launched, hasLength(1));
  });

  test('a later tap works once the first has finished', () async {
    await runner.run(callFor('+60123456789'));
    await runner.run(callFor('+60123456789'));

    expect(launcher.launched, hasLength(2));
  });

  test('a failure does not leave the runner stuck busy', () async {
    launcher.throwError = StateError('boom');
    await runner.run(callFor('+60123456789'));

    launcher.throwError = null;
    expect(
      await runner.run(callFor('+60123456789')),
      ActionOutcome.launched,
    );
  });

  test('constructing a runner launches nothing', () {
    ActionRunner(launcher);

    expect(launcher.launched, isEmpty);
  });
}
