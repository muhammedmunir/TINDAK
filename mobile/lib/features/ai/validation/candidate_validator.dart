import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/ai/model/ai_candidate.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/date_value.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/money_value.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// Why a candidate did not become an entity. Reason codes only — they are
/// counted in logs, and they never carry a value (brief §21).
enum CandidateRejection {
  /// The span is not in the user's text. The model made it up.
  spanNotFound,

  /// An invisible or bidirectional character in the span or the value
  /// (PD-032).
  formatCharacter,

  /// TINDAK could not work the value out from the span for itself, and this
  /// type requires that it can.
  notDerivable,

  /// TINDAK *did* work it out, and the model disagreed. The span was being
  /// used as cover for a different value.
  valueMismatch,

  /// The value fails TINDAK's own rule for this type.
  valueInvalid,

  /// A link with no scheme and no `www.` — PD-027 is not reopened through AI.
  bareDomain,

  /// A date so far from today that it is more likely a misreading than a plan.
  outOfWindow,

  /// The same value, at the same place, already accepted.
  duplicate,
}

sealed class CandidateVerdict {
  const CandidateVerdict();
}

final class CandidateAccepted extends CandidateVerdict {
  const CandidateAccepted(this.entity);
  final DetectedEntity entity;
}

final class CandidateRejected extends CandidateVerdict {
  const CandidateRejected(this.reason);
  final CandidateRejection reason;
}

/// Turns model claims into entities, or refuses to.
///
/// Pure Dart: no Flutter, no I/O, no network. The whole safety argument for M9
/// is decided in this file, which means the whole safety argument is a unit
/// test.
///
/// Three questions, in order, and all of them must pass:
///
/// 1. **Is this the user's own text?** The span must occur verbatim in the
///    normalised input. A value the message does not contain cannot become an
///    action, which is what makes prompt injection ineffective: text telling
///    the model to return `javascript:alert(1)` yields a span that is not
///    there, or a value TINDAK refuses anyway.
/// 2. **Does TINDAK agree?** Where TINDAK's own deterministic rules can read
///    the span, the model's value must be exactly what they produce. This is
///    the control that stops a real span being used as cover for a fabricated
///    value: span `RM180`, value `MYR80000` is rejected, not displayed.
/// 3. **Is the value one TINDAK can act on?** The same per-type rules the
///    local engine and `ActionUriBuilder` already enforce.
///
/// **When is agreement mandatory?** For `phone` and `url` — always. Those two
/// end in dialling and opening, and TINDAK already reads every Malaysian
/// number format and every scheme-bearing link, so a phone or link it cannot
/// derive is not a gap worth the risk. For `money` and `date`, agreement is
/// mandatory whenever the span contains a digit — `RM180`, `25/09/2026` — and
/// waived only for wholly written forms like `seribu lima ratus ringgit` or
/// `Jumaat depan`, which are the reason AI is here at all and which the user
/// confirms in full before anything irreversible happens.
final class CandidateValidator {
  const CandidateValidator({required this.engine, required this.clock});

  final UnderstandingEngine engine;
  final Clock clock;

  /// Below every local detector's minimum (0.60), so where a local entity and
  /// an AI candidate tie, the deterministic one wins. Never shown to anyone:
  /// ADR-009 rules out a number on screen, and this is not an exception.
  static const double aiConfidence = 0.5;

  /// A response claiming more than this is not a message being understood.
  static const int maxCandidates = 20;

  static const Duration pastWindow = Duration(days: 365);
  static const Duration futureWindow = Duration(days: 365 * 5);

  /// `+60` then a national number: the same shape `ActionUriBuilder` enforces
  /// at launch time, applied here so a bad value never even reaches a button.
  static final RegExp _malaysianE164 = RegExp(r'^\+60[1-9]\d{7,9}$');

  static final RegExp _anyDigit = RegExp(r'\d');
  static final RegExp _hasScheme = RegExp(r'^(https?://|www\.)', caseSensitive: false);

  /// Validates every candidate against [normalizedText], dropping duplicates
  /// and anything past [maxCandidates].
  List<CandidateVerdict> validateAll(
    List<AiCandidate> candidates,
    String normalizedText,
  ) {
    final verdicts = <CandidateVerdict>[];
    final seen = <String>{};

    for (final candidate in candidates.take(maxCandidates)) {
      final verdict = validate(candidate, normalizedText);
      if (verdict case CandidateAccepted(entity: final entity)) {
        final key = '${entity.type.name}|${entity.normalizedValue}|'
            '${entity.start}';
        if (!seen.add(key)) {
          verdicts.add(
            const CandidateRejected(CandidateRejection.duplicate),
          );
          continue;
        }
      }
      verdicts.add(verdict);
    }
    return verdicts;
  }

  CandidateVerdict validate(AiCandidate candidate, String normalizedText) {
    if (ContentNormalizer.containsFormatCharacter(candidate.span) ||
        ContentNormalizer.containsFormatCharacter(candidate.value)) {
      return const CandidateRejected(CandidateRejection.formatCharacter);
    }

    // 1. Grounding. Everything else is pointless if the model invented it.
    final start = normalizedText.indexOf(candidate.span);
    if (start < 0) {
      return const CandidateRejected(CandidateRejection.spanNotFound);
    }
    final end = start + candidate.span.length;

    // 2. TINDAK's own rule for the type. Checked before agreement so that a
    //    value TINDAK would never act on is reported as what it is, rather
    //    than as "could not derive".
    final rejection = _checkValue(candidate);
    if (rejection != null) return CandidateRejected(rejection);

    // 3. Agreement, where TINDAK can have an opinion.
    final derived = _derive(candidate.type, candidate.span);
    if (derived == null) {
      if (_derivationRequired(candidate)) {
        return const CandidateRejected(CandidateRejection.notDerivable);
      }
    } else if (derived != candidate.value) {
      return const CandidateRejected(CandidateRejection.valueMismatch);
    }

    return CandidateAccepted(
      DetectedEntity(
        type: candidate.type,
        // What the user reads is their own text, not the model's paraphrase.
        rawValue: candidate.span,
        normalizedValue: candidate.value,
        confidence: aiConfidence,
        start: start,
        end: end,
      ),
    );
  }

  /// Dialling and opening are never done on a value TINDAK cannot read for
  /// itself. Amounts and dates may be written out in words, which is the one
  /// thing the local engine genuinely cannot do — but only when the span
  /// carries no digits to check against.
  static bool _derivationRequired(AiCandidate candidate) =>
      switch (candidate.type) {
        EntityType.phone || EntityType.url => true,
        EntityType.money ||
        EntityType.date => _anyDigit.hasMatch(candidate.span),
      };

  /// What TINDAK's own detectors make of the span, alone.
  ///
  /// Only a detection covering the **whole** span counts: a number found
  /// inside a longer span says nothing about what that span means.
  String? _derive(EntityType type, String span) {
    final result = engine.understand(span);
    final matches = result.entities.where(
      (e) => e.type == type && e.start == 0 && e.end == span.length,
    );
    if (matches.length != 1) return null;
    return matches.first.normalizedValue;
  }

  CandidateRejection? _checkValue(AiCandidate candidate) {
    switch (candidate.type) {
      case EntityType.phone:
        return _malaysianE164.hasMatch(candidate.value)
            ? null
            : CandidateRejection.valueInvalid;

      case EntityType.url:
        final uri = Uri.tryParse(candidate.value);
        if (uri == null) return CandidateRejection.valueInvalid;
        final scheme = uri.scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          return CandidateRejection.valueInvalid;
        }
        final host = uri.host;
        if (host.isEmpty ||
            !host.contains('.') ||
            host.startsWith('.') ||
            host.endsWith('.') ||
            host.contains('..')) {
          return CandidateRejection.valueInvalid;
        }
        // PD-027: a bare domain is not a link, whichever path found it. The
        // rule is stated here rather than left to `UrlDetector` happening to
        // agree, so that it survives a change to either side.
        return _hasScheme.hasMatch(candidate.span)
            ? null
            : CandidateRejection.bareDomain;

      case EntityType.money:
        return MoneyValue.parse(candidate.value) == null
            ? CandidateRejection.valueInvalid
            : null;

      case EntityType.date:
        final date = DateValue.parse(candidate.value);
        if (date == null) return CandidateRejection.valueInvalid;
        final now = clock.now();
        final at = date.asDateTime;
        if (at.isBefore(now.subtract(pastWindow)) ||
            at.isAfter(now.add(futureWindow))) {
          return CandidateRejection.outOfWindow;
        }
        return null;
    }
  }
}
