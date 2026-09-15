/// The one error type every data source throws.
///
/// The backend speaks a single error shape — `{"code", "message", "detail"}` — and a status code.
/// This turns both into a typed Dart exception the UI can branch on: show the [message] to the user,
/// switch on the [code] for specific handling (`invalid_credentials`, `category_name_taken`), and
/// use the boolean helpers ([isUnauthorized], [isConflict], …) when only the class of failure
/// matters. A network failure with no HTTP response becomes an [ApiException.network].
library;

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.detail = const {},
    this.isNetworkError = false,
  });

  /// A transport failure — no connection, timeout, DNS — where no HTTP response came back.
  const ApiException.network([String message = 'Could not reach the server'])
      : this(message: message, code: 'network_error', isNetworkError: true);

  /// The backend's machine code, e.g. `invalid_credentials`. Null for non-domain failures.
  final String? code;

  /// A human-readable message, safe to show.
  final String message;

  /// The HTTP status, when there was a response.
  final int? statusCode;

  /// The backend's `detail` object, verbatim.
  final Map<String, Object?> detail;

  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  bool get isConflict => statusCode == 409;

  bool get isValidation => statusCode == 422;

  /// Build from whatever Dio threw. A response with our error body keeps its code and detail; a
  /// transport error becomes a network exception; anything else falls back to a generic message.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException.network();
    }
    final data = response.data;
    if (data is Map) {
      final map = data.cast<String, Object?>();
      final detail = map['detail'];
      return ApiException(
        code: map['code'] as String?,
        message: (map['message'] as String?) ?? 'Something went wrong',
        statusCode: response.statusCode,
        detail: detail is Map ? detail.cast<String, Object?>() : const {},
      );
    }
    return ApiException(
      message: 'Unexpected response from the server',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
