/// How text got into TINDAK.
///
/// Both paths are explicit and user-initiated (PD-033, ADR-029). There is no
/// third value and there must never be a passive one.
enum IntakeSource {
  /// An Android `ACTION_SEND` `text/plain` intent.
  share,

  /// The user pressed Tampal and TINDAK read the clipboard once.
  paste,
}

/// Text that has entered TINDAK, before any understanding.
///
/// Everything downstream — detectors, actions, screens, Memory — sees this type
/// and never learns which path the text arrived by. That is why the two intake
/// paths converge here rather than being special-cased later
/// (docs/10_ARCHITECTURE.md section 8.5).
///
/// [text] is untrusted. It came from another app, or from a clipboard any app
/// can write to. It is only ever rendered as plain characters.
final class IncomingText {
  const IncomingText({
    required this.text,
    required this.source,
    required this.receivedAt,
    this.sequence = 0,
    this.sourceApp,
  });

  /// Text the user pasted.
  ///
  /// [sequence] stays 0: a paste is a discrete user action that cannot arrive
  /// twice by accident, so it is never deduplicated.
  factory IncomingText.pasted(String text, {required DateTime at}) =>
      IncomingText(
        text: text,
        source: IntakeSource.paste,
        receivedAt: at,
      );

  final String text;
  final IntakeSource source;
  final DateTime receivedAt;

  /// Monotonic id from the Android side. Meaningful for [IntakeSource.share]
  /// only, where the same intent can be delivered twice.
  final int sequence;

  /// The sending package, when Android disclosed it. Best effort, often null,
  /// never trusted, never drives behaviour. Always null for a paste — the
  /// clipboard does not say who filled it.
  final String? sourceApp;

  int get characterCount => text.length;

  /// Builds share-sourced text from a platform channel payload.
  ///
  /// Returns null for anything unusable. The channel carries data derived from
  /// an attacker-controlled intent, so every field is checked rather than cast:
  /// a malformed payload must fail safely, not throw into the widget tree.
  static IncomingText? fromSharePayload(Object? payload) {
    if (payload is! Map) return null;

    final Object? sequence = payload['sequence'];
    final Object? text = payload['text'];
    final Object? receivedAt = payload['receivedAt'];
    final Object? sourceApp = payload['sourceApp'];

    if (sequence is! int) return null;
    if (text is! String || text.trim().isEmpty) return null;

    return IncomingText(
      text: text,
      source: IntakeSource.share,
      sequence: sequence,
      receivedAt: receivedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(receivedAt)
          : DateTime.fromMillisecondsSinceEpoch(0),
      sourceApp: sourceApp is String && sourceApp.isNotEmpty ? sourceApp : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomingText &&
          text == other.text &&
          source == other.source &&
          receivedAt == other.receivedAt &&
          sequence == other.sequence &&
          sourceApp == other.sourceApp;

  @override
  int get hashCode =>
      Object.hash(text, source, receivedAt, sequence, sourceApp);

  /// Deliberately excludes [text]. Neither a shared message nor a clipboard's
  /// contents may reach a log through a stray toString
  /// (docs/12_SECURITY.md section 11).
  @override
  String toString() =>
      'IncomingText(source: ${source.name}, sequence: $sequence, '
      'characters: $characterCount)';
}
