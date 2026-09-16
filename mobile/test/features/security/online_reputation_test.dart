import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/security/analyzer/url_safety_analyzer.dart';
import 'package:tindak/features/security/data/reputation_provider.dart';
import 'package:tindak/features/security/model/security_assessment.dart';
import 'package:tindak/features/security/security_checker.dart';
import 'package:tindak/features/security/security_copy.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// The online half (M8b): when a URL may be sent at all, and how provider
/// evidence combines with what the device already found.
void main() {
  DetectedEntity urlEntity(String url) => DetectedEntity(
    type: EntityType.url,
    rawValue: url,
    normalizedValue: url,
    confidence: 0.99,
    start: 0,
    end: url.length,
  );

  const clean = 'https://tnb.com.my';
  const suspicious = 'https://maybank2u.com.my@evil.example/login';
  const cautionable = 'http://example.com';

  SecurityChecker checkerWith(
    _FakeProvider? provider, {
    bool signedIn = true,
    bool disclosureAccepted = true,
  }) => SecurityChecker(
    analyzer: const UrlSafetyAnalyzer(),
    isSignedIn: () => signedIn,
    hasAcceptedDisclosure: () async => disclosureAccepted,
    provider: provider,
  );

  group('nothing is sent unless every gate is open', () {
    test('a guest never reaches the provider', () async {
      final provider = _FakeProvider();
      final checker = checkerWith(provider, signedIn: false);

      final result = await checker.check(urlEntity(clean));

      expect(provider.calls, isEmpty);
      expect(result.onlineStatus, OnlineCheckStatus.signInRequired);
      // The local level is untouched by not being signed in (C-1).
      expect(result.level, RiskLevel.low);
    });

    test('without the disclosure, nothing is sent', () async {
      final provider = _FakeProvider();
      final checker = checkerWith(provider, disclosureAccepted: false);

      expect(
        await checker.onlineBlocker(),
        OnlineCheckStatus.disclosureRequired,
      );
      final result = await checker.check(urlEntity(clean));

      expect(provider.calls, isEmpty);
      expect(result.onlineStatus, OnlineCheckStatus.disclosureRequired);
    });

    test('a build with no provider sends nothing', () async {
      final checker = checkerWith(null);

      final result = await checker.check(urlEntity(clean));

      expect(result.onlineStatus, OnlineCheckStatus.notChecked);
    });

    test('with every gate open, exactly the chosen URL is sent — once',
        () async {
      final provider = _FakeProvider();
      final checker = checkerWith(provider);

      await checker.check(urlEntity(clean));

      expect(provider.calls, <String>[clean]);
    });

    test('the local half runs whatever the gates say', () async {
      final checker = checkerWith(null, signedIn: false);

      final result = await checker.check(urlEntity(cautionable));

      expect(result.level, RiskLevel.caution);
      expect(result.findings, isNotEmpty);
    });
  });

  group('combining provider evidence', () {
    test('a threat match reaches HIGH RISK', () async {
      final provider = _FakeProvider(
        const ReputationResult(
          ReputationOutcome.threat,
          threatKind: ThreatKind.socialEngineering,
        ),
      );

      final result = await checkerWith(provider).check(urlEntity(clean));

      expect(result.level, RiskLevel.high);
      expect(result.onlineStatus, OnlineCheckStatus.threatFound);
      expect(
        result.onlineFinding,
        OnlineFindingCode.providerThreatSocialEngineering,
      );
    });

    test('a threat with no category still reads as a threat', () async {
      final provider = _FakeProvider(
        const ReputationResult(ReputationOutcome.threat),
      );

      final result = await checkerWith(provider).check(urlEntity(clean));

      expect(result.level, RiskLevel.high);
      expect(result.onlineFinding, OnlineFindingCode.providerThreat);
    });

    test('a clean provider answer never erases local findings', () async {
      final provider = _FakeProvider(
        const ReputationResult(ReputationOutcome.noKnownThreat),
      );

      final result = await checkerWith(provider).check(urlEntity(suspicious));

      // Suspicious locally, no match online: still suspicious.
      expect(result.level, RiskLevel.suspicious);
      expect(result.onlineStatus, OnlineCheckStatus.clean);
      expect(result.findings, isNotEmpty);
    });

    test('a clean provider answer does not lower a caution', () async {
      final provider = _FakeProvider(
        const ReputationResult(ReputationOutcome.noKnownThreat),
      );

      final result = await checkerWith(provider).check(urlEntity(cautionable));

      expect(result.level, RiskLevel.caution);
    });
  });

  group('a check that could not run changes nothing (C-1)', () {
    for (final (outcome, status) in <(ReputationOutcome, OnlineCheckStatus)>[
      (ReputationOutcome.offline, OnlineCheckStatus.offline),
      (ReputationOutcome.unavailable, OnlineCheckStatus.unavailable),
      (ReputationOutcome.quotaReached, OnlineCheckStatus.quotaReached),
      (ReputationOutcome.notAuthenticated, OnlineCheckStatus.signInRequired),
    ]) {
      test('${outcome.name} leaves a clean link at LOW RISK', () async {
        final provider = _FakeProvider(ReputationResult(outcome));

        final result = await checkerWith(provider).check(urlEntity(clean));

        expect(result.level, RiskLevel.low);
        expect(result.onlineStatus, status);
      });

      test('${outcome.name} leaves a suspicious link where it was', () async {
        final provider = _FakeProvider(ReputationResult(outcome));

        final result = await checkerWith(
          provider,
        ).check(urlEntity(suspicious));

        expect(result.level, RiskLevel.suspicious);
      });
    }

    test('a failure never invents HIGH RISK', () async {
      for (final outcome in <ReputationOutcome>[
        ReputationOutcome.offline,
        ReputationOutcome.unavailable,
        ReputationOutcome.quotaReached,
        ReputationOutcome.notAuthenticated,
      ]) {
        final result = await checkerWith(
          _FakeProvider(ReputationResult(outcome)),
        ).check(urlEntity(clean));

        expect(result.level, isNot(RiskLevel.high));
      }
    });
  });

  group('an unconfigured provider is not a clean answer (PD-047)', () {
    // Web Risk is deferred, so `unavailable` is the state TINDAK actually
    // ships in. It must stay distinguishable from "checked, nothing found" in
    // the model *and* in the words the user reads.
    test('unavailable and clean are different states', () {
      expect(OnlineCheckStatus.unavailable, isNot(OnlineCheckStatus.clean));
      expect(
        SecurityCopy.onlineStatus(OnlineCheckStatus.unavailable),
        isNot(SecurityCopy.onlineStatus(OnlineCheckStatus.clean)),
      );
    });

    test('no unfinished check is worded as an absence of threats', () {
      // "Tiada ancaman diketahui ditemui" is a finding, and only the clean
      // status has earned it.
      for (final status in <OnlineCheckStatus>[
        OnlineCheckStatus.unavailable,
        OnlineCheckStatus.offline,
        OnlineCheckStatus.quotaReached,
        OnlineCheckStatus.notChecked,
        OnlineCheckStatus.disclosureRequired,
        OnlineCheckStatus.signInRequired,
      ]) {
        expect(
          SecurityCopy.onlineStatus(status),
          isNot(contains('Tiada ancaman')),
          reason: '${status.name} must not read as "nothing found"',
        );
      }
    });

    test('an unconfigured provider leaves every local level alone', () async {
      for (final url in <String>[clean, cautionable, suspicious]) {
        final local = const UrlSafetyAnalyzer().analyse(url);
        final combined = SecurityChecker.combine(
          local,
          const ReputationResult(ReputationOutcome.unavailable),
        );

        expect(combined.level, local.level);
        expect(combined.onlineStatus, OnlineCheckStatus.unavailable);
        expect(combined.onlineFinding, isNull);
      }
    });
  });

  group('privacy', () {
    test('only the URL is handed to the provider', () async {
      final provider = _FakeProvider();
      // The entity carries a raw span too; only the normalised URL is sent.
      final entity = DetectedEntity(
        type: EntityType.url,
        rawValue: 'www.tnb.com.my',
        normalizedValue: clean,
        confidence: 0.9,
        start: 12,
        end: 26,
      );

      await checkerWith(provider).check(entity);

      expect(provider.calls, <String>[clean]);
    });

    test('a result prints no URL', () async {
      final result = await checkerWith(
        _FakeProvider(const ReputationResult(ReputationOutcome.threat)),
      ).check(urlEntity('https://private.example/secret'));

      expect(result.toString(), isNot(contains('private')));
      expect(result.toString(), isNot(contains('secret')));
    });
  });
}

final class _FakeProvider implements ReputationProvider {
  _FakeProvider([
    this.result = const ReputationResult(ReputationOutcome.noKnownThreat),
  ]);

  final ReputationResult result;
  final List<String> calls = <String>[];

  @override
  Future<ReputationResult> check(String url) async {
    calls.add(url);
    return result;
  }
}
