import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/share/shared_text.dart';

void main() {
  group('SharedText.tryFrom', () {
    Map<Object?, Object?> payload({
      Object? sequence = 1,
      Object? text = 'Bayar bil TNB',
      Object? receivedAt = 1757500000000,
      Object? sourceApp = 'com.whatsapp',
    }) => <Object?, Object?>{
      'sequence': sequence,
      'text': text,
      'receivedAt': receivedAt,
      'sourceApp': sourceApp,
    };

    test('reads a well-formed payload', () {
      final share = SharedText.tryFrom(payload());

      expect(share, isNotNull);
      expect(share!.sequence, 1);
      expect(share.text, 'Bayar bil TNB');
      expect(share.sourceApp, 'com.whatsapp');
      expect(share.receivedAt.millisecondsSinceEpoch, 1757500000000);
      expect(share.characterCount, 13);
    });

    test('keeps the text byte for byte', () {
      // M2 receives and displays. It must not trim, normalise or reinterpret.
      const raw = '  Bayar   bil\n\tTNB RM183.50  ';

      expect(SharedText.tryFrom(payload(text: raw))!.text, raw);
    });

    group('rejects malformed input safely', () {
      test('null payload', () => expect(SharedText.tryFrom(null), isNull));

      test('not a map', () {
        expect(SharedText.tryFrom('hello'), isNull);
        expect(SharedText.tryFrom(42), isNull);
        expect(SharedText.tryFrom(<String>['a']), isNull);
      });

      test('empty map', () {
        expect(SharedText.tryFrom(<Object?, Object?>{}), isNull);
      });

      test('missing text', () {
        expect(SharedText.tryFrom(payload(text: null)), isNull);
      });

      test('empty text', () {
        expect(SharedText.tryFrom(payload(text: '')), isNull);
      });

      test('text of the wrong type', () {
        expect(SharedText.tryFrom(payload(text: 123)), isNull);
        expect(SharedText.tryFrom(payload(text: <String>['a'])), isNull);
      });

      test('missing or wrongly typed sequence', () {
        expect(SharedText.tryFrom(payload(sequence: null)), isNull);
        expect(SharedText.tryFrom(payload(sequence: 'one')), isNull);
        expect(SharedText.tryFrom(payload(sequence: 1.5)), isNull);
      });
    });

    group('tolerates optional fields', () {
      test('missing receivedAt falls back to epoch', () {
        final share = SharedText.tryFrom(payload(receivedAt: null));

        expect(share, isNotNull);
        expect(share!.receivedAt.millisecondsSinceEpoch, 0);
      });

      test('wrongly typed receivedAt falls back to epoch', () {
        final share = SharedText.tryFrom(payload(receivedAt: 'yesterday'));

        expect(share!.receivedAt.millisecondsSinceEpoch, 0);
      });

      test('missing, empty or wrongly typed sourceApp becomes null', () {
        expect(SharedText.tryFrom(payload(sourceApp: null))!.sourceApp, isNull);
        expect(SharedText.tryFrom(payload(sourceApp: ''))!.sourceApp, isNull);
        expect(SharedText.tryFrom(payload(sourceApp: 7))!.sourceApp, isNull);
      });
    });

    group('accepts content that must not be interpreted', () {
      // Shared text is untrusted. TINDAK stores and renders it as plain
      // characters; nothing here may be executed, parsed or stripped.
      //
      // The control-character cases are built from code points rather than
      // written literally, so the source file itself stays readable and no
      // bidirectional override can disguise what this test contains.
      final nul = String.fromCharCode(0x00);
      final soh = String.fromCharCode(0x01);
      final esc = String.fromCharCode(0x1B);
      final rtlOverride = String.fromCharCode(0x202E);

      final hostile = <String, String>{
        'html script': '<script>alert(1)</script>',
        'html markup': '<b>bold</b> &amp; entities',
        'javascript scheme': 'javascript:alert(1)',
        'dart interpolation': r'${expression}',
        'path traversal': '../../etc/passwd',
        'sql injection': "'; DROP TABLE memories; --",
        'ansi and control characters': '$nul$soh$esc[31m',
        'right-to-left override': '${rtlOverride}gnirts desrever',
        'ussd sequence': '*21*0123456789#',
      };

      hostile.forEach((label, text) {
        test('keeps $label verbatim', () {
          expect(SharedText.tryFrom(payload(text: text))!.text, text);
        });
      });
    });

    test('handles a very large payload', () {
      final huge = 'a' * 500000;
      final share = SharedText.tryFrom(payload(text: huge));

      expect(share!.characterCount, 500000);
    });

    test('handles unicode, emoji and mixed scripts', () {
      const text = 'Bayar RM1,500 sebelum 25 Ogos 你好 مرحبا 🇲🇾💰';
      final share = SharedText.tryFrom(payload(text: text));

      expect(share!.text, text);
    });
  });

  group('SharedText', () {
    test('toString omits the shared text', () {
      // docs/12_SECURITY.md section 11: no user content in logs, including
      // through a stray toString.
      final share = SharedText.tryFrom(<Object?, Object?>{
        'sequence': 3,
        'text': 'private bill 0123456789',
        'receivedAt': 0,
      })!;

      expect(share.toString(), isNot(contains('private')));
      expect(share.toString(), isNot(contains('0123456789')));
      expect(share.toString(), contains('sequence: 3'));
    });

    test('equality covers every field', () {
      final a = SharedText.tryFrom(<Object?, Object?>{
        'sequence': 1,
        'text': 'x',
        'receivedAt': 0,
      })!;
      final b = SharedText.tryFrom(<Object?, Object?>{
        'sequence': 1,
        'text': 'x',
        'receivedAt': 0,
      })!;
      final c = SharedText.tryFrom(<Object?, Object?>{
        'sequence': 2,
        'text': 'x',
        'receivedAt': 0,
      })!;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
