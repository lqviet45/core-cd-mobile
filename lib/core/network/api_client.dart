import 'package:dio/dio.dart';

import '../auth/session_manager.dart';
import '../cache/cache_interceptor.dart';
import '../cache/encrypted_cache.dart';
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
///
/// Có [cache] thì mọi GET thành công được đệm mã hoá và, khi mất mạng, trả lại bản đã lưu (xem [CacheInterceptor]).
Dio createAuthedDio(
  AppConfig config,
  SessionManager session, {
  EncryptedCache? cache,
  void Function(DateTime savedAt)? onServedFromCache,
  void Function()? onLive,
}) {
  final dio = createBareDio(config);
  dio.interceptors.add(AuthInterceptor(session, dio));
  if (cache != null) {
    dio.interceptors.add(
      CacheInterceptor(
        cache,
        userId: () => session.user?.id,
        onServedFromCache: onServedFromCache,
        onLive: onLive,
      ),
    );
  }
  return dio;
}
