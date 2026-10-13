import 'package:dio/dio.dart';

import '../auth/session_manager.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// Dio **trần** (không xác thực) cho đăng nhập/làm mới/đăng xuất.
Dio createBareDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: config.requestTimeout,
    receiveTimeout: config.requestTimeout,
    sendTimeout: config.requestTimeout,
    headers: {'Accept': 'application/json'},
  ),
);

/// Dio dùng cho mọi API nghiệp vụ: tự gắn token và làm mới khi cần.
Dio createAuthedDio(AppConfig config, SessionManager session) {
  final dio = createBareDio(config);
  dio.interceptors.add(AuthInterceptor(session, dio));
  return dio;
}
