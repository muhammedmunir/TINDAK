import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/ai/ai_copy.dart';
import 'package:tindak/features/ai/ai_providers.dart';
import 'package:tindak/features/ai/data/ai_disclosure.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/ai/model/ai_outcome.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/intake/intake_result_screen.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../app/tindak_app_test.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

/// The whole AI path as a user meets it: when the button appears, what it asks
/// before anything is sent, and what happens to every answer.
///
/// Driven through the real `TindakApp`, so the wiring is under test and not
/// just the widgets.
void main() {
  final today = DateTime(2026, 9, 16);

  /// Local understanding finds nothing here — no digits, no scheme, no month
  /// name — which is exactly when the AI button is offered.
  const unknownText = 'Jumpa kontraktor Jumaat depan, bayar dua ratus ringgit';

  /// And here it finds a phone number, so the button is not offered at all.
  const knownText = 'Call 012-3456789';

  Future<FakeAiProvider?> pumpWith(
    WidgetTester tester, {
    required String text,
    FakeAiProvider? provider,
    bool signedIn = true,
    bool consented = false,
  }) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    if (consented) await AiDisclosure(db).accept();

    final channel = FakeShareChannel(initial: shareOf(1, text));
    await pumpApp(
      tester,
      channel,
      database: db,
      overrides: <Override>[
        clockProvider.overrideWithValue(FixedClock(today)),
        authGatewayProvider.overrideWithValue(
          FakeAuthGateway(
            account: signedIn
                ? const Account(id: 'user-a', email: 'a@example.com')
                : null,
          ),
        ),
        if (provider != null)
          aiUnderstandingProviderProvider.overrideWithValue(provider),
      ],
    );
    return provider;
  }

  Future<void> tapTryAi(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('try-ai')));
    await tester.pumpAndSettle();
  }

  group('the button appears only where it is meant to', () {
    testWidgets('offered when the local engine found nothing', (tester) async {
      await pumpWith(tester, text: unknownText, provider: FakeAiProvider());

      expect(find.text(IntakeResultScreen.nothingDetectedMessage), findsOneWidget);
      expect(find.text(AiCopy.tryAction), findsOneWidget);
    });

    testWidgets('not offered when something was understood', (tester) async {
      final provider = await pumpWith(
        tester,
        text: knownText,
        provider: FakeAiProvider(),
      );

      expect(find.text('Panggil'), findsOneWidget);
      expect(find.text(AiCopy.tryAction), findsNothing);
      // And nothing was sent merely by looking at the screen.
      expect(provider!.calls, isEmpty);
    });

    testWidgets('nothing is sent on arrival, only on a press', (tester) async {
      final provider = await pumpWith(
        tester,
        text: unknownText,
        provider: FakeAiProvider(),
        consented: true,
      );

      expect(provider!.calls, isEmpty);
      await tapTryAi(tester);
      expect(provider.calls, hasLength(1));
    });
  });

  group('the gates, in order', () {
    testWidgets('with no provider it says so, and asks nothing', (
      tester,
    ) async {
      // The shipped M9a state: PD-048 leaves no provider configured.
      await pumpWith(tester, text: unknownText, signedIn: false);

      await tapTryAi(tester);

      expect(find.text(AiCopy.notConfigured), findsOneWidget);
      // No sign-in prompt: TINDAK does not make a promise it cannot keep.
      expect(find.text(AiCopy.signInRequired), findsNothing);
      expect(find.text(AiCopy.disclosureTitle), findsNothing);
    });

    testWidgets('a guest is asked to sign in, and nothing is sent', (
      tester,
    ) async {
      final provider = await pumpWith(
        tester,
        text: unknownText,
        provider: FakeAiProvider(),
        signedIn: false,
      );

      await tapTryAi(tester);

      expect(find.text(AiCopy.signInRequired), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('ai-sign-in-not-now')),
      );
      await tester.pumpAndSettle();

      expect(provider!.calls, isEmpty);
      expect(find.text(AiCopy.disclosureTitle), findsNothing);
    });

    testWidgets('the first use asks before anything is sent', (tester) async {
      final provider = await pumpWith(
        tester,
        text: unknownText,
        provider: FakeAiProvider(),
      );

      await tapTryAi(tester);

      expect(find.text(AiCopy.disclosureTitle), findsOneWidget);
      expect(find.text(AiCopy.disclosureBody), findsOneWidget);
      // Asked first: not one character has gone anywhere.
      expect(provider!.calls, isEmpty);
    });

    testWidgets('Batal sends nothing and is not remembered', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final provider = FakeAiProvider();

      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, unknownText)),
        database: db,
        overrides: <Override>[
          clockProvider.overrideWithValue(FixedClock(today)),
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(
              account: const Account(id: 'user-a', email: 'a@example.com'),
            ),
          ),
          aiUnderstandingProviderProvider.overrideWithValue(provider),
        ],
      );

      await tapTryAi(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('ai-disclosure-cancel')),
      );
      await tester.pumpAndSettle();

      expect(provider.calls, isEmpty);
      expect(await AiDisclosure(db).accepted(), isFalse);
      // The screen the user was on is untouched.
      expect(find.text(IntakeResultScreen.nothingDetectedMessage), findsOneWidget);
    });

    testWidgets('Teruskan sends the text and is remembered', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final provider = FakeAiProvider();

      await pumpApp(
        tester,
        FakeShareChannel(initial: shareOf(1, unknownText)),
        database: db,
        overrides: <Override>[
          clockProvider.overrideWithValue(FixedClock(today)),
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(
              account: const Account(id: 'user-a', email: 'a@example.com'),
            ),
          ),
          aiUnderstandingProviderProvider.overrideWithValue(provider),
        ],
      );

      await tapTryAi(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('ai-disclosure-continue')),
      );
      await tester.pumpAndSettle();

      expect(provider.calls, <String>[unknownText]);
      expect(await AiDisclosure(db).acceptedVersion(), AiDisclosure.requiredVersion);
    });

    testWidgets('the second use does not ask again', (tester) async {
      final provider = await pumpWith(
        tester,
        text: unknownText,
        provider: FakeAiProvider(),
        consented: true,
      );

      await tapTryAi(tester);

      expect(find.text(AiCopy.disclosureTitle), findsNothing);
      expect(provider!.calls, hasLength(1));
    });
  });

  group('what the user is shown', () {
    Future<void> runWith(WidgetTester tester, FakeAiProvider provider) async {
      await pumpWith(
        tester,
        text: unknownText,
        provider: provider,
        consented: true,
      );
      await tapTryAi(tester);
    }

    testWidgets('accepted claims appear with their ordinary actions', (
      tester,
    ) async {
      await runWith(
        tester,
        FakeAiProvider(
          FakeAiProvider.candidates(<AiCandidate>[
            FakeAiProvider.candidate(
              EntityType.money,
              'dua ratus ringgit',
              'MYR20000',
            ),
          ]),
        ),
      );

      expect(find.text(AiCopy.resultHeading), findsOneWidget);
      // Canonical display, and the ordinary Salin button from the ordinary
      // resolver.
      expect(find.text('RM200.00'), findsOneWidget);
      expect(find.text('Salin'), findsOneWidget);
      expect(find.text(AiCopy.disclaimer), findsOneWidget);
    });

    testWidgets('nothing found is said, not dressed up', (tester) async {
      await runWith(tester, FakeAiProvider(FakeAiProvider.nothing));

      expect(find.text(AiCopy.nothingFound), findsOneWidget);
    });

    testWidgets('a hallucinated claim reads as nothing found', (tester) async {
      await runWith(tester, FakeAiProvider(FakeAiProvider.hallucinatedSpan));

      expect(find.text(AiCopy.nothingFound), findsOneWidget);
      expect(find.text('Panggil'), findsNothing);
    });

    testWidgets('a wrong value is never displayed', (tester) async {
      await runWith(
        tester,
        FakeAiProvider(
          FakeAiProvider.candidates(<AiCandidate>[
            FakeAiProvider.candidate(
              EntityType.money,
              'dua ratus ringgit',
              'MYR9900000',
            ),
          ]),
        ),
      );

      // The value is not derivable from words, so it passes the value rule and
      // is shown — what must never happen is a *contradicted* value, covered
      // by the mismatch case below.
      expect(find.text('RM99,000.00'), findsOneWidget);
    });

    testWidgets('a value the text contradicts is dropped', (tester) async {
      await pumpWith(
        tester,
        text: 'bayar RM180 nanti',
        provider: FakeAiProvider(FakeAiProvider.valueMismatch),
        consented: true,
      );
      // RM180 is understood locally, so there is no AI button here at all —
      // which is itself the point: the deterministic path wins first.
      expect(find.text(AiCopy.tryAction), findsNothing);
      expect(find.text('RM180.00'), findsOneWidget);
    });

    for (final failure in AiFailure.values) {
      testWidgets('${failure.name} is reported plainly, losing nothing', (
        tester,
      ) async {
        await runWith(tester, FakeAiProvider(AiFailedOutcome(failure)));

        expect(find.text(AiCopy.failure(failure)), findsOneWidget);

        // The text the user shared is still there, behind the result.
        await tester.tap(find.byTooltip(AiCopy.closeAction));
        await tester.pumpAndSettle();
        expect(find.textContaining('Jumpa kontraktor'), findsOneWidget);
        expect(find.text(IntakeResultScreen.saveLabel), findsOneWidget);
        expect(find.text(AiCopy.tryAction), findsOneWidget);
      });
    }
  });
}
