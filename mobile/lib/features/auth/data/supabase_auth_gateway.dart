import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/auth/data/secure_session_storage.dart';

/// [AuthGateway] over Supabase Auth email OTP.
///
/// One of the only files in TINDAK that may import Supabase
/// (test/features/understanding/layer_purity_test.dart).
final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth, this._sessionStorage);

  final GoTrueClient _auth;
  final SecureSessionStorage _sessionStorage;

  static const AppLogger _log = AppLogger('auth');
  static const Duration _timeout = Duration(seconds: 30);

  @override
  bool get isAvailable => true;

  @override
  Account? get currentAccount => _accountOf(_auth.currentUser);

  @override
  Stream<Account?> get accountChanges => _auth.onAuthStateChange
      .map((state) => _accountOf(state.session?.user))
      // A token refresh re-emits the same account; only a change matters.
      .distinct()
      .handleError((Object _) {});

  @override
  Future<AuthOutcome> sendCode(String email) => _attempt('send_code', () async {
    // No emailRedirectTo: the code is typed inside TINDAK, so no deep link is
    // involved (ADR-020, ADR-018).
    await _auth
        .signInWithOtp(email: email.trim(), shouldCreateUser: true)
        .timeout(_timeout);
  });

  @override
  Future<AuthOutcome> verifyCode(String email, String code) =>
      _attempt('verify_code', () async {
        final response = await _auth
            .verifyOTP(email: email.trim(), token: code, type: OtpType.email)
            .timeout(_timeout);
        if (response.session == null) {
          throw const AuthException('no session', code: 'otp_expired');
        }
      });

  @override
  Future<void> endSession() async {
    try {
      await _auth.signOut(scope: SignOutScope.local).timeout(_timeout);
    } on Object catch (error) {
      // The local session is already gone before the server is asked to
      // revoke it. Offline, only that request fails.
      _log.failure('auth_sign_out_revoke_${error.runtimeType}');
    }
    try {
      await _sessionStorage.removePersistedSession();
    } on Object catch (error) {
      _log.failure('auth_session_remove_${error.runtimeType}');
    }
  }

  static Account? _accountOf(User? user) =>
      user == null ? null : Account(id: user.id, email: user.email);

  /// Maps Supabase errors to outcomes. Logs codes only: an auth error message
  /// can contain the email address.
  Future<AuthOutcome> _attempt(
    String operation,
    Future<void> Function() call,
  ) async {
    try {
      await call();
      return AuthOutcome.success;
    } on AuthRetryableFetchException {
      _log.failure('auth_${operation}_offline');
      return AuthOutcome.offline;
    } on AuthException catch (e) {
      final code = e.code ?? '';
      _log.failure('auth_${operation}_${code.isEmpty ? e.statusCode : code}');
      if (e.statusCode == '429' || code.startsWith('over_')) {
        return AuthOutcome.rateLimited;
      }
      if (code == 'otp_expired' || code == 'invalid_credentials') {
        return AuthOutcome.invalidCode;
      }
      if (code == 'email_address_invalid' || code == 'validation_failed') {
        return AuthOutcome.invalidEmail;
      }
      return AuthOutcome.failed;
    } on TimeoutException {
      _log.failure('auth_${operation}_timeout');
      return AuthOutcome.offline;
    } on Object catch (error) {
      // SocketException and ClientException arrive here when the device is
      // offline before gotrue can wrap them.
      _log.failure('auth_${operation}_${error.runtimeType}');
      return AuthOutcome.offline;
    }
  }
}
