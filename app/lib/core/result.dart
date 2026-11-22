/// Explicit success/failure type used across repositories so the UI can map
/// failures to a "gagal muat" state instead of relying on thrown exceptions.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => success(value),
      Failure<T>(failure: final f) => failure(f),
    };
  }

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

/// A user-presentable failure.
class AppFailure {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($message${cause == null ? '' : ', $cause'})';
}

/// Runs [body] and converts any thrown error into a [Failure].
Future<Result<T>> guard<T>(
  Future<T> Function() body, {
  String message = 'Gagal memuat data.',
}) async {
  try {
    return Success(await body());
  } on AppFailure catch (f) {
    return Failure(f);
  } catch (e) {
    return Failure(AppFailure(message, cause: e));
  }
}
