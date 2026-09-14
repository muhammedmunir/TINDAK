import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Everything TINDAK understood from one piece of text.
///
/// A list, never a single entity. `Bayar bil TNB RM183.50 sebelum 25 September`
/// is money and a date, not money or a date (PD-002).
final class UnderstandingResult {
  UnderstandingResult({
    required this.content,
    required List<DetectedEntity> entities,
    this.wasTruncated = false,
  }) : entities = List<DetectedEntity>.unmodifiable(entities);

  final NormalizedContent content;

  /// Every meaningful entity, ordered by position in the text.
  final List<DetectedEntity> entities;

  /// True when the input exceeded the understanding cap and only its start was
  /// analysed (PD-028).
  final bool wasTruncated;

  bool get isEmpty => entities.isEmpty;

  /// The entity a screen should emphasise, if any.
  ///
  /// Ranking only. It exists to decide which action is most prominent and never
  /// hides or discards the others (PD-002).
  ///
  /// Highest confidence wins; ties go to the type with the lower priority
  /// number, then to whichever appears first.
  DetectedEntity? get primary {
    if (entities.isEmpty) return null;
    return entities.reduce((best, next) {
      if (next.confidence != best.confidence) {
        return next.confidence > best.confidence ? next : best;
      }
      if (next.type.priority != best.type.priority) {
        return next.type.priority < best.type.priority ? next : best;
      }
      return next.start < best.start ? next : best;
    });
  }

  @override
  String toString() =>
      'UnderstandingResult(entities: ${entities.length}, '
      'truncated: $wasTruncated)';
}
