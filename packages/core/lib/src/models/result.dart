import 'package:flutter/foundation.dart';

/// A Result type representing either a success value or an error
@immutable
sealed class Result<T, E> {
  const Result();

  /// Create a successful result
  const factory Result.success(T value) = Success<T, E>;

  /// Create an error result
  const factory Result.failure(E error) = Failure<T, E>;

  /// Check if this is a success
  bool get isSuccess => this is Success<T, E>;

  /// Check if this is a failure
  bool get isFailure => this is Failure<T, E>;

  /// Get the success value or null
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  /// Get the error or null
  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final error) => error,
      };

  /// Get the value or throw the error
  T get valueOrThrow => switch (this) {
        Success(:final value) => value,
        Failure(:final error) => throw error as Object,
      };

  /// Get the value or a default
  T valueOr(T defaultValue) => switch (this) {
        Success(:final value) => value,
        Failure() => defaultValue,
      };

  /// Map the success value
  Result<U, E> map<U>(U Function(T value) transform) => switch (this) {
        Success(:final value) => Result.success(transform(value)),
        Failure(:final error) => Result.failure(error),
      };

  /// Map the error value
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
        Success(:final value) => Result.success(value),
        Failure(:final error) => Result.failure(transform(error)),
      };

  /// FlatMap the success value
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) =>
      switch (this) {
        Success(:final value) => transform(value),
        Failure(:final error) => Result.failure(error),
      };

  /// Execute callback on success
  Result<T, E> onSuccess(void Function(T value) callback) {
    if (this case Success(:final value)) {
      callback(value);
    }
    return this;
  }

  /// Execute callback on failure
  Result<T, E> onFailure(void Function(E error) callback) {
    if (this case Failure(:final error)) {
      callback(error);
    }
    return this;
  }

  /// Fold to a single value
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final error) => onFailure(error),
      };
}

/// Successful result containing a value
@immutable
final class Success<T, E> extends Result<T, E> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T, E> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Failed result containing an error
@immutable
final class Failure<T, E> extends Result<T, E> {
  final E error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure<T, E> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Extension to convert nullable values to Result
extension NullableToResult<T> on T? {
  /// Convert nullable to Result with given error for null case
  Result<T, E> toResult<E>(E errorIfNull) {
    final value = this;
    if (value != null) {
      return Result.success(value);
    }
    return Result.failure(errorIfNull);
  }
}

/// Extension to convert Future to Result
extension FutureToResult<T> on Future<T> {
  /// Convert `Future<T>` to `Future<Result<T, Exception>>` catching errors
  Future<Result<T, Exception>> toResult() async {
    try {
      return Result.success(await this);
    } on Exception catch (e) {
      return Result.failure(e);
    }
  }
}
