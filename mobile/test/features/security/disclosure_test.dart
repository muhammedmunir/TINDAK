import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/security/data/online_check_disclosure.dart';
import 'package:tindak/features/security/data/reputation_provider.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/security/security_check_action.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/security/security_providers.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

/// The one-time disclosure (C-6): the user is asked **before** the first URL
/// ever leaves the device, and Batal means nothing is sent and nothing is
/// remembered.
void main() {
  late TindakDatabase db;
  late _FakeProvider provider;

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
    provider = _FakeProvider();
  });

  final entity = DetectedEntity(
    type: EntityType.url,
    rawValue: 'https://tnb.com.my',
    normalizedValue: 'https://tnb.com.my',
    confidence: 0.99,
    start: 0,
    end: 18,
  );

  Future<void> tapCheck(WidgetTester tester, {bool signedIn = true}) async {
    final gateway = FakeAuthGateway(
      account: signedIn
          ? const Account(id: 'user-a', email: 'a@example.com')
          : null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          authGatewayProvider.overrideWithValue(gateway),
          reputationProviderProvider.overrideWithValue(provider),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => runSecurityCheck(context, ref, entity),
                  child: const Text(SecurityCopy.checkAction),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(SecurityCopy.checkAction));
    await tester.pumpAndSettle();
  }

  testWidgets('the first check asks before sending anything', (tester) async {
    await tapCheck(tester);

    expect(find.text(SecurityCopy.disclosureTitle), findsOneWidget);
    expect(find.text(SecurityCopy.disclosureBody), findsOneWidget);
    // Asked first: not one byte has gone anywhere yet.
    expect(provider.calls, isEmpty);
  });

  testWidgets('Batal sends nothing and is not remembered', (tester) async {
    await tapCheck(tester);
    await tester.tap(find.byKey(const ValueKey<String>('disclosure-cancel')));
    await tester.pumpAndSettle();

    expect(provider.calls, isEmpty);
    expect(await OnlineCheckDisclosure(db).accepted(), isFalse);
    // The local result is still shown.
    expect(find.text(SecurityCopy.title), findsOneWidget);
    expect(find.text(SecurityCopy.levelLabel(RiskLevel.low)), findsOneWidget);
  });

  testWidgets('Teruskan sends the URL and is remembered', (tester) async {
    await tapCheck(tester);
    await tester.tap(find.byKey(const ValueKey<String>('disclosure-continue')));
    await tester.pumpAndSettle();

    expect(provider.calls, <String>['https://tnb.com.my']);
    expect(await OnlineCheckDisclosure(db).accepted(), isTrue);
  });

  testWidgets('the second check does not ask again', (tester) async {
    await OnlineCheckDisclosure(db).accept();

    await tapCheck(tester);

    expect(find.text(SecurityCopy.disclosureTitle), findsNothing);
    expect(provider.calls, hasLength(1));
  });

  testWidgets('a guest is never asked, and nothing is sent', (tester) async {
    await tapCheck(tester, signedIn: false);

    expect(find.text(SecurityCopy.disclosureTitle), findsNothing);
    expect(provider.calls, isEmpty);
    expect(
      find.text(SecurityCopy.onlineStatus(OnlineCheckStatus.signInRequired)),
      findsOneWidget,
    );
  });

  testWidgets('a quota rejection is said plainly, and the level is unchanged',
      (tester) async {
    await OnlineCheckDisclosure(db).accept();
    provider.result = const ReputationResult(ReputationOutcome.quotaReached);

    await tapCheck(tester);

    expect(
      find.text(SecurityCopy.onlineStatus(OnlineCheckStatus.quotaReached)),
      findsOneWidget,
    );
    expect(find.text(SecurityCopy.levelLabel(RiskLevel.low)), findsOneWidget);
  });

  testWidgets('a provider threat reads as RISIKO TINGGI with its reason',
      (tester) async {
    await OnlineCheckDisclosure(db).accept();
    provider.result = const ReputationResult(
      ReputationOutcome.threat,
      threatKind: ThreatKind.socialEngineering,
    );

    await tapCheck(tester);

    expect(find.text(SecurityCopy.levelLabel(RiskLevel.high)), findsOneWidget);
    expect(
      find.text(
        SecurityCopy.onlineReason(
          OnlineFindingCode.providerThreatSocialEngineering,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline keeps the local result and says so', (tester) async {
    await OnlineCheckDisclosure(db).accept();
    provider.result = const ReputationResult(ReputationOutcome.offline);

    await tapCheck(tester);

    expect(
      find.text(SecurityCopy.onlineStatus(OnlineCheckStatus.offline)),
      findsOneWidget,
    );
    expect(find.text(SecurityCopy.levelLabel(RiskLevel.low)), findsOneWidget);
  });
}

final class _FakeProvider implements ReputationProvider {
  ReputationResult result = const ReputationResult(
    ReputationOutcome.noKnownThreat,
  );
  final List<String> calls = <String>[];

  @override
  Future<ReputationResult> check(String url) async {
    calls.add(url);
    return result;
  }
}
