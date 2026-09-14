import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/actions/resolver/action_uri_builder.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// An entity built by hand, deliberately bypassing the detectors.
///
/// The builder must not trust upstream. These tests hand it values no detector
/// should ever produce and require it to refuse them.
DetectedEntity entity(EntityType type, String normalized) => DetectedEntity(
  type: type,
  rawValue: normalized,
  normalizedValue: normalized,
  confidence: 0.95,
  start: 0,
  end: 1,
);

ActionDescriptor action(ActionKind kind, EntityType type, String normalized) =>
    ActionDescriptor(kind: kind, entity: entity(type, normalized));

void main() {
  const builder = ActionUriBuilder();
  String cp(int codePoint) => String.fromCharCode(codePoint);

  group('Call — docs/20_TEST_PLAN.md section 7.1', () {
    test('Malaysian mobile', () {
      final uri = builder.build(
        action(ActionKind.call, EntityType.phone, '+60123456789'),
      );

      expect(uri.toString(), 'tel:+60123456789');
    });

    test('eleven-digit mobile', () {
      expect(
        builder
            .build(action(ActionKind.call, EntityType.phone, '+601112345678'))
            .toString(),
        'tel:+601112345678',
      );
    });

    test('Klang Valley landline', () {
      expect(
        builder
            .build(action(ActionKind.call, EntityType.phone, '+60312345678'))
            .toString(),
        'tel:+60312345678',
      );
    });

    test('peninsular and Borneo landlines', () {
      for (final number in <String>['+6041234567', '+6082123456']) {
        expect(
          builder
              .build(action(ActionKind.call, EntityType.phone, number))
              .toString(),
          'tel:$number',
        );
      }
    });

    test('uses the value from detection, end to end', () {
      final detected = const UnderstandingEngine()
          .understand('Hubungi 012-345 6789')
          .entities
          .single;

      expect(
        builder
            .build(ActionDescriptor(kind: ActionKind.call, entity: detected))
            .toString(),
        'tel:+60123456789',
      );
    });
  });

  group('Call refuses — REQUIRED safety tests (PD-029)', () {
    const refused = <String, String>{
      '*21*0123456789#': 'USSD call-forwarding shape',
      '*#06#': 'USSD IMEI query',
      '+60123#456789': 'hash inside a number',
      '+60123*456789': 'star inside a number',
      '+60123456789#': 'trailing hash',
      '0123456789': 'not E.164 — raw national form',
      '60123456789': 'no plus',
      '+6512345678': 'not a Malaysian number',
      '+600123456789': 'national prefix left in',
      '+60 12 345 6789': 'spaces',
      '+60-123456789': 'hyphen',
      '+6012345': 'too short',
      '+60123456789012': 'too long',
      '+60١٢٣٤٥٦٧٨٩': 'non-ASCII digits',
      'tel:+60123456789': 'already a URI',
      '': 'empty',
    };

    refused.forEach((value, why) {
      test('$value — $why', () {
        expect(
          builder.build(action(ActionKind.call, EntityType.phone, value)),
          isNull,
          reason: why,
        );
      });
    });

    test('a zero-width space inside a number', () {
      expect(
        builder.build(
          action(ActionKind.call, EntityType.phone, '+6012345${cp(0x200B)}6789'),
        ),
        isNull,
      );
    });

    test('a right-to-left override inside a number', () {
      expect(
        builder.build(
          action(ActionKind.call, EntityType.phone, '+60${cp(0x202E)}123456789'),
        ),
        isNull,
      );
    });

    test('Call on a URL entity', () {
      expect(
        builder.build(
          action(ActionKind.call, EntityType.url, 'https://example.com'),
        ),
        isNull,
      );
    });
  });

  group('WhatsApp', () {
    test('Malaysian mobile becomes a wa.me link with digits only', () {
      expect(
        builder
            .build(action(ActionKind.whatsapp, EntityType.phone, '+60123456789'))
            .toString(),
        'https://wa.me/60123456789',
      );
    });

    test('eleven-digit mobile', () {
      expect(
        builder
            .build(
              action(ActionKind.whatsapp, EntityType.phone, '+601112345678'),
            )
            .toString(),
        'https://wa.me/601112345678',
      );
    });

    test('carries no message text and no query', () {
      final uri = builder.build(
        action(ActionKind.whatsapp, EntityType.phone, '+60123456789'),
      )!;

      expect(uri.hasQuery, isFalse);
      expect(uri.hasFragment, isFalse);
    });

    test('refuses a landline', () {
      expect(
        builder.build(
          action(ActionKind.whatsapp, EntityType.phone, '+60312345678'),
        ),
        isNull,
      );
    });

    test('refuses USSD shapes', () {
      for (final value in <String>['*21*0123456789#', '+60123#456789']) {
        expect(
          builder.build(action(ActionKind.whatsapp, EntityType.phone, value)),
          isNull,
          reason: value,
        );
      }
    });

    test('refuses a URL entity', () {
      expect(
        builder.build(
          action(ActionKind.whatsapp, EntityType.url, 'https://wa.me/60123456789'),
        ),
        isNull,
      );
    });
  });

  group('Open', () {
    test('https', () {
      expect(
        builder
            .build(action(ActionKind.openUrl, EntityType.url, 'https://example.com/a'))
            .toString(),
        'https://example.com/a',
      );
    });

    test('http', () {
      expect(
        builder
            .build(action(ActionKind.openUrl, EntityType.url, 'http://example.com'))
            .toString(),
        'http://example.com',
      );
    });

    test('keeps path and query intact', () {
      const url = 'https://www.tnb.com.my/bayar?akaun=123&Ref=AbC';

      expect(
        builder.build(action(ActionKind.openUrl, EntityType.url, url)).toString(),
        url,
      );
    });
  });

  group('Open refuses — REQUIRED safety tests (docs/12_SECURITY.md section 7)',
      () {
    const refused = <String, String>{
      'javascript:alert(1)': 'javascript scheme',
      'JAVASCRIPT:alert(1)': 'javascript scheme, uppercase',
      'file:///data/data/my.tindak.app/databases': 'file scheme',
      'intent://scan/#Intent;scheme=zxing;end': 'intent scheme',
      'content://com.android.contacts/contacts': 'content scheme',
      'tel:+60123456789': 'tel scheme through the URL action',
      'sms:+60123456789': 'sms scheme',
      'market://details?id=x': 'market scheme',
      'data:text/html,<script>alert(1)</script>': 'data scheme',
      'ftp://example.com': 'ftp scheme',
      'whatsapp://send?phone=60123456789': 'custom app scheme',
      'https://': 'no host',
      'https://localhost': 'host without a dot',
      'https://.example.com': 'leading dot',
      'https://example..com': 'empty label',
      'example.com': 'no scheme',
      'https://example.com/a b': 'whitespace',
      '': 'empty',
    };

    refused.forEach((value, why) {
      test('$value — $why', () {
        expect(
          builder.build(action(ActionKind.openUrl, EntityType.url, value)),
          isNull,
          reason: why,
        );
      });
    });

    test('a zero-width space in the host', () {
      expect(
        builder.build(
          action(ActionKind.openUrl, EntityType.url, 'https://exam${cp(0x200B)}ple.com'),
        ),
        isNull,
      );
    });

    test('a newline smuggled into the value', () {
      expect(
        builder.build(
          action(ActionKind.openUrl, EntityType.url, 'https://example.com\njavascript:x'),
        ),
        isNull,
      );
    });

    test('Open on a phone entity', () {
      expect(
        builder.build(
          action(ActionKind.openUrl, EntityType.phone, '+60123456789'),
        ),
        isNull,
      );
    });
  });

  test('only ever uses the normalised value, never the raw span', () {
    // A hand-built entity whose raw text is hostile and whose normalised value
    // is clean. The URI must come from the normalised value.
    const hostile = DetectedEntity(
      type: EntityType.phone,
      rawValue: '*21*0123456789#',
      normalizedValue: '+60123456789',
      confidence: 0.95,
      start: 0,
      end: 15,
    );

    expect(
      builder
          .build(const ActionDescriptor(kind: ActionKind.call, entity: hostile))
          .toString(),
      'tel:+60123456789',
    );
  });
}
