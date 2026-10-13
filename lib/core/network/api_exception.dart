import 'package:dio/dio.dart';

/// Lỗi từ API (RFC 7807 `ProblemDetails`) hoặc lỗi kết nối, đã chuẩn hoá để UI hiển thị.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.message,
    this.fieldErrors = const {},
    this.traceId,
  });

  /// Chuyển lỗi của Dio thành [ApiException]; không bao giờ đưa URL/token vào thông điệp.
  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      final timeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      return ApiException(
        status: 0,
        message: timeout
            ? 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.'
            : 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }

    final status = res.statusCode ?? 0;
    final data = res.data;
    String? title;
    String? traceId;
    final fields = <String, String>{};
    if (data is Map<String, dynamic>) {
      title = data['title'] as String?;
      traceId = data['traceId'] as String?;
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        errors.forEach((k, v) {
          if (v is List && v.isNotEmpty) {
            fields[_lowerFirst(k)] = v.first.toString();
          }
        });
      }
    }
    return ApiException(
      status: status,
      message: title ?? _fallback(status),
      fieldErrors: fields,
      traceId: traceId,
    );
  }

  final int status;
  final String message;
  final Map<String, String> fieldErrors;
  final String? traceId;

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static String _fallback(int status) => switch (status) {
    401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu.',
    409 => 'Dữ liệu vừa được thay đổi. Vui lòng tải lại.',
    429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít giây.',
    >= 500 => 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
    _ => 'Có lỗi xảy ra (mã $status).',
  };

  @override
  String toString() => 'ApiException($status): $message';
}
