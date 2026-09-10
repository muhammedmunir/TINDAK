/// Build-time configuration.
///
/// Values arrive through `--dart-define` so a build for a different environment
/// needs no source change and nothing environment-specific is committed.
///
/// ```
/// flutter build appbundle --release \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// ```
///
/// **Only public values belong here.** Anything in this class ships inside the
/// APK and can be read by anyone who installs it. The Supabase anon key is
/// public by design and scoped by RLS; a service-role key, a Gemini key or a
/// reputation-provider key must never appear here. Those live in Supabase Edge
/// Function config and are reached through an Edge Function.
/// See docs/12_SECURITY.md section 6 and AI Rule 9.
final class AppConfig {
  const AppConfig._();

  /// Supabase project URL. Empty until a cloud milestone supplies it.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon key. Public, RLS-scoped.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether cloud configuration is present.
  ///
  /// False is a normal state, not an error. TINDAK is guest-first and
  /// local-first (PD-001, PD-005): the core loop runs with no cloud
  /// configuration at all.
  static bool get hasCloudConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
