import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/share/share_channel.dart';
import 'package:tindak/features/share/share_controller.dart';
import 'package:tindak/features/share/shared_text.dart';

/// A share channel under test control, with no platform behind it.
final class FakeShareChannel implements ShareChannel {
  FakeShareChannel({this.initial});

  SharedText? initial;
  int initialShareCalls = 0;
  void Function(SharedText share)? _handler;

  @override
  Future<SharedText?> initialShare() async {
    initialShareCalls += 1;
    final share = initial;
    // Matches the platform contract: handed over exactly once.
    initial = null;
    return share;
  }

  @override
  void onShareReceived(void Function(SharedText share) handler) {
    _handler = handler;
  }

  /// Simulates a share arriving while the app is already running.
  void emit(SharedText share) => _handler?.call(share);
}

SharedText share(int sequence, [String text = 'Bayar bil TNB']) => SharedText(
  sequence: sequence,
  text: text,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(sequence * 1000),
);

void main() {
  late FakeShareChannel channel;
  late ProviderContainer container;

  ShareController controller() =>
      container.read(shareControllerProvider.notifier);
  SharedText? current() => container.read(shareControllerProvider);

  setUp(() {
    channel = FakeShareChannel();
    container = ProviderContainer(
      overrides: [shareChannelProvider.overrideWithValue(channel)],
    );
    addTearDown(container.dispose);
  });

  group('cold start', () {
    test('with no share the app stays on Home', () async {
      await controller().start();

      expect(current(), isNull);
    });

    test('a launching share becomes the current share', () async {
      channel.initial = share(1);

      await controller().start();

      expect(current(), isNotNull);
      expect(current()!.text, 'Bayar bil TNB');
      expect(current()!.sequence, 1);
    });

    test('the initial share is requested exactly once', () async {
      channel.initial = share(1);

      await controller().start();

      expect(channel.initialShareCalls, 1);
    });
  });

  group('already running', () {
    test('a new share replaces the current one', () async {
      channel.initial = share(1, 'first');
      await controller().start();

      channel.emit(share(2, 'second'));

      expect(current()!.text, 'second');
      expect(current()!.sequence, 2);
    });

    test('a share arrives even when the app started without one', () async {
      await controller().start();

      channel.emit(share(1, 'warm'));

      expect(current()!.text, 'warm');
    });
  });

  group('no duplicate processing', () {
    test('the same sequence delivered twice is handled once', () async {
      await controller().start();
      var notifications = 0;
      container.listen(shareControllerProvider, (_, _) => notifications += 1);

      final same = share(5, 'once');
      channel.emit(same);
      channel.emit(same);

      expect(notifications, 1);
      expect(current()!.text, 'once');
    });

    test('an older sequence is ignored', () async {
      await controller().start();

      channel.emit(share(9, 'newest'));
      channel.emit(share(4, 'stale'));

      expect(current()!.text, 'newest');
    });

    test('initial share and a racing new-intent callback yield one result',
        () async {
      // Cold start can describe the same share through both paths. The
      // sequence is what makes the second delivery a no-op.
      final launching = share(1, 'launched');
      channel.initial = launching;

      final future = controller().start();
      channel.emit(launching);
      await future;

      expect(current()!.text, 'launched');
      expect(current()!.sequence, 1);
    });

    test('a share dismissed by the user cannot be redelivered', () async {
      channel.initial = share(3, 'seen');
      await controller().start();

      controller().clear();
      expect(current(), isNull);

      // A lifecycle event replaying the same intent must not resurrect it.
      channel.emit(share(3, 'seen'));

      expect(current(), isNull);
    });

    test('a genuinely new share still arrives after a clear', () async {
      channel.initial = share(3, 'seen');
      await controller().start();
      controller().clear();

      channel.emit(share(4, 'new one'));

      expect(current()!.text, 'new one');
    });
  });

  group('failure is safe', () {
    test('a channel that throws leaves the app on Home', () async {
      final broken = _ThrowingShareChannel();
      final brokenContainer = ProviderContainer(
        overrides: [shareChannelProvider.overrideWithValue(broken)],
      );
      addTearDown(brokenContainer.dispose);

      // start() must never throw into the widget tree. A share that cannot be
      // read leaves the user on Home, not on a crashed app.
      await brokenContainer.read(shareControllerProvider.notifier).start();

      expect(brokenContainer.read(shareControllerProvider), isNull);
    });
  });
}

final class _ThrowingShareChannel implements ShareChannel {
  @override
  Future<SharedText?> initialShare() async =>
      throw StateError('platform unavailable');

  @override
  void onShareReceived(void Function(SharedText share) handler) {}
}
