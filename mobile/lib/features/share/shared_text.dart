/// Text received from an Android share intent.
///
/// The raw payload, before any understanding. M2 receives and displays it;
/// detection arrives at M3.
///
/// [text] is untrusted: it came from whatever app performed the share. It is
/// only ever rendered as plain characters.
final class SharedText {
  const SharedText({
    required this.sequence,
    required this.text,
    required this.receivedAt,
    this.sourceApp,
  });

  /// Monotonic id assigned by the Android side.
  ///
  /// Used to discard a repeat: the same share can reach Dart twice if the
  /// initial-share request and a new-intent callback race during cold start.
  final int sequence;

  /// The shared text, exactly as received.
  final String text;

  /// When Android handed the intent over.
  final DateTime receivedAt;

  /// The sending package, when Android disclosed it. Best effort, often null,
  /// never trusted, never drives behaviour.
  final String? sourceApp;

  int get characterCount => text.length;

  /// Builds a [SharedText] from a platform channel payload.
  ///
  /// Returns null for anything unusable. The channel carries data from an
  /// attacker-controlled intent, so every field is checked rather than cast:
  /// a malformed payload must fail safely, not throw into the widget tree.
  static SharedText? tryFrom(Object? payload) {
    if (payload is! Map) return null;

    final Object? sequence = payload['sequence'];
    final Object? text = payload['text'];
    final Object? receivedAt = payload['receivedAt'];
    final Object? sourceApp = payload['sourceApp'];

    if (sequence is! int) return null;
    if (text is! String || text.isEmpty) return null;

    return SharedText(
      sequence: sequence,
      text: text,
      receivedAt: receivedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(receivedAt)
          : DateTime.fromMillisecondsSinceEpoch(0),
      sourceApp: sourceApp is String && sourceApp.isNotEmpty ? sourceApp : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedText &&
          sequence == other.sequence &&
          text == other.text &&
          receivedAt == other.receivedAt &&
          sourceApp == other.sourceApp;

  @override
  int get hashCode => Object.hash(sequence, text, receivedAt, sourceApp);

  /// Deliberately excludes [text]. A shared string must never reach a log
  /// through a stray toString (docs/12_SECURITY.md section 11).
  @override
  String toString() =>
      'SharedText(sequence: $sequence, characters: $characterCount)';
}
