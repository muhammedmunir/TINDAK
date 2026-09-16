/// Sign-in for TINDAK, as the app sees it: email and a six-digit code
/// (ADR-020). Pure Dart; the Supabase implementation lives in
/// `supabase_auth_gateway.dart`.
abstract interface class AuthGateway {
  /// False when this build has no cloud configuration. TINDAK is guest-first,
  /// so that is a normal state and every local feature still works.
  bool get isAvailable;

  /// The signed-in account, or null for a guest.
  Account? get currentAccount;

  /// Emits whenever the signed-in account changes, including a session that
  /// ends on its own.
  Stream<Account?> get accountChanges;

  /// Emails a six-digit code. Creates the account on first use.
  Future<AuthOutcome> sendCode(String email);

  /// Exchanges the code for a session, stored in secure storage.
  Future<AuthOutcome> verifyCode(String email, String code);

  /// Ends the session on this device. Called only after this account's local
  /// rows are purged (ADR-031). Never fails: the local session is removed
  /// first, and revoking it on the server is best effort.
  Future<void> endSession();
}

final class Account {
  const Account({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Account && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// The email is personal data and is not printed.
  @override
  String toString() => 'Account($id)';
}

enum AuthOutcome {
  success,
  invalidEmail,

  /// Wrong or expired. Not distinguished to the user: both mean "get a new
  /// code".
  invalidCode,

  /// Too many codes requested or attempts made.
  rateLimited,
  offline,
  failed,
}

/// Used when the build has no cloud configuration.
final class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  bool get isAvailable => false;

  @override
  Account? get currentAccount => null;

  @override
  Stream<Account?> get accountChanges => const Stream<Account?>.empty();

  @override
  Future<AuthOutcome> sendCode(String email) async => AuthOutcome.failed;

  @override
  Future<AuthOutcome> verifyCode(String email, String code) async =>
      AuthOutcome.failed;

  @override
  Future<void> endSession() async {}
}
