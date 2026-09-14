import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// Deterministic, local, non-AI search (PD-004).
///
/// A memory matches when the query appears in its original text, or in any of
/// its entities' search values. No embeddings, no ranking model, no inference —
/// the same query over the same data always returns the same rows.
///
/// Pure Dart so every rule is a unit test.
final class MemorySearch {
  const MemorySearch._();

  /// Longest query honoured. Anything longer is cut, not refused.
  static const int maxQueryLength = 200;

  /// Digits needed before a query is also matched as a number. Two digits
  /// would match almost every phone number saved.
  static const int minDigitsForNumberMatch = 3;

  /// What a person might type to find this entity, lowercased.
  ///
  /// A phone stored as `+60123456789` is findable as `0123456789` — how
  /// Malaysians write it — and as `60123456789`. Punctuation in the query is
  /// handled by [digitsOf], so `012-345 6789` finds it too.
  static String searchValueFor(DetectedEntity entity) {
    final normalized = entity.normalizedValue;
    return switch (entity.type) {
      EntityType.phone when normalized.startsWith('+60') =>
        '0${normalized.substring(3)} ${normalized.substring(1)}',
      _ => normalized.toLowerCase(),
    };
  }

  /// The query as it will be matched, or empty for "show everything".
  static String textOf(String query) {
    final trimmed = query.trim();
    return trimmed.length > maxQueryLength
        ? trimmed.substring(0, maxQueryLength)
        : trimmed;
  }

  /// Only the query's digits, when there are enough of them to mean a number.
  static String digitsOf(String query) {
    final digits = textOf(query).replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= minDigitsForNumberMatch ? digits : '';
  }

  /// Wraps [value] as a SQL `LIKE` pattern matching it anywhere, with `%`, `_`
  /// and the escape character itself escaped. Without this, searching for
  /// `100%` or `a_b` would match things the user did not type.
  static String containsPattern(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }
}
