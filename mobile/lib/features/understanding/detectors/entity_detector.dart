import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Finds one kind of meaning in normalised text.
///
/// Each detector runs independently over the same content and returns zero or
/// more entities. Detectors never know about each other: overlap between them
/// is resolved once, in the engine. That is what lets a detector be added
/// without rewriting the others (master plan section 10).
///
/// A detector receives [NormalizedContent], never a raw string, so it cannot
/// see invisible or bidirectional characters (PD-032).
abstract interface class EntityDetector {
  EntityType get type;

  List<DetectedEntity> detect(NormalizedContent content);
}
