/// The reusable HTTP client every data source is built on.
///
/// One [ApiClient] wraps one configured [Dio]. It does three things and nothing else, so every
/// resource (auth, categories, expenses) shares exactly the same behaviour:
///
/// 1. **Base URL and timeouts** from [ApiConfig], set once.
/// 2. **The bearer token**, attached by an interceptor that reads it from the [AuthTokenStore] on
///    every request — so signing in or out changes nothing the data sources have to know about.
/// 3. **Typed errors**: every Dio failure is converted to an [ApiException] before it leaves the
///    client, so a caller catches one exception type and never imports Dio.
///
/// The thin verb methods ([get], [post], [patch], [delete]) return decoded JSON. Data sources layer
/// DTO mapping on top; they never touch Dio directly.
library;

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'auth_token_store.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
}

class ApiClient {
  ApiClient({
    required ApiConfig config,
    required AuthTokenStore tokenStore,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        _dio = dio ?? Dio() {
    _configure(config);
  }

  // A named initializing formal for a private field is not possible together with the `dio`
  // fallback in one clean signature, so the assignment stays explicit; the lint is a style
  // preference, not a correctness issue.
  // ignore_for_file: prefer_initializing_formals

  void _configure(ApiConfig config) {
    _dio.options
      ..baseUrl = config.baseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..headers['Content-Type'] = 'application/json'
      // Never throw on a status code by default; the verb methods below decide.
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  /// Exposed so a test can install a mock adapter or assert on interceptors.
  Dio get dio => _dio;

  Future<Object?> get(String path, {Map<String, Object?>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<Object?> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  /// Returns the decoded body, or null for a 204 No Content.
  Future<Object?> delete(String path) => _send(() => _dio.delete(path));

  /// Run a request, turn a non-2xx into an [ApiException], and hand back the decoded body.
  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return response.data;
    }
    // A 4xx came back within validateStatus; render the body as our error shape.
    final data = response.data;
    if (data is Map) {
      final map = data.cast<String, Object?>();
      final detail = map['detail'];
      throw ApiException(
        code: map['code'] as String?,
        message: (map['message'] as String?) ?? 'Request failed',
        statusCode: status,
        detail: detail is Map ? detail.cast<String, Object?>() : const {},
      );
    }
    throw ApiException(message: 'Request failed', statusCode: status);
  }

  /// Drop null query values so an omitted filter is not sent as the string "null".
  Map<String, Object?>? _clean(Map<String, Object?>? query) {
    if (query == null) return null;
    final cleaned = <String, Object?>{};
    query.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned;
  }
}
