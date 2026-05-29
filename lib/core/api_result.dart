/// Унифицированный результат операции: либо данные [T], либо ошибка [AppError].
/// Заменяет голые try/catch и nullable-возвраты.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get data => (this is Success<T>) ? (this as Success<T>).value : null;
  AppError? get error =>
      (this is Failure<T>) ? (this as Failure<T>).error : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => success(v),
      Failure<T>(error: final e) => failure(e),
    };
  }
}

class Success<T> extends ApiResult<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends ApiResult<T> {
  @override
  final AppError error;
  const Failure(this.error);
}

/// Структурированная ошибка приложения.
class AppError {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const AppError({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  factory AppError.network([dynamic original]) => AppError(
      message: 'Ошибка сети. Проверьте подключение.', originalError: original);

  factory AppError.unauthorized() => const AppError(
      message: 'Сессия истекла. Войдите снова.', statusCode: 401);

  factory AppError.server([int? code, dynamic original]) => AppError(
      message: 'Ошибка сервера. Попробуйте позже.',
      statusCode: code,
      originalError: original);

  factory AppError.unknown([dynamic original]) =>
      AppError(message: 'Неизвестная ошибка.', originalError: original);

  factory AppError.validation(String msg) =>
      AppError(message: msg, statusCode: 400);

  @override
  String toString() => 'AppError(message: $message, statusCode: $statusCode)';
}
