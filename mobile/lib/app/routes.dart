/// Route names.
///
/// Navigator 1.0 with a named route table, no routing package (ADR-018).
/// Five screens, no nested navigators, and the share entry point arrives as an
/// Android intent rather than a deep link.
final class Routes {
  const Routes._();

  /// Home and empty state. The launcher entry point.
  static const String home = '/';

  // Added by their own milestones:
  //   shareResult  M2
  //   memory       M5a
  //   memoryDetail M5a
  //   settings     M5b
}
