import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/money_value.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Finds Malaysian Ringgit amounts.
///
/// Specification: docs/20_TEST_PLAN.md section 3.
///
/// `RM` or `MYR` is the signal, and it is required. A bare `1,500` stays
/// undetected even in `Bayar 1,500 sebelum 25/09/2026` (PD approval A-5): every
/// message is full of ordinary numbers, and a wrong amount is worse than a
/// missed one.
///
/// Amounts are read into whole sen by string arithmetic, never through a
/// double (ADR-023). A malformed amount produces **nothing** rather than a
/// partial value: `RM1,2` and `RM12.345` are dropped whole, because a number
/// that is nearly right is the most dangerous kind.
final class MoneyDetector implements EntityDetector {
  const MoneyDetector();

  @override
  EntityType get type => EntityType.money;

  /// `RM`/`MYR`, optional single space, then either grouped thousands or plain
  /// digits, then at most two decimals.
  ///
  /// The guards matter as much as the pattern:
  /// - the marker may not be glued to a letter or digit, so `WARM25` and
  ///   `X RM25` behave correctly;
  /// - nothing may follow the amount that would have been part of it — a
  ///   further digit, a comma or a dot before a digit — which is what makes a
  ///   malformed amount fail entirely instead of matching a prefix.
  static final RegExp _amount = RegExp(
    r'(?<![\p{L}\d])(?:RM|MYR)[ ]?'
    r'(\d{1,3}(?:,\d{3})+|\d+)'
    r'(?:\.(\d{1,2}))?'
    r'(?![\d,]|\.\d)',
    caseSensitive: false,
    unicode: true,
  );

  @override
  List<DetectedEntity> detect(NormalizedContent content) {
    final found = <DetectedEntity>[];

    for (final match in _amount.allMatches(content.text)) {
      final whole = match.group(1)!;
      final fraction = match.group(2) ?? '';
      final money = MoneyValue.fromParts(whole, fraction);
      if (money == null) continue;

      found.add(
        DetectedEntity(
          type: EntityType.money,
          rawValue: content.text.substring(match.start, match.end),
          normalizedValue: money.normalizedValue,
          // The marker is explicit, so certainty is high either way; a written
          // decimal or thousands separator makes it higher still.
          confidence: (fraction.isNotEmpty || whole.contains(',')) ? 0.95 : 0.90,
          start: match.start,
          end: match.end,
        ),
      );
    }
    return found;
  }
}
