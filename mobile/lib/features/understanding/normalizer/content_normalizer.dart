import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Prepares text for detectors.
///
/// Runs once, before any detector, so no detector can be written that skips it
/// (PD-032, docs/20_TEST_PLAN.md section 1.1).
///
/// What it does, and deliberately no more:
///
/// 1. **Removes every Unicode format character (category Cf).** Zero-width
///    spaces and joiners, soft hyphens, the byte-order mark, and the
///    bidirectional embeddings, overrides and isolates. They are invisible on
///    screen but present in the value a detector would act on — a number that
///    reads `012-3456789` and dials something else is a scam mechanism, and it
///    is the exact scam TINDAK claims to protect against.
///
/// 2. **Maps Unicode space separators (Zs) to an ordinary space**, and line and
///    paragraph separators to a newline. A non-breaking space inside
///    `012 345 6789` must still read as a separator.
///
/// It does **not** lowercase (URL paths are case-sensitive), does not trim, and
/// does not collapse whitespace. Detectors handle their own separators, and
/// every change made here is a change a user did not see.
final class ContentNormalizer {
  const ContentNormalizer();

  static final RegExp _format = RegExp(r'\p{Cf}', unicode: true);
  static final RegExp _spaceSeparator = RegExp(r'\p{Zs}', unicode: true);
  static final RegExp _lineSeparator = RegExp(r'[\p{Zl}\p{Zp}]', unicode: true);

  NormalizedContent normalize(String input) {
    final withoutFormat = input.replaceAll(_format, '');
    final spaces = withoutFormat.replaceAll(_spaceSeparator, ' ');
    final lines = spaces.replaceAll(_lineSeparator, '\n');
    return NormalizedContent(lines);
  }

  /// True when [value] contains a character [normalize] would remove.
  ///
  /// Used by the engine's invariant check and by tests: no detected entity may
  /// ever carry one.
  static bool containsFormatCharacter(String value) => _format.hasMatch(value);
}
