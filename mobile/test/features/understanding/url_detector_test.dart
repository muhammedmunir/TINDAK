import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/understanding/detectors/url_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

List<DetectedEntity> detect(String text) =>
    const UrlDetector().detect(const ContentNormalizer().normalize(text));

/// docs/20_TEST_PLAN.md section 5.
void main() {
  group('must detect — section 5.1', () {
    const cases = <String, String>{
      'https://example.com': 'https://example.com',
      'http://example.com/a/b?c=d': 'http://example.com/a/b?c=d',
      'https://example.com.my': 'https://example.com.my',
      'www.example.com': 'https://www.example.com',
      'https://sub.example.com:8443/x': 'https://sub.example.com:8443/x',
    };

    cases.forEach((input, normalized) {
      test(input, () {
        final found = detect(input);

        expect(found, hasLength(1), reason: input);
        expect(found.single.type, EntityType.url);
        expect(found.single.normalizedValue, normalized);
        expect(found.single.rawValue, input);
      });
    });
  });

  group('must NOT detect — section 5.2', () {
    const cases = <String, String>{
      'example.com': 'bare domain (PD-027)',
      'Jumpa saya di kedai.my esok': 'bare domain inside a sentence',
      '25.09.2026': 'a date is not a host',
      'javascript:alert(1)': 'not an http(s) scheme',
      'ftp://example.com': 'not an http(s) scheme',
      'intent://scan/#Intent;scheme=zxing;end': 'not an http(s) scheme',
      'file:///data/data/my.tindak.app': 'not an http(s) scheme',
      'https://': 'no host',
      'http://localhost': 'host without a dot',
      'ali@www.example.com': 'an email-like token, not a link',
    };

    cases.forEach((input, why) {
      test('$input — $why', () {
        expect(detect(input), isEmpty, reason: why);
      });
    });
  });

  group('normalisation', () {
    test('lowercases scheme and host', () {
      expect(
        detect('HTTPS://EXAMPLE.COM').single.normalizedValue,
        'https://example.com',
      );
    });

    test('preserves path case', () {
      // Paths are case-sensitive: /A and /a are different resources.
      expect(
        detect('https://Example.com/Path/A').single.normalizedValue,
        'https://example.com/Path/A',
      );
    });

    test('www. becomes https', () {
      expect(
        detect('www.example.com/x').single.normalizedValue,
        'https://www.example.com/x',
      );
    });

    test('high confidence with a scheme, lower with www only', () {
      expect(detect('https://example.com').single.confidence, 0.99);
      expect(detect('www.example.com').single.confidence, 0.90);
    });
  });

  group('links in running text', () {
    test('drops sentence punctuation after a link', () {
      for (final end in <String>['.', ',', '!', '?', ';', ':']) {
        final found = detect('Lihat https://example.com$end');

        expect(found.single.rawValue, 'https://example.com', reason: end);
      }
    });

    test('drops a closing parenthesis the link did not open', () {
      expect(
        detect('(lihat https://example.com)').single.rawValue,
        'https://example.com',
      );
    });

    test('keeps a closing parenthesis the link did open', () {
      const link = 'https://en.wikipedia.org/wiki/Kuala_Lumpur_(city)';

      expect(detect('Baca $link').single.rawValue, link);
    });

    test('finds several links', () {
      final found = detect('https://a.com dan www.b.com.my');

      expect(found.map((e) => e.rawValue), <String>[
        'https://a.com',
        'www.b.com.my',
      ]);
    });

    test('https://www. is one link, not two', () {
      expect(detect('https://www.example.com'), hasLength(1));
    });

    test('stops at whitespace', () {
      expect(
        detect('https://example.com/a esok').single.rawValue,
        'https://example.com/a',
      );
    });

    test('offsets map back onto the normalised text', () {
      const text = 'Klik https://example.com/x sekarang';
      final found = detect(text).single;

      expect(text.substring(found.start, found.end), found.rawValue);
    });
  });
}
