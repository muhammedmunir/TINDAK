import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Finds calendar dates.
///
/// Specification: docs/20_TEST_PLAN.md section 4.
///
/// Two shapes only: numeric `D/M/YYYY` (also `-` and `.`), and `D <month>`
/// with month names in Malay and English. Ambiguous numeric dates are
/// **DD/MM/YYYY** (PD-008), so `03/04/2026` is 3 April 2026 — no locale
/// guessing.
///
/// - **Two-digit years are rejected** (ADR-026). `25/08/26` yields nothing;
///   guessing the century would set a reminder to a year the user never wrote.
/// - **Impossible dates are rejected.** `31/02/2026` and `29/02/2025` are not
///   dates; `29/02/2028` is.
/// - **A missing year resolves to the next occurrence** (PD-025): this year if
///   the date is today or still ahead, otherwise next year.
///
/// The clock is injected, so tests pin "today" and behaviour never depends on
/// the month the suite happens to run in.
///
/// Relative expressions — `esok`, `minggu depan`, `Jumaat depan`, `malam ini`
/// — are deliberately **not** understood. The clock is here for no-year dates
/// and nothing else.
final class DateDetector implements EntityDetector {
  const DateDetector({this.clock = const SystemClock()});

  final Clock clock;

  @override
  EntityType get type => EntityType.date;

  /// `D/M/YYYY` with the same separator twice. The year must be four digits:
  /// the pattern simply cannot match a two-digit year, and the trailing guard
  /// stops a longer digit run from being read as one.
  ///
  /// The trailing guard also refuses a fourth part: `25/09/2026/01` is a
  /// reference or a range, not a date, and reading its first ten characters as
  /// one would be a guess.
  static final RegExp _numeric = RegExp(
    r'(?<![\d])(\d{1,2})([/.-])(\d{1,2})\2(\d{4})(?![\d])(?!\2\d)',
  );

  /// `D <month>` with an optional four-digit year. The month is matched as
  /// letters and looked up in a table, so an unknown word is simply not a date.
  static final RegExp _named = RegExp(
    r'(?<![\p{L}\d])(\d{1,2})\s+(\p{L}+)\.?(?:\s+(\d{4}))?(?![\d])',
    unicode: true,
  );

  /// How far ahead a no-year date may be pushed to find a real calendar day.
  /// Only `29 Februari` ever needs more than one step.
  static const int _maxYearsAhead = 8;

  @override
  List<DetectedEntity> detect(NormalizedContent content) {
    final text = content.text;
    final found = <DetectedEntity>[];
    final taken = <(int, int)>[];

    for (final match in _numeric.allMatches(text)) {
      final date = DateValue.build(
        int.parse(match.group(4)!),
        int.parse(match.group(3)!),
        int.parse(match.group(1)!),
      );
      if (date == null) continue;
      taken.add((match.start, match.end));
      found.add(_entity(text, match.start, match.end, date, inferred: false));
    }

    for (final match in _named.allMatches(text)) {
      final month = DateValue.monthsByName[match.group(2)!.toLowerCase()];
      if (month == null) continue;
      if (_overlapsAny(match.start, match.end, taken)) continue;

      final day = int.parse(match.group(1)!);
      final writtenYear = match.group(3);
      final date = writtenYear == null
          ? _nextOccurrence(month, day)
          : DateValue.build(int.parse(writtenYear), month, day);
      if (date == null) continue;

      found.add(
        _entity(
          text,
          match.start,
          match.end,
          date,
          inferred: writtenYear == null,
        ),
      );
    }

    return found;
  }

  /// PD-025. This year when the date is today or still ahead, otherwise next
  /// year. Today stays today — a date being reached right now is the current
  /// occurrence, not next year's.
  DateValue? _nextOccurrence(int month, int day) {
    final today = clock.today();
    for (var offset = 0; offset <= _maxYearsAhead; offset++) {
      final candidate = DateValue.build(today.year + offset, month, day);
      if (candidate == null) continue; // 29 February in a non-leap year.
      if (!candidate.isBefore(today)) return candidate;
    }
    return null;
  }

  DetectedEntity _entity(
    String text,
    int start,
    int end,
    DateValue date, {
    required bool inferred,
  }) => DetectedEntity(
    type: EntityType.date,
    rawValue: text.substring(start, end),
    normalizedValue: date.normalizedValue,
    // A year TINDAK worked out is worth less certainty than one the user
    // wrote, and the resolved date is always shown in full before it is used.
    confidence: inferred ? 0.85 : 0.95,
    start: start,
    end: end,
  );

  static bool _overlapsAny(int start, int end, List<(int, int)> spans) {
    for (final (s, e) in spans) {
      if (start < e && s < end) return true;
    }
    return false;
  }
}
