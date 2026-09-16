import 'package:tindak/features/ai/model/ai_outcome.dart';

/// The one door out for AI, and the only thing the rest of TINDAK knows about
/// a model.
///
/// It takes the selected text and nothing else — no memory list, no other
/// memories, no email, no device id, no location, no surrounding content
/// (brief §15). It returns TINDAK's own vocabulary, so no provider's response
/// format reaches the domain or the screen.
///
/// **M9a ships no implementation of this in `lib/` at all.** The provider is
/// null, the gate answers `AiBlocker.notConfigured`, and the app says so in
/// plain words. That is not a stub waiting to be filled in — it is the
/// behaviour PD-048 requires until a provider whose terms permit user content
/// is chosen, and the cost fail-safe the brief asks for (§25), shipped first
/// rather than bolted on last.
abstract interface class AiUnderstandingProvider {
  Future<AiOutcome> understand(String text);
}
