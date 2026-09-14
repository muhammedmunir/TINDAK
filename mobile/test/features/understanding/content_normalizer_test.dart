import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// PD-032, docs/20_TEST_PLAN.md section 1.1.
///
/// Every invisible character is built from its code point rather than written
/// literally, so this file cannot itself be disguised by the characters it
/// tests.
void main() {
  const normalizer = ContentNormalizer();
  String normalize(String s) => normalizer.normalize(s).text;
  String cp(int codePoint) => String.fromCharCode(codePoint);

  group('removes every format character', () {
    final formatCharacters = <String, int>{
      'soft hyphen': 0x00AD,
      'zero-width space': 0x200B,
      'zero-width non-joiner': 0x200C,
      'zero-width joiner': 0x200D,
      'left-to-right mark': 0x200E,
      'right-to-left mark': 0x200F,
      'left-to-right embedding': 0x202A,
      'right-to-left embedding': 0x202B,
      'pop directional formatting': 0x202C,
      'left-to-right override': 0x202D,
      'right-to-left override': 0x202E,
      'word joiner': 0x2060,
      'invisible times': 0x2062,
      'left-to-right isolate': 0x2066,
      'right-to-left isolate': 0x2067,
      'first strong isolate': 0x2068,
      'pop directional isolate': 0x2069,
      'byte-order mark': 0xFEFF,
    };

    formatCharacters.forEach((name, codePoint) {
      test(name, () {
        expect(normalize('ab${cp(codePoint)}cd'), 'abcd');
      });
    });
  });

  group('separators', () {
    test('a non-breaking space becomes a space', () {
      expect(normalize('012${cp(0x00A0)}3456789'), '012 3456789');
    });

    test('a narrow no-break space becomes a space', () {
      expect(normalize('a${cp(0x202F)}b'), 'a b');
    });

    test('line and paragraph separators become newlines', () {
      expect(normalize('a${cp(0x2028)}b${cp(0x2029)}c'), 'a\nb\nc');
    });

    test('ordinary newlines and tabs are kept', () {
      expect(normalize('a\nb\tc'), 'a\nb\tc');
    });
  });

  group('changes nothing it does not need to', () {
    test('clean text is unchanged byte for byte', () {
      const text = 'Bayar bil TNB RM183.50 sebelum 25 September\n'
          'https://Example.com/Path 012-345 6789';

      expect(normalize(text), text);
    });

    test('does not lowercase — URL paths are case-sensitive', () {
      expect(normalize('HTTPS://A.COM/Path'), 'HTTPS://A.COM/Path');
    });

    test('does not trim or collapse whitespace', () {
      expect(normalize('  a   b  '), '  a   b  ');
    });

    test('keeps emoji and mixed scripts readable', () {
      const text = 'Bayar RM1,500 你好 مرحبا 🇲🇾💰';

      expect(normalize(text), text);
    });
  });

  test('containsFormatCharacter agrees with normalize', () {
    final dirty = 'x${cp(0x202E)}y';

    expect(ContentNormalizer.containsFormatCharacter(dirty), isTrue);
    expect(
      ContentNormalizer.containsFormatCharacter(normalize(dirty)),
      isFalse,
    );
  });
}
