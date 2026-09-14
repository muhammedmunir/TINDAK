import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// Builds the one URI an action may launch, or refuses.
///
/// This is the last line between text that arrived from another app and an
/// Android intent. It trusts nothing upstream: a detector bug, a future
/// detector, or a hand-built entity must all fail closed here
/// (docs/12_SECURITY.md section 7, PD-029).
///
/// - Only the entity's **normalised** value is used. The raw span is never
///   read, and no URI is ever assembled from shared text.
/// - A phone must be exact Malaysian E.164: `+60`, then digits, nothing else.
///   `*`, `#`, spaces, letters and every USSD shape fail the pattern outright.
/// - WhatsApp additionally requires a mobile number.
/// - A link must be http or https with a real host. `javascript:`, `file:`,
///   `intent:`, `content:`, `tel:` and every other scheme are refused.
/// - An action must match its entity's type. Call on a URL is refused.
///
/// Pure Dart, so every refusal is a unit test.
final class ActionUriBuilder {
  const ActionUriBuilder();

  /// `+60` followed by a national number without its leading 0: 8 to 10
  /// digits, never starting with 0.
  static final RegExp _malaysianE164 = RegExp(r'^\+60[1-9]\d{7,9}$');

  /// A Malaysian mobile in E.164: `+601` then 8 or 9 digits.
  static final RegExp _malaysianMobileE164 = RegExp(r'^\+601\d{8,9}$');

  Uri? build(ActionDescriptor action) {
    final value = action.entity.normalizedValue;
    if (ContentNormalizer.containsFormatCharacter(value)) return null;
    if (_hasWhitespaceOrControl(value)) return null;

    return switch (action.kind) {
      ActionKind.call => _call(action, value),
      ActionKind.whatsapp => _whatsapp(action, value),
      ActionKind.openUrl => _openUrl(action, value),
    };
  }

  static Uri? _call(ActionDescriptor action, String value) {
    if (action.entity.type != EntityType.phone) return null;
    if (!_malaysianE164.hasMatch(value)) return null;
    return Uri(scheme: 'tel', path: value);
  }

  static Uri? _whatsapp(ActionDescriptor action, String value) {
    if (action.entity.type != EntityType.phone) return null;
    if (!_malaysianMobileE164.hasMatch(value)) return null;
    // wa.me takes the international number without its plus. Nothing but
    // those digits is interpolated — no message text, no query.
    return Uri.https('wa.me', '/${value.substring(1)}');
  }

  static Uri? _openUrl(ActionDescriptor action, String value) {
    if (action.entity.type != EntityType.url) return null;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    final host = uri.host;
    if (host.isEmpty || !host.contains('.')) return null;
    if (host.startsWith('.') || host.endsWith('.') || host.contains('..')) {
      return null;
    }
    return uri;
  }

  static bool _hasWhitespaceOrControl(String value) {
    for (final unit in value.codeUnits) {
      if (unit <= 0x20 || unit == 0x7F) return true;
    }
    return false;
  }
}
