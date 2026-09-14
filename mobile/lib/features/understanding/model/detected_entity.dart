import 'package:tindak/features/understanding/model/entity_type.dart';

/// One piece of meaning found in text.
final class DetectedEntity {
  const DetectedEntity({
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
    required this.confidence,
    required this.start,
    required this.end,
  }) : assert(confidence >= 0 && confidence <= 1),
       assert(start >= 0 && end > start);

  final EntityType type;

  /// The matched characters as they appear in the **normalised** text.
  ///
  /// Never the raw input. Invisible and bidirectional characters have already
  /// been removed, so what is displayed is what was detected (PD-032).
  final String rawValue;

  /// Canonical form: E.164 for a phone, lowercased scheme and host for a URL
  /// (docs/11_DATABASE.md section 4). This, not [rawValue], is what a later
  /// action is built from.
  final String normalizedValue;

  /// How sure the detector is, in `[0, 1]`.
  final double confidence;

  /// Character range `[start, end)` in the normalised text.
  final int start;
  final int end;

  int get length => end - start;

  /// True when this entity's span lies entirely within [other]'s and is not
  /// identical to it.
  bool isStrictlyInside(DetectedEntity other) =>
      start >= other.start &&
      end <= other.end &&
      (start != other.start || end != other.end);

  bool overlaps(DetectedEntity other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedEntity &&
          type == other.type &&
          rawValue == other.rawValue &&
          normalizedValue == other.normalizedValue &&
          confidence == other.confidence &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode =>
      Object.hash(type, rawValue, normalizedValue, confidence, start, end);

  /// Deliberately excludes the values. A detected phone number or URL is user
  /// content and must not reach a log (docs/12_SECURITY.md section 11).
  @override
  String toString() =>
      'DetectedEntity(${type.name}, confidence: $confidence, [$start, $end))';
}
