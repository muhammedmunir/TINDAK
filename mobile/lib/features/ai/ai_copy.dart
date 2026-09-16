import 'package:tindak/features/ai/model/ai_outcome.dart';

/// Every word the AI path shows.
///
/// One fixed sentence per state, approved with the milestone. Nothing is
/// assembled from the user's text, nothing is generated, and **no model output
/// is ever displayed as prose** — the model returns values, and TINDAK supplies
/// the words around them.
///
/// Nothing here claims AI is right. There is no percentage, no score and no
/// "confidence", because ADR-009 rules those out and AI is not an exception.
final class AiCopy {
  const AiCopy._();

  /// The only way into the AI path (brief §2).
  static const String tryAction = 'Cuba dengan AI';

  static const String title = 'Bantuan AI';
  static const String resultHeading = 'AI menemui';
  static const String working = 'Memproses…';
  static const String closeAction = 'Tutup';
  static const String cancelAction = 'Batal';
  static const String continueAction = 'Teruskan';
  static const String signInAction = 'Log Masuk';
  static const String notNowAction = 'Bukan Sekarang';

  /// Shown under every AI result. The user decides, not the model (brief §12).
  static const String disclaimer =
      'Maklumat ini dicadangkan oleh AI. Semak sebelum anda bertindak.';

  // The one-time disclosure, shown before any text is sent for the first time
  // (PD-011). Separate from the Protect disclosure in M8.
  static const String disclosureTitle = 'Bantu fahami dengan AI';
  static const String disclosureBody =
      'TINDAK akan menghantar teks yang anda pilih kepada perkhidmatan AI '
      'untuk membantu mengenal pasti maklumat dan tindakan yang berkaitan. '
      'Jangan hantar maklumat yang anda tidak mahu diproses oleh perkhidmatan '
      'AI.';

  /// A guest pressed the button. Sign-in is not consent: the disclosure still
  /// follows (PD-024).
  static const String signInRequired = 'Log masuk untuk menggunakan AI.';

  /// PD-028's 2,000, said with the number so the user knows what to change.
  /// Nothing is truncated and nothing is sent.
  static const String tooLong =
      'Teks terlalu panjang untuk diproses dengan AI. Had ialah 2,000 aksara.';

  /// No provider configured — the normal state under PD-048. TINDAK says so
  /// rather than pretending AI is available.
  static const String notConfigured = 'AI tidak tersedia buat masa ini.';

  /// The request worked and found nothing supported. Not an error, and never
  /// replaced by an invented result (brief §13).
  static const String nothingFound =
      'AI tidak menemui tindakan yang disokong dalam teks ini.';

  /// Why the request produced nothing. Availability, never a judgement about
  /// the text, and never a reason to lose what is already on screen.
  static String failure(AiFailure failure) => switch (failure) {
    AiFailure.offline =>
      'Tiada sambungan internet. TINDAK masih berfungsi tanpa AI.',
    AiFailure.timeout ||
    AiFailure.unavailable =>
      'AI tidak dapat dihubungi sekarang. Cuba lagi kemudian.',
    AiFailure.quotaDaily =>
      'Had penggunaan AI hari ini telah dicapai. Cuba lagi esok.',
    AiFailure.quotaBurst => 'Terlalu banyak permintaan. Cuba lagi sebentar.',
    AiFailure.notAuthenticated => signInRequired,
    AiFailure.unreadable =>
      'AI tidak dapat memproses teks ini. Cuba lagi kemudian.',
  };
}
