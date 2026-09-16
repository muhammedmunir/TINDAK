import 'package:tindak/features/understanding/model/entity_type.dart';

/// One claim from the model. **Not** an entity, and never treated as one.
///
/// A candidate becomes a `DetectedEntity` only after `CandidateValidator`
/// proves three separate things: that [span] is really part of the user's own
/// text, that [value] is one TINDAK's own rules accept, and — wherever TINDAK
/// can work the answer out for itself — that [value] is exactly what those
/// rules derive from [span] (PD-048 review, ADR-033).
///
/// [type] reuses [EntityType] rather than declaring a parallel enum, so the
/// allow-list is enforced by the compiler: there is no way to express `person`
/// or `bank_account` here without an enum change that breaks every exhaustive
/// switch in the action layer.
final class AiCandidate {
  const AiCandidate({
    required this.type,
    required this.span,
    required this.value,
  });

  final EntityType type;

  /// The characters the model says it read this from, quoted verbatim from the
  /// normalised text. A span that is not found there is a fabrication.
  final String span;

  /// TINDAK's canonical form — E.164, `MYR<sen>`, ISO date, absolute URL.
  /// Often not present in the text at all: `Jumaat depan` has no date in it.
  final String value;

  /// Parses one entry of the response envelope. Returns null for anything
  /// TINDAK does not recognise, which is how an unsupported entity type is
  /// dropped rather than mapped onto the nearest thing (brief §9).
  static AiCandidate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final type = _typeOf(raw['type']);
    final span = raw['span'];
    final value = raw['value'];
    if (type == null || span is! String || value is! String) return null;
    if (span.isEmpty || value.isEmpty) return null;
    return AiCandidate(type: type, span: span, value: value);
  }

  static EntityType? _typeOf(Object? raw) => switch (raw) {
    'phone' => EntityType.phone,
    'url' => EntityType.url,
    'money' => EntityType.money,
    'date' => EntityType.date,
    _ => null,
  };

  /// Deliberately excludes [span] and [value]. A candidate holds a phone
  /// number or a link out of someone's message, and must not reach a log
  /// (docs/12_SECURITY.md §11).
  @override
  String toString() => 'AiCandidate(${type.name})';
}
