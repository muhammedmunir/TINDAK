/// A calendar date, with no time of day.
///
/// M6 understands dates only. A time is chosen by the user when a reminder is
/// created (PD-007), never defaulted silently, so nothing here invents one.
final class DateValue {
  const DateValue(this.year, this.month, this.day);

  /// Reads the canonical stored form, ISO-8601 `YYYY-MM-DD`
  /// (docs/11_DATABASE.md section 4). Returns null for anything else, and for
  /// a date that does not exist.
  static DateValue? parse(String normalizedValue) {
    final match = _iso.firstMatch(normalizedValue);
    if (match == null) return null;
    return build(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Builds a date only if the calendar really has it: `31/02/2026`,
  /// `31/04/2026` and `29/02/2025` return null, `29/02/2028` does not.
  static DateValue? build(int year, int month, int day) {
    if (year < 1000 || year > 9999) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final candidate = DateTime(year, month, day);
    // DateTime rolls an impossible day into the next month, so the parts are
    // compared back rather than trusted.
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return DateValue(year, month, day);
  }

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Month names as a person writes them, Malay first. Both languages map to
  /// the same month, so this is a table rather than a language detector — and
  /// it is why `Mac` (March) and `Mei` (May) can never be confused with `Mar`
  /// and `May` (docs/20_TEST_PLAN.md section 4).
  static const Map<String, int> monthsByName = <String, int>{
    'januari': 1, 'jan': 1, 'january': 1,
    'februari': 2, 'feb': 2, 'february': 2,
    'mac': 3, 'mar': 3, 'march': 3,
    'april': 4, 'apr': 4,
    'mei': 5, 'may': 5,
    'jun': 6, 'june': 6,
    'julai': 7, 'jul': 7, 'july': 7,
    'ogos': 8, 'ogo': 8, 'august': 8, 'aug': 8, 'ogs': 8,
    'september': 9, 'sep': 9, 'sept': 9,
    'oktober': 10, 'okt': 10, 'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'disember': 12, 'dis': 12, 'december': 12, 'dec': 12,
  };

  /// Malay month names for display (PD approval A-3).
  static const List<String> _malayMonths = <String>[
    'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
    'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember',
  ];

  final int year;
  final int month;
  final int day;

  /// What the cloud and search store: `2026-09-25`.
  String get normalizedValue =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// What a person sees: `25 September 2026`. Always the full resolved date,
  /// including a year TINDAK worked out, so an inference is visible before it
  /// can matter (PD-025).
  String get display => '$day ${_malayMonths[month - 1]} $year';

  /// Lowercased forms a person might type when searching: ISO, the numeric
  /// form, and the month-name form.
  String get searchValue {
    final numeric =
        '${day.toString().padLeft(2, '0')}/'
        '${month.toString().padLeft(2, '0')}/$year';
    return '$normalizedValue $numeric ${display.toLowerCase()}';
  }

  DateTime get asDateTime => DateTime(year, month, day);

  bool isBefore(DateTime other) => asDateTime.isBefore(other);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateValue &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'DateValue($normalizedValue)';
}
