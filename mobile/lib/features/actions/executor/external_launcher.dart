import 'package:url_launcher/url_launcher.dart';

/// Hands a validated URI to another Android app.
///
/// An interface so tests can record exactly which URIs were launched, and
/// when. That record is how "no action without a tap" and "no repeat on a
/// lifecycle event" are proven rather than asserted.
abstract interface class ExternalLauncher {
  /// True when Android accepted the URI and started an app for it.
  Future<bool> launch(Uri uri);
}

/// The only code in TINDAK that calls `url_launcher`
/// (docs/10_ARCHITECTURE.md section 6).
final class UrlLauncherExternalLauncher implements ExternalLauncher {
  const UrlLauncherExternalLauncher();

  @override
  Future<bool> launch(Uri uri) => launchUrl(
    uri,
    // Always a separate app — the dialer, WhatsApp, the browser. Never an
    // in-app browser view: TINDAK has no WebView anywhere
    // (docs/12_SECURITY.md section 7).
    mode: LaunchMode.externalApplication,
  );
}
