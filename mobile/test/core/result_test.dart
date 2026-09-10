import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/result/result.dart';

void main() {
  group('Result', () {
    test('Ok carries its value', () {
      const result = Result<int>.ok(7);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('Err carries its failure', () {
      const result = Result<int>.err(StorageFailure());

      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test('fold takes the matching branch', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(NetworkFailure());

      expect(ok.fold(onOk: (v) => 'ok:$v', onErr: (f) => 'err:${f.code}'),
          'ok:2');
      expect(err.fold(onOk: (v) => 'ok:$v', onErr: (f) => 'err:${f.code}'),
          'err:network');
    });

    test('map transforms a value and leaves a failure untouched', () {
      const ok = Result<int>.ok(3);
      const err = Result<int>.err(NotFoundFailure());

      expect(ok.map((v) => v * 2).valueOrNull, 6);
      expect(err.map((v) => v * 2).failureOrNull, isA<NotFoundFailure>());
    });

    test('values with the same content are equal', () {
      expect(const Result<int>.ok(1), const Result<int>.ok(1));
      expect(const Result<int>.ok(1), isNot(const Result<int>.ok(2)));
      expect(
        const Result<int>.err(StorageFailure()),
        const Result<int>.err(StorageFailure()),
      );
    });

    test('a switch over Result is exhaustive', () {
      // This test exists to fail at compile time if Result stops being sealed.
      // docs/10_ARCHITECTURE.md section 14 depends on exhaustiveness.
      String describe(Result<int> r) => switch (r) {
        Ok<int>(:final value) => 'ok $value',
        Err<int>(:final failure) => 'err ${failure.code}',
      };

      expect(describe(const Result<int>.ok(1)), 'ok 1');
      expect(describe(const Result<int>.err(NetworkFailure())), 'err network');
    });
  });
}
