import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/security/analyzer/url_safety_analyzer.dart';
import 'package:tindak/features/security/model/security_assessment.dart';

/// The local checks (M8a). Every heuristic is asserted in both directions: a
/// URL that must trigger it, and a near-miss that must not.
///
/// The rules under test are deterministic and offline. Nothing here can send a
/// URL anywhere, which is the point of doing this layer first.
void main() {
  const analyzer = UrlSafetyAnalyzer();

  SecurityAssessment check(String url, {String? raw}) =>
      analyzer.analyse(url, rawValue: raw);

  Set<SecurityFindingCode> codes(String url) =>
      check(url).findings.map((f) => f.code).toSet();

  group('clean links', () {
    const clean = <String>[
      'https://tnb.com.my',
      'https://www.maybank2u.com.my/login',
      'https://example.com:443/a/b?c=d',
      'https://sub.example.com.my/path',
      'https://example.com/%20spaced%2Fpath',
      'https://a.b.c.co.uk',
    ];

    for (final url in clean) {
      test('$url is LOW RISK with no findings', () {
        final result = check(url);

        expect(result.level, RiskLevel.low);
        expect(result.findings, isEmpty);
      });
    }

    test('HTTPS earns no positive claim — there is simply nothing to report',
        () {
      expect(check('https://tnb.com.my').findings, isEmpty);
    });
  });

  group('caution signals', () {
    test('plain http (C-5)', () {
      expect(codes('http://example.com'), <SecurityFindingCode>{
        SecurityFindingCode.notEncrypted,
      });
      expect(check('http://example.com').level, RiskLevel.caution);
      expect(codes('https://example.com'), isEmpty);
    });

    test('IP address host', () {
      expect(
        codes('https://192.168.1.10/login'),
        contains(SecurityFindingCode.ipAddressHost),
      );
      // A name that merely contains digits is not an address.
      expect(
        codes('https://192-168-1-10.example.com'),
        isNot(contains(SecurityFindingCode.ipAddressHost)),
      );
      expect(
        codes('https://999.999.999.999'),
        isNot(contains(SecurityFindingCode.ipAddressHost)),
      );
    });

    test('punycode host', () {
      expect(
        codes('https://xn--80ak6aa92e.com'),
        contains(SecurityFindingCode.punycodeHost),
      );
      expect(
        codes('https://example.com'),
        isNot(contains(SecurityFindingCode.punycodeHost)),
      );
    });

    test('unusual port', () {
      expect(
        codes('https://example.com:8443/x'),
        contains(SecurityFindingCode.unusualPort),
      );
      expect(
        codes('https://example.com:443/x'),
        isNot(contains(SecurityFindingCode.unusualPort)),
      );
      expect(
        codes('http://example.com:80/x'),
        isNot(contains(SecurityFindingCode.unusualPort)),
      );
    });

    test('deep subdomains, with a conservative threshold', () {
      expect(
        codes('https://a.b.c.d.e.example.com'),
        contains(SecurityFindingCode.deepSubdomains),
      );
      // Five labels is ordinary and must not be flagged.
      expect(
        codes('https://a.b.c.co.uk'),
        isNot(contains(SecurityFindingCode.deepSubdomains)),
      );
    });

    test('link shortener', () {
      expect(
        codes('https://bit.ly/3abcdef'),
        contains(SecurityFindingCode.urlShortener),
      );
      expect(
        codes('https://www.tinyurl.com/x'),
        contains(SecurityFindingCode.urlShortener),
      );
      expect(
        codes('https://bitly.example.com/x'),
        isNot(contains(SecurityFindingCode.urlShortener)),
      );
    });
  });

  group('suspicious signals', () {
    test('credentials before the host', () {
      // Reads as a bank, goes somewhere else entirely.
      final result = check('https://maybank2u.com.my@evil.example/login');

      expect(result.level, RiskLevel.suspicious);
      expect(
        result.findings.map((f) => f.code),
        contains(SecurityFindingCode.credentialsInUrl),
      );
      expect(
        codes('https://example.com/path@handle'),
        isNot(contains(SecurityFindingCode.credentialsInUrl)),
      );
    });

    test('an encoded character disguising the authority', () {
      expect(
        codes('https://maybank2u.com.my%40evil.example/login'),
        contains(SecurityFindingCode.encodedAuthorityCharacter),
      );
      // Percent-encoding in the path is ordinary and must not be flagged.
      expect(
        codes('https://example.com/search%40term'),
        isNot(contains(SecurityFindingCode.encodedAuthorityCharacter)),
      );
    });

    test('mixed scripts in one label', () {
      // Cyrillic "а" standing in for Latin "a".
      expect(
        codes('https://maybаnk.com'),
        contains(SecurityFindingCode.mixedScriptHost),
      );
      // A wholly non-Latin domain is normal, not a homograph.
      expect(
        codes('https://مثال.com'),
        isNot(contains(SecurityFindingCode.mixedScriptHost)),
      );
    });

    test('the shown link differing from the real one', () {
      expect(
        check(
          'https://evil.example',
          raw: 'https://tnb.com.my',
        ).findings.map((f) => f.code),
        contains(SecurityFindingCode.normalisationMismatch),
      );
      // www. becoming https:// is the detector's normal work, not a mismatch.
      expect(
        check('https://example.com', raw: 'example.com').findings,
        isEmpty,
      );
      expect(
        check('https://example.com', raw: 'https://example.com/').findings,
        isEmpty,
      );
    });

    test('an unparseable link is reported, never passed as clean', () {
      final result = check('https://');

      expect(result.level, RiskLevel.suspicious);
      expect(result.findings, isNotEmpty);
    });
  });

  group('combining signals — no scoring (C-2)', () {
    test('three cautions stay CAUTION', () {
      // http + unusual port + shortener.
      final result = check('http://bit.ly:8080/abc');

      expect(result.findings, hasLength(3));
      expect(
        result.findings.every((f) => f.severity == SecuritySeverity.caution),
        isTrue,
      );
      expect(result.level, RiskLevel.caution);
    });

    test('one suspicious signal outranks any number of cautions', () {
      final result = check('http://user:pw@1.2.3.4:8080/a.b.c.d.e');

      expect(result.level, RiskLevel.suspicious);
    });

    test('the level is the highest severity, never a sum', () {
      final one = check('https://xn--80ak6aa92e.com');
      final many = check('http://xn--80ak6aa92e.com:8081/x');

      expect(one.level, RiskLevel.caution);
      expect(many.level, RiskLevel.caution);
    });
  });

  group('HIGH RISK is unreachable on device', () {
    test('no local input produces high risk', () {
      const worst = <String>[
        'http://user:password@1.2.3.4:8080/a.b.c.d.e.f',
        'https://maybаnk.com%2F@evil.example:99',
        'https://',
        'http://bit.ly:8081/xn--80ak6aa92e',
      ];

      for (final url in worst) {
        expect(
          check(url).level,
          isNot(RiskLevel.high),
          reason: '$url must not reach HIGH RISK without a provider',
        );
      }
    });
  });

  group('determinism and privacy', () {
    test('the same link always gives the same answer', () {
      final a = check('http://bit.ly:8080/abc');
      final b = check('http://bit.ly:8080/abc');

      expect(a.level, b.level);
      expect(a.findings, b.findings);
    });

    test('an assessment prints no URL', () {
      final result = check('https://private-link.example/secret-token');

      expect(result.toString(), isNot(contains('private-link')));
      expect(result.toString(), isNot(contains('secret-token')));
    });

    test('the online layer starts unchecked and changes no level', () {
      final result = check('https://tnb.com.my');

      expect(result.onlineStatus, OnlineCheckStatus.notChecked);
      expect(result.level, RiskLevel.low);
    });
  });
}
