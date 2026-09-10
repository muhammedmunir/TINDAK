/// Every expected failure in TINDAK.
///
/// Sealed on purpose: UX section 26 requires each error to answer what happened,
/// what the user can still do, and what to do next. A sealed type forces the UI
/// to answer those questions for every case rather than falling back to a
/// generic "something went wrong".
///
/// [code] is a stable identifier safe for logs and telemetry. It never carries
/// user content — see docs/12_SECURITY.md section 11.
sealed class Failure {
  const Failure();

  String get code;
}

/// The device has no usable connection, or the request did not complete.
///
/// Never shown for an operation that can succeed locally (UX section 18).
final class NetworkFailure extends Failure {
  const NetworkFailure();

  @override
  String get code => 'network';
}

/// The local database could not be read or written.
final class StorageFailure extends Failure {
  const StorageFailure();

  @override
  String get code => 'storage';
}

/// The requested row does not exist, or is not visible to the current owner.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();

  @override
  String get code => 'not_found';
}

/// An Android runtime permission was refused.
///
/// A refusal is never fatal. A denied notification permission still saves the
/// reminder (PD-026).
final class PermissionFailure extends Failure {
  const PermissionFailure(this.permission);

  final String permission;

  @override
  String get code => 'permission';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionFailure && permission == other.permission;

  @override
  int get hashCode => Object.hash(runtimeType, permission);
}

/// The operation needs a signed-in account.
///
/// ADR-025: authentication is required for cloud features that consume
/// protected or limited server resources, or that reach account-owned data.
/// Local features never produce this failure.
final class AuthRequiredFailure extends Failure {
  const AuthRequiredFailure();

  @override
  String get code => 'auth_required';
}

/// Anything not anticipated. Carries a stable [reason] code, never a message
/// built from user content.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([this.reason = 'unexpected']);

  final String reason;

  @override
  String get code => reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnexpectedFailure && reason == other.reason;

  @override
  int get hashCode => Object.hash(runtimeType, reason);
}
