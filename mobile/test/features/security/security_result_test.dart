import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_resolver.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/security/security_providers.dart';
import 'package:tindak/features/security/security_result_screen.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

import '../../app/tindak_app_test.dart' show RecordingLauncher;
import '../../support/fake_cloud.dart';

/// The result screen and the check action (M8a): what a person sees, and that
/// opening still goes through the M4 path.
SecurityAssessment _withStatus(
  SecurityAssessment local,
  OnlineCheckStatus status,
) => SecurityAssessment(
  url: local.url,
  level: local.level,
  findings: local.findings,
  onlineStatus: status,
);

void main() {
  DetectedEntity urlEntity(String url) => DetectedEntity(
    type: EntityType.url,
    rawValue: url,
    normalizedValue: url,
    confidence: 0.99,
    start: 0,
    end: url.length,
  );

  Future<RecordingLauncher> pumpResult(
    WidgetTester tester,
    String url, {
    bool signedIn = true,
  }) async {
    final launcher = RecordingLauncher();
    final gateway = FakeAuthGateway(
      account: signedIn
          ? const Account(id: 'user-a', email: 'a@example.com')
          : null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          externalLauncherProvider.overrideWithValue(launcher),
          authGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final entity = urlEntity(url);
              final checker = ref.read(securityCheckerProvider);
              return SecurityResultScreen(
                entity: entity,
                assessment: _withStatus(
                  checker.local(entity),
                  signedIn
                      ? OnlineCheckStatus.notChecked
                      : OnlineCheckStatus.signInRequired,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return launcher;
  }

  group('what the screen says', () {
    testWidgets('a clean link reads LOW RISK, with no claim of safety',
        (tester) async {
      await pumpResult(tester, 'https://tnb.com.my');

      expect(find.text(SecurityCopy.levelLabel(RiskLevel.low)), findsOneWidget);
      expect(find.text(SecurityCopy.noLocalFindings), findsOneWidget);
      expect(find.text(SecurityCopy.disclaimer), findsOneWidget);
      // Nothing anywhere tells the user the link is safe.
      expect(find.textContaining('selamat untuk dibuka'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('http reads CAUTION with its own reason', (tester) async {
      await pumpResult(tester, 'http://example.com');

      expect(
        find.text(SecurityCopy.levelLabel(RiskLevel.caution)),
        findsOneWidget,
      );
      expect(
        find.text(SecurityCopy.reason(SecurityFindingCode.notEncrypted)),
        findsOneWidget,
      );
    });

    testWidgets('a disguised link reads SUSPICIOUS and says why',
        (tester) async {
      await pumpResult(tester, 'https://maybank2u.com.my@evil.example/login');

      expect(
        find.text(SecurityCopy.levelLabel(RiskLevel.suspicious)),
        findsOneWidget,
      );
      expect(
        find.text(SecurityCopy.reason(SecurityFindingCode.credentialsInUrl)),
        findsOneWidget,
      );
    });

    testWidgets('every level shows the disclaimer', (tester) async {
      for (final url in <String>[
        'https://tnb.com.my',
        'http://example.com',
        'https://a@b.example',
      ]) {
        await pumpResult(tester, url);
        expect(find.text(SecurityCopy.disclaimer), findsOneWidget);
      }
    });

    testWidgets('no percentage or score is ever shown', (tester) async {
      await pumpResult(tester, 'http://bit.ly:8080/x');

      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('skor'), findsNothing);
      expect(find.textContaining('Risk '), findsNothing);
    });
  });

  group('online availability is stated, never scored (C-1)', () {
    testWidgets('a guest keeps the local level and is offered sign-in',
        (tester) async {
      await pumpResult(tester, 'https://tnb.com.my', signedIn: false);

      // Still LOW RISK: not signing in does not make a link riskier.
      expect(find.text(SecurityCopy.levelLabel(RiskLevel.low)), findsOneWidget);
      expect(
        find.text(SecurityCopy.onlineStatus(OnlineCheckStatus.signInRequired)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('security-sign-in')),
        findsOneWidget,
      );
    });

    testWidgets('a signed-in user is told the online half has not run yet',
        (tester) async {
      await pumpResult(tester, 'https://tnb.com.my');

      expect(
        find.text(SecurityCopy.onlineStatus(OnlineCheckStatus.notChecked)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('security-sign-in')),
        findsNothing,
      );
    });
  });

  group('opening', () {
    testWidgets('a low-risk link opens straight through the M4 path',
        (tester) async {
      final launcher = await pumpResult(tester, 'https://tnb.com.my');

      await tester.tap(find.byKey(const ValueKey<String>('security-open')));
      await tester.pumpAndSettle();

      expect(launcher.launched, <String>['https://tnb.com.my']);
    });

    testWidgets('a suspicious link asks first, and Batal opens nothing',
        (tester) async {
      final launcher = await pumpResult(
        tester,
        'https://maybank2u.com.my@evil.example/login',
      );

      await tester.tap(find.byKey(const ValueKey<String>('security-open')));
      await tester.pumpAndSettle();
      expect(find.text(SecurityCopy.riskyOpenQuestion), findsOneWidget);

      await tester.tap(find.text(SecurityCopy.cancelAction));
      await tester.pumpAndSettle();
      expect(launcher.launched, isEmpty);
    });

    testWidgets('confirming opens it — TINDAK informs, the user decides',
        (tester) async {
      final launcher = await pumpResult(
        tester,
        'https://maybank2u.com.my@evil.example/login',
      );

      await tester.tap(find.byKey(const ValueKey<String>('security-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('security-open-confirm')),
      );
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
    });

    testWidgets('a clean check is never permission to open what M4 refuses',
        (tester) async {
      // A scan cannot make this openable: the builder refuses the scheme.
      final entity = DetectedEntity(
        type: EntityType.url,
        rawValue: 'javascript:alert(1)',
        normalizedValue: 'javascript:alert(1)',
        confidence: 0.99,
        start: 0,
        end: 19,
      );
      final launcher = RecordingLauncher();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            externalLauncherProvider.overrideWithValue(launcher),
          ],
          child: MaterialApp(
            home: SecurityResultScreen(
              entity: entity,
              assessment: SecurityAssessment(
                url: entity.normalizedValue,
                level: RiskLevel.low,
                findings: const <SecurityFinding>[],
                onlineStatus: OnlineCheckStatus.notChecked,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('security-open')));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
    });
  });

  group('the action itself', () {
    test('a URL offers Buka and Semak Keselamatan, in that order', () {
      const resolver = ActionResolver();

      expect(
        resolver.resolve(urlEntity('https://example.com')).map((a) => a.kind),
        <ActionKind>[ActionKind.openUrl, ActionKind.securityCheck],
      );
    });

    test('a phone offers no security check', () {
      const resolver = ActionResolver();
      final phone = DetectedEntity(
        type: EntityType.phone,
        rawValue: '012-345 6789',
        normalizedValue: '+60123456789',
        confidence: 0.95,
        start: 0,
        end: 12,
      );

      expect(
        resolver.resolve(phone).map((a) => a.kind),
        isNot(contains(ActionKind.securityCheck)),
      );
    });
  });
}
