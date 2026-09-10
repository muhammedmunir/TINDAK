import 'package:tindak/core/failure/failure.dart';

/// The outcome of an operation that is expected to be able to fail.
///
/// Application and domain layers return [Result] instead of throwing. Exceptions
/// are reserved for programmer error. Because [Result] is sealed, a `switch` over
/// it is exhaustive and the compiler will not let a failure path be forgotten.
///
/// See docs/10_ARCHITECTURE.md section 14.
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a failure.
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// The value, or `null` when this is a failure.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or `null` when this is a success.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onErr,
  }) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };

  /// Transforms a successful value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ok<T> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Err<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'Err($failure)';
}
