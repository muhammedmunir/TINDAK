import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/normalized_content.dart';

/// Finds web links.
///
/// Specification: docs/20_TEST_PLAN.md section 5.
///
/// A link needs an explicit `http://`, `https://`, or a `www.` prefix, which is
/// normalised to `https://`.
///
/// **Bare domains are not detected** (PD-027). `Jumpa saya di kedai.my esok`
/// is a sentence, not a link, and Malay text is full of tokens that look like a
/// domain. A false action is worse than a conservative detector.
///
/// Only http and https are ever produced. `javascript:`, `intent:`, `file:` and
/// every other scheme are ignored here and refused again by the action
/// executor at M4 (docs/12_SECURITY.md section 7).
final class UrlDetector implements EntityDetector {
  const UrlDetector();

  @override
  EntityType get type => EntityType.url;

  static final RegExp _opening = RegExp(
    r'https?://|www\.',
    caseSensitive: false,
  );

  static final RegExp _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Characters that can never be part of a link in running text.
  static bool _terminates(int c) =>
      c <= 0x20 || // whitespace and control
      c == 0x22 || // "
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x60; // `

  /// Sentence punctuation commonly written straight after a link.
  static const String _trailingPunctuation = '.,;:!?\'"]}';

  static const double _schemeConfidence = 0.99;
  static const double _wwwConfidence = 0.90;

  @override
  List<DetectedEntity> detect(NormalizedContent content) {
    final text = content.text;
    final found = <DetectedEntity>[];
    var coveredUntil = 0;

    for (final match in _opening.allMatches(text)) {
      final start = match.start;
      if (start < coveredUntil) continue;

      final isWww = match.group(0)!.toLowerCase() == 'www.';
      if (start > 0) {
        final before = text[start - 1];
        if (_wordCharacter.hasMatch(before)) continue;
        // `https://www.` is one link, found by its scheme; `ali@www.` is not a
        // link at all.
        if (isWww && '.:/@-'.contains(before)) continue;
      }

      var end = start;
      while (end < text.length && !_terminates(text.codeUnitAt(end))) {
        end += 1;
      }
      end = _trimTrailing(text, start, end);

      final raw = text.substring(start, end);
      final uri = Uri.tryParse(isWww ? 'https://$raw' : raw);
      if (uri == null || !_isAcceptable(uri)) continue;

      found.add(
        DetectedEntity(
          type: EntityType.url,
          rawValue: raw,
          normalizedValue: _normalize(uri),
          confidence: isWww ? _wwwConfidence : _schemeConfidence,
          start: start,
          end: end,
        ),
      );
      coveredUntil = end;
    }
    return found;
  }

  /// Drops sentence punctuation from the end, keeping a closing parenthesis
  /// only when the link itself opened one.
  static int _trimTrailing(String text, int start, int end) {
    var e = end;
    while (e > start) {
      final last = text[e - 1];
      if (_trailingPunctuation.contains(last)) {
        e -= 1;
        continue;
      }
      if (last == ')') {
        final body = text.substring(start, e);
        final opens = '('.allMatches(body).length;
        final closes = ')'.allMatches(body).length;
        if (closes > opens) {
          e -= 1;
          continue;
        }
      }
      break;
    }
    return e;
  }

  static bool _isAcceptable(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;

    final host = uri.host;
    if (host.isEmpty || !host.contains('.')) return false;
    if (host.startsWith('.') || host.endsWith('.')) return false;
    if (host.contains('..')) return false;
    return true;
  }

  /// Lowercased scheme and host, path and query untouched — paths are
  /// case-sensitive, and `/A` and `/a` are different resources
  /// (docs/11_DATABASE.md section 4).
  static String _normalize(Uri uri) => uri
      .replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase())
      .toString();
}
