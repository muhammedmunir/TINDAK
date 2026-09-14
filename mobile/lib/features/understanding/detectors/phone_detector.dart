import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Finds Malaysian phone numbers.
///
/// Specification: docs/20_TEST_PLAN.md section 2.
///
/// | Class | Pattern | Digits |
/// |---|---|---|
/// | Mobile | `01[0-9]` + subscriber | 10, or 11 for `011` and `015` |
/// | Klang Valley landline | `03` + 8 | 10 |
/// | Other peninsular landline | `0[45679]` + 7 | 9 |
/// | Sabah / Sarawak landline | `08[2-9]` + 6–7 | 9–10 |
///
/// Short codes are out of scope (PD-009).
///
/// **A Malaysian IC number is never a phone candidate** (PD-029). It is twelve
/// digits, often hyphenated, and appears in exactly the messages people share.
/// Detecting one would put someone's identity number one tap from being
/// dialled.
final class PhoneDetector implements EntityDetector {
  const PhoneDetector();

  @override
  EntityType get type => EntityType.phone;

  /// Separators allowed between digit groups: space, hyphen, dot, parentheses.
  static bool _isSeparator(int c) =>
      c == 0x20 || c == 0x2D || c == 0x2E || c == 0x28 || c == 0x29;

  /// At most this many separator characters between two digit groups, so
  /// `(03) 1234` joins but `012   345` split across a long gap does not.
  static const int _maxSeparatorRun = 2;

  /// Longest digit string worth normalising: `0060` + an 11-digit mobile.
  static const int _maxDigits = 15;

  /// Most digit groups a single number is built from.
  static const int _maxGroupsPerNumber = 6;

  /// `YYMMDD-PB-####`, hyphenated, spaced or unseparated. Twelve digits that
  /// are not part of a longer digit run.
  static final RegExp _identityCard = RegExp(
    r'(?<!\d)\d{6}[- ]?\d{2}[- ]?\d{4}(?!\d)',
  );

  /// A currency marker immediately before a number means it is an amount.
  static final RegExp _currencyBefore = RegExp(
    r'(?:RM|MYR)\s?$',
    caseSensitive: false,
  );

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  @override
  List<DetectedEntity> detect(NormalizedContent content) {
    final text = content.text;
    final identityCards = [
      for (final m in _identityCard.allMatches(text)) (m.start, m.end),
    ];

    final found = <DetectedEntity>[];
    var index = 0;
    while (index < text.length) {
      final run = _readRun(text, index);
      if (run == null) {
        index += 1;
        continue;
      }
      found.addAll(_numbersIn(text, run, identityCards));
      index = run.end;
    }
    return found;
  }

  /// Reads a maximal run of digit groups joined by short separators, starting
  /// at [from]. Returns null when no run starts there.
  _Run? _readRun(String text, int from) {
    var pos = from;
    var hasPlus = false;

    final c = text.codeUnitAt(pos);
    if (c == 0x2B /* + */) {
      if (pos + 1 >= text.length || !_isDigit(text.codeUnitAt(pos + 1))) {
        return null;
      }
      hasPlus = true;
      pos += 1;
    } else if (c == 0x28 /* ( */) {
      if (pos + 1 >= text.length || !_isDigit(text.codeUnitAt(pos + 1))) {
        return null;
      }
      pos += 1;
    } else if (!_isDigit(c)) {
      return null;
    }

    final groups = <(int, int)>[];
    while (pos < text.length && _isDigit(text.codeUnitAt(pos))) {
      final groupStart = pos;
      while (pos < text.length && _isDigit(text.codeUnitAt(pos))) {
        pos += 1;
      }
      groups.add((groupStart, pos));

      // Look past a short separator run. Only consume it if a digit follows.
      var ahead = pos;
      var separators = 0;
      while (ahead < text.length &&
          separators < _maxSeparatorRun &&
          _isSeparator(text.codeUnitAt(ahead))) {
        ahead += 1;
        separators += 1;
      }
      if (separators > 0 &&
          ahead < text.length &&
          _isDigit(text.codeUnitAt(ahead))) {
        pos = ahead;
      } else {
        break;
      }
    }

    final end = groups.last.$2;
    return _Run(
      start: from,
      end: end,
      hasPlus: hasPlus,
      groups: groups,
      gluedBefore: from > 0 && _isLetterAt(text, from - 1),
      gluedAfter: end < text.length && _isLetterAt(text, end),
      afterCurrency: _currencyBefore.hasMatch(text.substring(0, from)),
    );
  }

  /// Extracts every valid, non-overlapping number from a run.
  ///
  /// A run can hold more than one number (`0123456789 0198765432`) or a number
  /// with neighbouring digits (`3.30 0123456789`), so windows of whole groups
  /// are tried left to right, taking the longest valid window at each point.
  /// Windows only ever split *between* groups, never inside one — which is why
  /// a long unseparated digit run can never yield a phone number.
  List<DetectedEntity> _numbersIn(
    String text,
    _Run run,
    List<(int, int)> identityCards,
  ) {
    final found = <DetectedEntity>[];
    final groups = run.groups;
    var first = 0;

    while (first < groups.length) {
      _Candidate? best;
      final lastAllowed = (first + _maxGroupsPerNumber - 1).clamp(
        0,
        groups.length - 1,
      );

      final digits = StringBuffer();
      for (var last = first; last <= lastAllowed; last++) {
        digits.write(text.substring(groups[last].$1, groups[last].$2));
        if (digits.length > _maxDigits) break;

        // A letter glued to either end, or a currency marker in front, means
        // this is a code, a reference or an amount — not a phone number.
        if (first == 0 && (run.gluedBefore || run.afterCurrency)) continue;
        if (last == groups.length - 1 && run.gluedAfter) continue;

        final start = first == 0 ? run.start : groups[first].$1;
        final end = groups[last].$2;
        if (_overlapsAny(start, end, identityCards)) continue;

        final withPlus = first == 0 && run.hasPlus;
        final national = _toNational(digits.toString(), withPlus: withPlus);
        if (national == null || !_isValidNational(national.number)) continue;

        best = _Candidate(
          start: start,
          end: end,
          lastGroup: last,
          national: national.number,
          confidence: _confidence(
            international: national.international,
            separated: last > first,
            bareCountryCode: national.bareCountryCode,
          ),
        );
      }

      if (best == null) {
        first += 1;
        continue;
      }

      found.add(
        DetectedEntity(
          type: EntityType.phone,
          rawValue: text.substring(best.start, best.end),
          normalizedValue: '+60${best.national.substring(1)}',
          confidence: best.confidence,
          start: best.start,
          end: best.end,
        ),
      );
      first = best.lastGroup + 1;
    }
    return found;
  }

  /// Converts dialled digits to a national number starting with `0`.
  static _National? _toNational(String digits, {required bool withPlus}) {
    if (withPlus) {
      if (!digits.startsWith('60')) return null;
      return _National('0${digits.substring(2)}', international: true);
    }
    if (digits.startsWith('0060')) {
      return _National('0${digits.substring(4)}', international: true);
    }
    if (digits.startsWith('0')) {
      return _National(digits);
    }
    if (digits.startsWith('60')) {
      // Malaysian numbers dialled locally always begin with 0, so a leading 60
      // can only be the country code — but without a + it is less certain.
      return _National('0${digits.substring(2)}', bareCountryCode: true);
    }
    return null;
  }

  static final RegExp _mobile = RegExp(r'^01\d+$');
  static final RegExp _klangValley = RegExp(r'^03\d{8}$');
  static final RegExp _peninsular = RegExp(r'^0[45679]\d{7}$');
  static final RegExp _borneo = RegExp(r'^08[2-9]\d{6,7}$');

  static bool _isValidNational(String n) {
    if (_mobile.hasMatch(n)) {
      final third = n[2];
      final required = (third == '1' || third == '5') ? 11 : 10;
      return n.length == required;
    }
    return _klangValley.hasMatch(n) ||
        _peninsular.hasMatch(n) ||
        _borneo.hasMatch(n);
  }

  /// docs/20_TEST_PLAN.md section 2.3.
  static double _confidence({
    required bool international,
    required bool separated,
    required bool bareCountryCode,
  }) {
    if (international || separated) return 0.95;
    if (bareCountryCode) return 0.60;
    return 0.80;
  }

  static bool _overlapsAny(int start, int end, List<(int, int)> spans) {
    for (final (s, e) in spans) {
      if (start < e && s < end) return true;
    }
    return false;
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static bool _isLetterAt(String text, int index) =>
      _letter.hasMatch(text[index]);
}

final class _Run {
  const _Run({
    required this.start,
    required this.end,
    required this.hasPlus,
    required this.groups,
    required this.gluedBefore,
    required this.gluedAfter,
    required this.afterCurrency,
  });

  final int start;
  final int end;
  final bool hasPlus;
  final List<(int, int)> groups;
  final bool gluedBefore;
  final bool gluedAfter;
  final bool afterCurrency;
}

final class _National {
  const _National(
    this.number, {
    this.international = false,
    this.bareCountryCode = false,
  });

  final String number;
  final bool international;
  final bool bareCountryCode;
}

final class _Candidate {
  const _Candidate({
    required this.start,
    required this.end,
    required this.lastGroup,
    required this.national,
    required this.confidence,
  });

  final int start;
  final int end;
  final int lastGroup;
  final String national;
  final double confidence;
}
