import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/auth/sign_in_screen.dart';
import 'package:tindak/features/home/home_screen.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/settings/settings_screen.dart';
import 'package:tindak/features/sync/sync_providers.dart';
import 'package:tindak/features/sync/widgets/sync_dialogs.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';

import '../../app/tindak_app_test.dart'
    show FakeShareChannel, pumpApp;
import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

const Account alice = Account(id: 'user-alice', email: 'alice@example.com');

void main() {
  late TindakDatabase db;
  late FakeCloud cloud;

  setUp(() {
    db = openTestDatabase();
    cloud = FakeCloud();
  });

  Future<String> seed(String text, {String? owner}) async {
    final repo = DriftMemoryRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 9, 15)),
      currentUserId: () => owner,
    );
    final result = await repo.save(
      incoming: IncomingText.pasted(text, at: DateTime.utc(2026, 9, 15)),
      understanding: const UnderstandingEngine().understand(text),
    );
    return result.valueOrNull!;
  }

  Future<List<MemoryRow>> rows() => db.select(db.memories).get();

  Future<FakeAuthGateway> pump(
    WidgetTester tester, {
    Account? account,
    bool cloudConfigured = true,
  }) async {
    final gateway = FakeAuthGateway(account: account, cloud: cloud);
    await pumpApp(
      tester,
      FakeShareChannel(),
      database: db,
      overrides: [
        if (cloudConfigured) ...[
          authGatewayProvider.overrideWithValue(gateway),
          cloudMemoryApiProvider.overrideWithValue(cloud),
        ],
      ],
    );
    return gateway;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip(HomeScreen.settingsTooltip));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, SettingsScreen.signIn));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('sign-in-email')),
      'alice@example.com',
    );
    await tester.tap(find.text(SignInScreen.sendCode));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('sign-in-code')),
      '123456',
    );
    await tester.tap(find.text(SignInScreen.verify));
    await tester.pumpAndSettle();
  }

  group('Settings — PD-043', () {
    testWidgets('a build without cloud configuration says so, and nothing '
        'else changes', (tester) async {
      await pump(tester, cloudConfigured: false);
      await openSettings(tester);

      expect(find.text(SettingsScreen.unavailable), findsNWidgets(2));
      expect(find.text(SettingsScreen.signIn), findsNothing);
    });

    testWidgets('a guest sees Log Masuk, and no sync controls', (tester) async {
      await pump(tester);
      await openSettings(tester);

      expect(find.text(SettingsScreen.accountSection), findsOneWidget);
      expect(find.text(SettingsScreen.syncSection), findsOneWidget);
      expect(find.widgetWithText(FilledButton, SettingsScreen.signIn),
          findsOneWidget);
      expect(find.text(SettingsScreen.syncNow), findsNothing);
    });
  });

  group('sign-in and guest migration — PD-044', () {
    testWidgets('no prompt when there are no guest items', (tester) async {
      await pump(tester);
      await openSettings(tester);
      await signIn(tester);

      expect(find.text(SyncCopy.migrateTitle), findsNothing);
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('the prompt counts the items on this device', (tester) async {
      await seed('satu');
      await seed('dua');
      await pump(tester);
      await openSettings(tester);
      await signIn(tester);

      expect(find.text(SyncCopy.migrateTitle), findsOneWidget);
      expect(find.text(SyncCopy.migrateBody(2)), findsOneWidget);
      expect(find.textContaining('Anda mempunyai 2 item'), findsOneWidget);
    });

    testWidgets('Bukan Sekarang changes nothing and uploads nothing',
        (tester) async {
      await seed('satu');
      await seed('dua');
      await pump(tester);
      await openSettings(tester);
      await signIn(tester);

      await tester.tap(find.text(SyncCopy.notNow));
      await tester.pumpAndSettle();

      expect((await rows()).map((r) => r.ownerUserId), everyElement(isNull));
      expect((await rows()).map((r) => r.syncStatus),
          everyElement('local_only'));
      expect(cloud.rows, isEmpty);
      // Resumable later, from Settings.
      expect(find.text(SettingsScreen.guestItems(2)), findsOneWidget);
    });

    testWidgets('Sync moves the items into the account and uploads them',
        (tester) async {
      await seed('satu');
      await pump(tester);
      await openSettings(tester);
      await signIn(tester);

      await tester.tap(find.widgetWithText(FilledButton, SyncCopy.sync));
      await tester.pumpAndSettle();

      final row = (await rows()).single;
      expect(row.ownerUserId, 'user-alice@example.com');
      expect(row.syncStatus, 'synced');
      expect(cloud.rows.keys, <String>[row.id]);
      expect(find.text(SettingsScreen.syncGuestItems), findsNothing);
    });

    testWidgets('a declined migration can be resumed from Settings',
        (tester) async {
      await seed('satu');
      await pump(tester);
      await openSettings(tester);
      await signIn(tester);
      await tester.tap(find.text(SyncCopy.notNow));
      await tester.pumpAndSettle();

      await tester.tap(find.text(SettingsScreen.syncGuestItems));
      await tester.pumpAndSettle();
      expect(find.text(SyncCopy.migrateBody(1)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, SyncCopy.sync));
      await tester.pumpAndSettle();

      expect((await rows()).single.syncStatus, 'synced');
    });
  });

  group('sign-out — PD-041, ADR-031', () {
    testWidgets('with everything synced: account items leave the device, '
        'guest items stay', (tester) async {
      await seed('guest');
      await seed('mine', owner: alice.id);
      final gateway = await pump(tester, account: alice);
      await openSettings(tester);
      // The session restored at launch has already synced.
      expect(cloud.rows, hasLength(1));

      await tester.tap(find.text(SettingsScreen.signOut));
      await tester.pumpAndSettle();

      expect(gateway.sessionEnded, isTrue);
      final left = await rows();
      expect(left.single.content, 'guest');
      expect(find.text(SettingsScreen.signedOutMessage), findsOneWidget);
    });

    testWidgets('offline with unsent changes: blocked, nothing deleted, still '
        'signed in', (tester) async {
      cloud.offline = true;
      await seed('guest');
      await seed('unsent', owner: alice.id);
      final gateway = await pump(tester, account: alice);
      await openSettings(tester);

      await tester.tap(find.text(SettingsScreen.signOut));
      await tester.pumpAndSettle();

      expect(find.text(SyncCopy.signOutBlockedTitle), findsOneWidget);
      expect(find.text(SyncCopy.signOutBlockedBody), findsOneWidget);
      expect(find.text(SyncCopy.retry), findsOneWidget);
      expect(find.text(SyncCopy.cancel), findsOneWidget);
      // No way to sign out anyway.
      expect(find.textContaining('anyway'), findsNothing);

      await tester.tap(find.text(SyncCopy.cancel));
      await tester.pumpAndSettle();

      expect(gateway.sessionEnded, isFalse);
      expect(await rows(), hasLength(2));
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('Cuba Lagi once back online syncs, then signs out',
        (tester) async {
      cloud.offline = true;
      final unsent = await seed('unsent', owner: alice.id);
      final gateway = await pump(tester, account: alice);
      await openSettings(tester);
      await tester.tap(find.text(SettingsScreen.signOut));
      await tester.pumpAndSettle();

      cloud.offline = false;
      await tester.tap(find.text(SyncCopy.retry));
      await tester.pumpAndSettle();

      expect(cloud.rows.containsKey(unsent), isTrue);
      expect(gateway.sessionEnded, isTrue);
      expect(await rows(), isEmpty);
    });
  });

  group('sign-in errors', () {
    Future<FakeAuthGateway> openSignIn(WidgetTester tester) async {
      final gateway = await pump(tester);
      await openSettings(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, SettingsScreen.signIn),
      );
      await tester.pumpAndSettle();
      return gateway;
    }

    testWidgets('a malformed email is caught before anything is sent',
        (tester) async {
      final gateway = await openSignIn(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('sign-in-email')),
        'bukan-emel',
      );
      await tester.tap(find.text(SignInScreen.sendCode));
      await tester.pumpAndSettle();

      expect(find.text(SignInScreen.invalidEmailMessage), findsOneWidget);
      expect(gateway.sentCodes, isEmpty);
    });

    for (final (outcome, message) in <(AuthOutcome, String)>[
      (AuthOutcome.offline, SignInScreen.offlineMessage),
      (AuthOutcome.rateLimited, SignInScreen.rateLimitedMessage),
      (AuthOutcome.failed, SignInScreen.failedMessage),
    ]) {
      testWidgets('sending a code: ${outcome.name} is explained',
          (tester) async {
        final gateway = await openSignIn(tester);
        gateway.nextOutcome = outcome;
        await tester.enterText(
          find.byKey(const ValueKey<String>('sign-in-email')),
          'alice@example.com',
        );
        await tester.tap(find.text(SignInScreen.sendCode));
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('sign-in-code')),
            findsNothing);
      });
    }

    testWidgets('a wrong code keeps the user on the code step, signed out',
        (tester) async {
      final gateway = await openSignIn(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('sign-in-email')),
        'alice@example.com',
      );
      await tester.tap(find.text(SignInScreen.sendCode));
      await tester.pumpAndSettle();

      gateway.nextOutcome = AuthOutcome.invalidCode;
      await tester.enterText(
        find.byKey(const ValueKey<String>('sign-in-code')),
        '000000',
      );
      await tester.tap(find.text(SignInScreen.verify));
      await tester.pumpAndSettle();

      expect(find.text(SignInScreen.invalidCodeMessage), findsOneWidget);
      expect(gateway.currentAccount, isNull);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('Memory while signed in', () {
    testWidgets('Home lists guest and account items together, and hides the '
        'device-only notice when nothing is device-only', (tester) async {
      await seed('mine', owner: alice.id);
      await pump(tester, account: alice);

      expect(find.text('mine'), findsOneWidget);
      expect(find.text(HomeScreen.deviceOnlyNotice), findsNothing);
    });

    testWidgets('signing out hides account items at once', (tester) async {
      await seed('guest');
      await seed('mine', owner: alice.id);
      await pump(tester, account: alice);
      expect(find.text('mine'), findsOneWidget);
      expect(find.text('guest'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.text(SettingsScreen.signOut));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('mine'), findsNothing);
      expect(find.text('guest'), findsOneWidget);
      expect(find.text(HomeScreen.deviceOnlyNotice), findsOneWidget);
    });
  });
}
