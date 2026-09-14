/// Text after [ContentNormalizer], ready for detectors.
///
/// Detectors only ever see this type, never raw input. That is how PD-032 is
/// guaranteed structurally: a detector written later cannot forget to strip
/// invisible characters, because it is never handed a string that still has
/// them.
///
/// Offsets on a detected entity refer to [text], not to the original input.
final class NormalizedContent {
  const NormalizedContent(this.text);

  final String text;

  bool get isEmpty => text.trim().isEmpty;

  /// Deliberately excludes [text] (docs/12_SECURITY.md section 11).
  @override
  String toString() => 'NormalizedContent(characters: ${text.length})';
}
