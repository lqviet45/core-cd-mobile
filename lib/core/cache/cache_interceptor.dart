import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'encrypted_cache.dart';

/// Lưu mọi phản hồi GET thành công (mã hoá, theo từng người dùng) và, khi **mất kết nối**, trả lại bản đã lưu để
/// các màn chỉ-đọc vẫn xem được. Chỉ lỗi mạng/quá thời gian mới dùng bản đệm: 4xx/5xx từ máy chủ luôn được báo
/// đúng như thực tế. Lệnh ghi (POST/PUT/DELETE) không bao giờ được đệm hay phục vụ từ đệm.
class CacheInterceptor extends Interceptor {
  CacheInterceptor(
    this._cache, {
    required this.userId,
    this.onServedFromCache,
    this.onLive,
    this.maxAge = const Duration(days: 7),
  });

  final EncryptedCache _cache;

  /// Người dùng hiện tại (null = chưa đăng nhập → không đệm).
  final String? Function() userId;

  /// Báo cho UI biết đang hiển thị dữ liệu lưu lúc nào / đã có phản hồi trực tiếp.
  final void Function(DateTime savedAt)? onServedFromCache;
  final void Function()? onLive;
  final Duration maxAge;

  static const fromCacheKey = 'fromCache';

  String? _key(RequestOptions o) {
    final u = userId();
    if (u == null || o.method.toUpperCase() != 'GET') return null;
    return '$u|${o.uri}';
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final key = _key(response.requestOptions);
    final data = response.data;
    if (key != null &&
        response.statusCode == 200 &&
        (data is Map || data is List)) {
      // Đệm chạy nền: lỗi ghi đệm không được làm hỏng một phản hồi hợp lệ.
      unawaited(_cache.write(key, jsonEncode(data)).catchError((Object _) {}));
    }
    if (response.requestOptions.extra[fromCacheKey] != true) onLive?.call();
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final key = _key(err.requestOptions);
    final offline =
        err.response == null &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.unknown);
    if (key == null || !offline) return handler.next(err);

    final hit = await _cache.read(key, maxAge: maxAge);
    if (hit == null) return handler.next(err);
    onServedFromCache?.call(hit.savedAt);
    handler.resolve(
      Response<dynamic>(
        requestOptions: err.requestOptions,
        statusCode: 200,
        data: jsonDecode(hit.body),
        extra: {fromCacheKey: true, 'cachedAt': hit.savedAt},
      ),
    );
  }
}
