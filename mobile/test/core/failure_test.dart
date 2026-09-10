import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/failure/failure.dart';

void main() {
  group('Failure', () {
    test('every case exposes a stable code', () {
      const failures = <Failure>[
        NetworkFailure(),
        StorageFailure(),
        NotFoundFailure(),
        PermissionFailure('notifications'),
        AuthRequiredFailure(),
        UnexpectedFailure(),
      ];

      for (final failure in failures) {
        expect(failure.code, isNotEmpty, reason: '${failure.runtimeType}');
      }
    });

    test('codes are unique across cases', () {
      const codes = <String>[
        'network',
        'storage',
        'not_found',
        'permission',
        'auth_required',
        'unexpected',
      ];

      expect(codes.toSet().length, codes.length);
    });

    test('codes carry no user content', () {
      // docs/12_SECURITY.md section 11: a code is safe for logs and telemetry.
      // PermissionFailure carries a permission name, never a memory value.
      const failure = PermissionFailure('notifications');

      expect(failure.code, 'permission');
      expect(failure.permission, 'notifications');
    });

    test('failures of the same case are equal', () {
      expect(const StorageFailure(), const StorageFailure());
      expect(
        const PermissionFailure('notifications'),
        const PermissionFailure('notifications'),
      );
      expect(
        const PermissionFailure('notifications'),
        isNot(const PermissionFailure('camera')),
      );
    });
  });
}
