import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tindak/core/config/app_config.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/secure_session_storage.dart';
import 'package:tindak/features/auth/data/supabase_auth_gateway.dart';
import 'package:tindak/features/sync/data/supabase_cloud_memory_api.dart';
import 'package:tindak/features/sync/sync_providers.dart';

/// Connects TINDAK to Supabase when, and only when, the build carries cloud
/// configuration.
///
/// One of the only files that may import Supabase
/// (test/features/understanding/layer_purity_test.dart).
///
/// Never fatal. Without configuration, or if starting Supabase fails, TINDAK
/// runs exactly as the guest-only app of M5a: every local feature works and
/// Settings says Cloud Sync is unavailable.
final class CloudBootstrap {
  const CloudBootstrap._();

  static const AppLogger _log = AppLogger('cloud');

  static Future<List<Override>> start() async {
    if (!AppConfig.hasCloudConfig) return const <Override>[];

    const sessionStorage = SecureSessionStorage();
    try {
      final supabase = await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // The publishable key: public by design, scoped by RLS.
        publishableKey: AppConfig.supabaseAnonKey,
        // Supabase's own logging can print request details, including the
        // email address being signed in.
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          localStorage: sessionStorage,
          pkceAsyncStorage: sessionStorage,
          // The code is typed in the app; no auth deep link exists to detect
          // (ADR-018, ADR-020).
          detectSessionInUri: false,
        ),
      );
      final client = supabase.client;
      return <Override>[
        authGatewayProvider.overrideWithValue(
          SupabaseAuthGateway(client.auth, sessionStorage),
        ),
        cloudMemoryApiProvider.overrideWithValue(
          SupabaseCloudMemoryApi(client),
        ),
      ];
    } on Object catch (error) {
      _log.failure('cloud_start_failed_${error.runtimeType}');
      return const <Override>[];
    }
  }
}
