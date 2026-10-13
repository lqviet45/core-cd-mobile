import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/session_manager.dart';

/// Gắn Bearer token, làm mới trước khi hết hạn và thử lại **đúng một lần** khi gặp 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session, this._dio);

  static const _retriedKey = 'auth_retried';

  final SessionManager _session;

  /// Dio dùng để thử lại request (cùng instance đã gắn interceptor này).
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _session.ensureFresh();
    final token = _session.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final retried = req.extra[_retriedKey] == true;
    if (err.response?.statusCode != 401 || retried) return handler.next(err);

    final result = await _session.refresh();
    if (result != RefreshResult.ok) return handler.next(err);

    try {
      req.extra[_retriedKey] = true;
      req.headers['Authorization'] = 'Bearer ${_session.accessToken}';
      handler.resolve(await _dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
