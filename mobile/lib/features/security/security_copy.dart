import 'package:tindak/features/security/model/security_assessment.dart';

/// Every word Protect shows (M8a).
///
/// One fixed sentence per finding code: nothing is assembled from the link,
/// and no wording is generated. A new check means a new line here, approved
/// with it.
///
/// **Nothing here ever claims a link is safe.** HTTPS earns no praise, a clean
/// scan is "no signs found", and the disclaimer is on every result.
final class SecurityCopy {
  const SecurityCopy._();

  static const String checkAction = 'Semak Keselamatan';
  static const String title = 'Semakan Keselamatan';
  static const String reasonsHeading = 'Sebab';
  static const String openAction = 'Buka Pautan';
  static const String closeAction = 'Tutup';
  static const String cancelAction = 'Batal';
  static const String signInAction = 'Log Masuk';
  static const String notNowAction = 'Bukan Sekarang';

  /// On every completed assessment, whatever the level.
  static const String disclaimer =
      'Semakan ini membantu mengenal pasti tanda risiko, tetapi tidak '
      'menjamin bahawa pautan adalah selamat.';

  /// Before opening something with signs of risk (PD-014: the user decides).
  static const String riskyOpenQuestion =
      'Pautan ini mempunyai tanda risiko. Anda masih mahu membukanya?';

  static const String noLocalFindings =
      'Tiada tanda risiko ditemui dalam semakan tempatan.';

  static String levelLabel(RiskLevel level) => switch (level) {
    RiskLevel.low => 'RISIKO RENDAH',
    RiskLevel.caution => 'BERHATI-HATI',
    RiskLevel.suspicious => 'MENCURIGAKAN',
    RiskLevel.high => 'RISIKO TINGGI',
  };

  /// The online layer's state, said as availability and never as a verdict
  /// (C-1).
  static String onlineStatus(OnlineCheckStatus status) => switch (status) {
    OnlineCheckStatus.notChecked => 'Semakan dalam talian belum dilakukan.',
    OnlineCheckStatus.signInRequired =>
      'Log masuk untuk semakan keselamatan dalam talian.',
    OnlineCheckStatus.clean =>
      'Tiada ancaman diketahui ditemui dalam semakan dalam talian.',
    OnlineCheckStatus.threatFound =>
      'Perkhidmatan reputasi menandakan pautan ini sebagai ancaman.',
    OnlineCheckStatus.unavailable => 'Semakan dalam talian tidak tersedia.',
  };

  /// One factual sentence per signal. Each says what was found, not what it
  /// means about the person who sent it.
  static String reason(SecurityFindingCode code) => switch (code) {
    SecurityFindingCode.credentialsInUrl =>
      'Pautan ini mengandungi nama pengguna atau kata laluan sebelum nama '
          'domain.',
    SecurityFindingCode.encodedAuthorityCharacter =>
      'Nama domain dalam pautan ini disembunyikan menggunakan aksara berkod.',
    SecurityFindingCode.mixedScriptHost =>
      'Nama domain mencampurkan huruf daripada sistem tulisan berbeza.',
    SecurityFindingCode.normalisationMismatch =>
      'Pautan yang dipaparkan berbeza daripada pautan sebenar.',
    SecurityFindingCode.notEncrypted =>
      'Pautan ini tidak menggunakan sambungan HTTPS.',
    SecurityFindingCode.ipAddressHost =>
      'Pautan ini menggunakan alamat IP secara terus.',
    SecurityFindingCode.punycodeHost =>
      'Nama domain menggunakan format Punycode.',
    SecurityFindingCode.unusualPort =>
      'Pautan ini menggunakan port yang tidak biasa.',
    SecurityFindingCode.deepSubdomains =>
      'Nama domain mempunyai terlalu banyak bahagian.',
    SecurityFindingCode.urlShortener =>
      'Pautan ini menggunakan perkhidmatan pemendek pautan, jadi destinasi '
          'sebenar tidak kelihatan.',
  };
}
