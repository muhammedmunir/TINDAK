import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/intake/incoming_text.dart';

void main() {
  group('IncomingText.fromSharePayload', () {
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
      final incoming = IncomingText.fromSharePayload(payload());

      expect(incoming, isNotNull);
      expect(incoming!.sequence, 1);
      expect(incoming.text, 'Bayar bil TNB');
      expect(incoming.source, IntakeSource.share);
      expect(incoming.sourceApp, 'com.whatsapp');
      expect(incoming.receivedAt.millisecondsSinceEpoch, 1757500000000);
      expect(incoming.characterCount, 13);
    });

    test('keeps the text byte for byte', () {
      // Intake receives and displays. It must not trim, normalise or
      // reinterpret; normalization is M3's job and happens later.
      const raw = '  Bayar   bil\n\tTNB RM183.50  ';

      expect(IncomingText.fromSharePayload(payload(text: raw))!.text, raw);
    });

    group('rejects malformed input safely', () {
      test('null payload', () {
        expect(IncomingText.fromSharePayload(null), isNull);
      });

      test('not a map', () {
        expect(IncomingText.fromSharePayload('hello'), isNull);
        expect(IncomingText.fromSharePayload(42), isNull);
        expect(IncomingText.fromSharePayload(<String>['a']), isNull);
      });

      test('empty map', () {
        expect(IncomingText.fromSharePayload(<Object?, Object?>{}), isNull);
      });

      test('missing text', () {
        expect(IncomingText.fromSharePayload(payload(text: null)), isNull);
      });

      test('empty text', () {
        expect(IncomingText.fromSharePayload(payload(text: '')), isNull);
      });

      test('whitespace-only text', () {
        // A share of nothing but spaces must not produce a result screen.
        expect(IncomingText.fromSharePayload(payload(text: '   \n\t ')), isNull);
      });

      test('text of the wrong type', () {
        expect(IncomingText.fromSharePayload(payload(text: 123)), isNull);
        expect(
          IncomingText.fromSharePayload(payload(text: <String>['a'])),
          isNull,
        );
      });

      test('missing or wrongly typed sequence', () {
        expect(IncomingText.fromSharePayload(payload(sequence: null)), isNull);
        expect(IncomingText.fromSharePayload(payload(sequence: 'one')), isNull);
        expect(IncomingText.fromSharePayload(payload(sequence: 1.5)), isNull);
      });
    });

    group('tolerates optional fields', () {
      test('missing receivedAt falls back to epoch', () {
        final incoming = IncomingText.fromSharePayload(
          payload(receivedAt: null),
        );

        expect(incoming!.receivedAt.millisecondsSinceEpoch, 0);
      });

      test('wrongly typed receivedAt falls back to epoch', () {
        final incoming = IncomingText.fromSharePayload(
          payload(receivedAt: 'yesterday'),
        );

        expect(incoming!.receivedAt.millisecondsSinceEpoch, 0);
      });

      test('missing, empty or wrongly typed sourceApp becomes null', () {
        expect(
          IncomingText.fromSharePayload(payload(sourceApp: null))!.sourceApp,
          isNull,
        );
        expect(
          IncomingText.fromSharePayload(payload(sourceApp: ''))!.sourceApp,
          isNull,
        );
        expect(
          IncomingText.fromSharePayload(payload(sourceApp: 7))!.sourceApp,
          isNull,
        );
      });
    });

    group('accepts content that must not be interpreted', () {
      // Text is untrusted whichever path it came by. TINDAK stores and renders
      // it as plain characters; nothing here may be executed, parsed or
      // stripped at intake.
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
        'ansi and control characters': 'x$nul$soh$esc[31m',
        'right-to-left override': '${rtlOverride}gnirts desrever',
        'ussd sequence': '*21*0123456789#',
      };

      hostile.forEach((label, text) {
        test('keeps $label verbatim from a share', () {
          expect(IncomingText.fromSharePayload(payload(text: text))!.text, text);
        });

        test('keeps $label verbatim from a paste', () {
          final pasted = IncomingText.pasted(
            text,
            at: DateTime.fromMillisecondsSinceEpoch(0),
          );

          expect(pasted.text, text);
        });
      });
    });

    test('handles a very large payload', () {
      final huge = 'a' * 500000;

      expect(
        IncomingText.fromSharePayload(payload(text: huge))!.characterCount,
        500000,
      );
    });

    test('handles unicode, emoji and mixed scripts', () {
      const text = 'Bayar RM1,500 sebelum 25 Ogos 你好 مرحبا 🇲🇾💰';

      expect(IncomingText.fromSharePayload(payload(text: text))!.text, text);
    });
  });

  group('IncomingText.pasted', () {
    test('carries the paste source and no sequence', () {
      final at = DateTime(2026, 9, 11, 8, 30);
      final pasted = IncomingText.pasted('Bayar bil TNB', at: at);

      expect(pasted.source, IntakeSource.paste);
      expect(pasted.text, 'Bayar bil TNB');
      expect(pasted.receivedAt, at);
      expect(pasted.sequence, 0);
      expect(pasted.sourceApp, isNull);
    });
  });

  group('IncomingText', () {
    test('toString omits the text, whichever path it came by', () {
      // docs/12_SECURITY.md section 11: neither a shared message nor a
      // clipboard's contents may reach a log, including through a stray
      // toString.
      final shared = IncomingText.fromSharePayload(<Object?, Object?>{
        'sequence': 3,
        'text': 'private bill 0123456789',
        'receivedAt': 0,
      })!;
      final pasted = IncomingText.pasted(
        'private bill 0123456789',
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );

      for (final incoming in <IncomingText>[shared, pasted]) {
        expect(incoming.toString(), isNot(contains('private')));
        expect(incoming.toString(), isNot(contains('0123456789')));
      }
      expect(shared.toString(), contains('share'));
      expect(pasted.toString(), contains('paste'));
    });

    test('equality covers source as well as content', () {
      final at = DateTime.fromMillisecondsSinceEpoch(0);
      final pastedA = IncomingText.pasted('x', at: at);
      final pastedB = IncomingText.pasted('x', at: at);
      final shared = IncomingText(
        text: 'x',
        source: IntakeSource.share,
        receivedAt: at,
      );

      expect(pastedA, pastedB);
      expect(pastedA.hashCode, pastedB.hashCode);
      expect(pastedA, isNot(shared));
    });
  });
}
