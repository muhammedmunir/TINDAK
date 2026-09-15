/// Route names.
///
/// Navigator 1.0 with a named route table, no routing package (ADR-018).
final class Routes {
  const Routes._();

  /// Home — Memory, or the empty state before anything is saved. The share
  /// and paste result is swapped in over it rather than pushed.
  static const String home = '/';

  /// One saved item. Argument: the memory id.
  static const String memoryDetail = '/memory';

  // Added by their own milestones:
  //   settings     M5b
}
