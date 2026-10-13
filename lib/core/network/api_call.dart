import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Chạy một lời gọi Dio và chuyển mọi [DioException] thành [ApiException] để lớp trên chỉ xử lý một loại lỗi.
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}

/// Bỏ tham số rỗng/null khỏi query string.
Map<String, Object> cleanQuery(Map<String, Object?> q) => {
  for (final e in q.entries)
    if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value!,
};
