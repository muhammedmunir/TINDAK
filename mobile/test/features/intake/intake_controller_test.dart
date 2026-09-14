import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/intake/clipboard_reader.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/share/share_channel.dart';

/// A share channel under test control, with no platform behind it.
final class FakeShareChannel implements ShareChannel {
  FakeShareChannel({this.initial});

  IncomingText? initial;
  int initialShareCalls = 0;
  void Function(IncomingText share)? _handler;

  @override
  Future<IncomingText?> initialShare() async {
    initialShareCalls += 1;
    final share = initial;
    // Matches the platform contract: handed over exactly once.
    initial = null;
    return share;
  }

  @override
  void onShareReceived(void Function(IncomingText share) handler) {
    _handler = handler;
  }

  /// Simulates a share arriving while the app is already running.
  void emit(IncomingText share) => _handler?.call(share);
}

/// A clipboard that records every read, so the privacy rule can be asserted
/// rather than assumed.
final class FakeClipboardReader implements ClipboardReader {
  FakeClipboardReader({this.text});

  String? text;
  int reads = 0;
  bool throwOnRead = false;

  @override
  Future<String?> readPlainText() async {
    reads += 1;
    if (throwOnRead) throw StateError('clipboard unavailable');
    return text;
  }
}

IncomingText shareOf(int sequence, [String text = 'Bayar bil TNB']) =>
    IncomingText(
      text: text,
      source: IntakeSource.share,
      sequence: sequence,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(sequence * 1000),
    );

void main() {
  late FakeShareChannel channel;
  late FakeClipboardReader clipboard;
  late ProviderContainer container;

  final fixedNow = DateTime(2026, 9, 11, 8, 30);

  IntakeController controller() =>
      container.read(intakeControllerProvider.notifier);
  IncomingText? current() => container.read(intakeControllerProvider);

  setUp(() {
    channel = FakeShareChannel();
    clipboard = FakeClipboardReader();
    container = ProviderContainer(
      overrides: [
        shareChannelProvider.overrideWithValue(channel),
        clipboardReaderProvider.overrideWithValue(clipboard),
        clockProvider.overrideWithValue(FixedClock(fixedNow)),
      ],
    );
    addTearDown(container.dispose);
  });

  group('share intake', () {
    test('with no share the app stays on Home', () async {
      await controller().start();

      expect(current(), isNull);
    });

    test('a launching share becomes the current text', () async {
      channel.initial = shareOf(1);

      await controller().start();

      expect(current()!.text, 'Bayar bil TNB');
      expect(current()!.source, IntakeSource.share);
    });

    test('a share while running replaces the current text', () async {
      channel.initial = shareOf(1, 'first');
      await controller().start();

      channel.emit(shareOf(2, 'second'));

      expect(current()!.text, 'second');
    });

    test('the same sequence delivered twice is handled once', () async {
      await controller().start();
      var notifications = 0;
      container.listen(intakeControllerProvider, (_, _) => notifications += 1);

      final same = shareOf(5, 'once');
      channel.emit(same);
      channel.emit(same);

      expect(notifications, 1);
    });

    test('an older sequence is ignored', () async {
      await controller().start();

      channel.emit(shareOf(9, 'newest'));
      channel.emit(shareOf(4, 'stale'));

      expect(current()!.text, 'newest');
    });

    test('a dismissed share cannot be redelivered', () async {
      channel.initial = shareOf(3, 'seen');
      await controller().start();
      controller().clear();

      channel.emit(shareOf(3, 'seen'));

      expect(current(), isNull);
    });

    test('a channel that throws leaves the app on Home', () async {
      final broken = _ThrowingShareChannel();
      final brokenContainer = ProviderContainer(
        overrides: [shareChannelProvider.overrideWithValue(broken)],
      );
      addTearDown(brokenContainer.dispose);

      // start() must never throw into the widget tree.
      await brokenContainer.read(intakeControllerProvider.notifier).start();

      expect(brokenContainer.read(intakeControllerProvider), isNull);
    });
  });

  group('clipboard privacy — ADR-004, PD-033', () {
    test('start() never reads the clipboard', () async {
      clipboard.text = 'secret in the clipboard';

      await controller().start();

      expect(clipboard.reads, 0);
      expect(current(), isNull);
    });

    test('a share arriving never reads the clipboard', () async {
      clipboard.text = 'secret in the clipboard';
      await controller().start();

      channel.emit(shareOf(1, 'shared text'));

      expect(clipboard.reads, 0);
    });

    test('clearing never reads the clipboard', () async {
      clipboard.text = 'secret in the clipboard';
      await controller().start();
      channel.emit(shareOf(1, 'shared'));

      controller().clear();

      expect(clipboard.reads, 0);
    });

    test('repeated lifecycle activity never reads the clipboard', () async {
      // Stands in for launch, resume, and anything else that runs without the
      // user asking. No number of these may touch the clipboard.
      clipboard.text = 'secret in the clipboard';

      for (var i = 0; i < 5; i++) {
        await controller().start();
        channel.emit(shareOf(i + 1, 'share $i'));
        controller().clear();
      }

      expect(clipboard.reads, 0);
    });

    test('pressing Tampal reads exactly once', () async {
      clipboard.text = 'Bayar bil TNB RM183.50';

      await controller().paste();

      expect(clipboard.reads, 1);
    });

    test('two presses read twice and never more', () async {
      clipboard.text = 'x';

      await controller().paste();
      await controller().paste();

      expect(clipboard.reads, 2);
    });
  });

  group('paste intake', () {
    test('accepted text becomes the current text', () async {
      clipboard.text = 'Bayar bil TNB RM183.50';

      final outcome = await controller().paste();

      expect(outcome, PasteOutcome.accepted);
      expect(current()!.text, 'Bayar bil TNB RM183.50');
      expect(current()!.source, IntakeSource.paste);
      expect(current()!.receivedAt, fixedNow);
      expect(current()!.sourceApp, isNull);
    });

    test('text is stored exactly as copied', () async {
      const raw = '  Bayar   bil\n\tTNB RM183.50  ';
      clipboard.text = raw;

      await controller().paste();

      expect(current()!.text, raw);
    });

    test('an empty clipboard fails safely', () async {
      clipboard.text = '';

      final outcome = await controller().paste();

      expect(outcome, PasteOutcome.empty);
      expect(current(), isNull);
    });

    test('a whitespace-only clipboard fails safely', () async {
      clipboard.text = '   \n\t  ';

      final outcome = await controller().paste();

      expect(outcome, PasteOutcome.empty);
      expect(current(), isNull);
    });

    test('a non-text clipboard fails safely', () async {
      // Clipboard.getData returns null when there is no plain text — an image,
      // for instance.
      clipboard.text = null;

      final outcome = await controller().paste();

      expect(outcome, PasteOutcome.unavailable);
      expect(current(), isNull);
    });

    test('a clipboard read that throws fails safely', () async {
      clipboard.throwOnRead = true;

      final outcome = await controller().paste();

      expect(outcome, PasteOutcome.unavailable);
      expect(current(), isNull);
    });

    test('a failed paste leaves an existing result untouched', () async {
      channel.initial = shareOf(1, 'shared earlier');
      await controller().start();
      clipboard.text = '';

      await controller().paste();

      expect(current()!.text, 'shared earlier');
    });

    test('a paste replaces a share', () async {
      channel.initial = shareOf(1, 'shared');
      await controller().start();
      clipboard.text = 'pasted';

      await controller().paste();

      expect(current()!.text, 'pasted');
      expect(current()!.source, IntakeSource.paste);
    });

    test('a paste never blocks a later share', () async {
      // Regression guard. If paste shared the share counter, a paste would
      // raise the bar and silently swallow a genuine later share whose
      // Android-assigned sequence is lower.
      await controller().start();
      clipboard.text = 'pasted';
      await controller().paste();
      await controller().paste();
      await controller().paste();

      channel.emit(shareOf(1, 'a real share'));

      expect(current()!.text, 'a real share');
      expect(current()!.source, IntakeSource.share);
    });

    test('a large clipboard is accepted whole', () async {
      clipboard.text = 'a' * 500000;

      await controller().paste();

      expect(current()!.characterCount, 500000);
    });
  });
}

final class _ThrowingShareChannel implements ShareChannel {
  @override
  Future<IncomingText?> initialShare() async =>
      throw StateError('platform unavailable');

  @override
  void onShareReceived(void Function(IncomingText share) handler) {}
}
