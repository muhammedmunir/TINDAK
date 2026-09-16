/// A Malaysian Ringgit amount, held as whole sen.
///
/// Never a double. `RM183.50` as a binary double is not exactly 183.50, and
/// money that fails to compare equal to itself is a defect that surfaces months
/// later (ADR-023). Parsing and formatting are string arithmetic from end to
/// end, so no amount ever passes through a floating-point value.
final class MoneyValue {
  const MoneyValue(this.sen);

  /// Reads the canonical stored form, `MYR<sen>` (docs/11_DATABASE.md section
  /// 4). Returns null for anything else, so a value written by a future
  /// version cannot be displayed as the wrong amount.
  static MoneyValue? parse(String normalizedValue) {
    if (!normalizedValue.startsWith(currencyPrefix)) return null;
    final sen = int.tryParse(normalizedValue.substring(currencyPrefix.length));
    return (sen == null || sen < 0) ? null : MoneyValue(sen);
  }

  /// Builds an amount from the parts of a written number, without ever
  /// multiplying a decimal. [whole] may carry thousands separators; [fraction]
  /// is one or two digits, or empty.
  static MoneyValue? fromParts(String whole, String fraction) {
    final digits = whole.replaceAll(',', '');
    if (digits.isEmpty || digits.length > maxWholeDigits) return null;
    if (fraction.length > 2) return null;
    final ringgit = int.tryParse(digits);
    if (ringgit == null) return null;
    final sen = int.tryParse(fraction.padRight(2, '0').padLeft(2, '0'));
    if (sen == null) return null;
    return MoneyValue(ringgit * 100 + sen);
  }

  static const String currencyPrefix = 'MYR';

  /// Longest whole-ringgit part accepted. Far beyond any real amount in a
  /// shared message, and small enough that sen can never overflow.
  static const int maxWholeDigits = 15;

  /// The amount in whole sen. `RM183.50` is `18350`.
  final int sen;

  /// What the cloud and search store: `MYR18350`.
  String get normalizedValue => '$currencyPrefix$sen';

  /// What a person sees: always `RM`, always two decimals, thousands grouped —
  /// so `rm25`, `RM 25` and `RM25.00` all read as `RM25.00` (PD approval A-2).
  String get display {
    final ringgit = (sen ~/ 100).toString();
    final cents = (sen % 100).toString().padLeft(2, '0');
    final grouped = StringBuffer();
    for (var i = 0; i < ringgit.length; i++) {
      if (i > 0 && (ringgit.length - i) % 3 == 0) grouped.write(',');
      grouped.write(ringgit[i]);
    }
    return 'RM$grouped.$cents';
  }

  /// Lowercased forms a person might type when searching: the display form,
  /// the plain amount, and the sen. Matches the `search_value` contract in
  /// docs/11_DATABASE.md section 3.1.
  String get searchValue {
    final plain = display.substring(2).replaceAll(',', '');
    return '${display.toLowerCase()} $plain $sen';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MoneyValue && sen == other.sen;

  @override
  int get hashCode => sen.hashCode;

  /// Deliberately excludes the amount — it is user content
  /// (docs/12_SECURITY.md section 11).
  @override
  String toString() => 'MoneyValue(sen: ${sen.bitLength} bits)';
}
