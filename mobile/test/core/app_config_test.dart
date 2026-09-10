import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('is empty when no --dart-define is supplied', () {
      // `flutter test` runs without dart-defines, so this is the guest-first,
      // no-cloud-configuration case. It must be a normal state, not a crash:
      // PD-001 and PD-005 require the core loop to run with no cloud config.
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseAnonKey, isEmpty);
      expect(AppConfig.hasCloudConfig, isFalse);
    });

    test('hasCloudConfig requires both values', () {
      // Guards the shape of the check. Neither value alone is usable.
      expect(
        AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty,
        AppConfig.hasCloudConfig,
      );
    });
  });
}
