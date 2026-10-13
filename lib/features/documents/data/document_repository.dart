import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_exception.dart';
import 'document_dto.dart';

class DocumentRepository {
  /// [storage]: Dio **trần** (không gắn token, không baseUrl) để PUT/GET tới URL ngắn hạn của kho tệp. Tuyệt đối
  /// không dùng Dio nghiệp vụ cho việc này: sẽ rò token truy cập sang máy chủ kho tệp.
  DocumentRepository(this._dio, {Dio? storage}) : _storage = storage ?? Dio();
  final Dio _dio;
  final Dio _storage;

  Future<List<DocumentItem>> list(String ownerType, String ownerId) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '/api/documents',
          queryParameters: {'ownerType': ownerType, 'ownerId': ownerId},
        );
        return res.data!
            .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Sinh tài liệu do hệ thống tạo (hợp đồng/chứng chỉ). Idempotent: đã có thì trả bản hiện có.
  Future<DocumentItem> generate(String path) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(path);
    return DocumentItem.fromJson(res.data!);
  });

  Future<DownloadLink> downloadLink(String id) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/documents/$id/download-link',
    );
    return DownloadLink.fromJson(res.data!);
  });

  /// Tải nội dung về bộ nhớ (để chia sẻ). Dùng URL ngắn hạn, không kèm token.
  Future<List<int>> fetchBytes(String url) async {
    try {
      final res = await _storage.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// 1) xin URL PUT ngắn hạn  2) tải thẳng lên kho  3) xác nhận để API kiểm tra nội dung.
  Future<DocumentItem> upload({
    required String kind,
    required String ownerId,
    required UploadFile file,
  }) async {
    final req = await apiCall(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/documents/uploads',
        data: {
          'kind': kind,
          'ownerId': ownerId,
          'fileName': file.name,
          'contentType': file.contentType,
          'size': file.bytes.length,
        },
      );
      return UploadRequest.fromJson(res.data!);
    });
    if (file.bytes.length > req.maxBytes) {
      throw const ApiException(
        status: 413,
        message: 'Tệp quá lớn so với giới hạn của hệ thống.',
      );
    }
    try {
      await _storage.put<void>(
        req.uploadUrl,
        data: Stream.fromIterable([file.bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: req.contentType,
            Headers.contentLengthHeader: file.bytes.length,
          },
        ),
      );
    } on DioException {
      throw const ApiException(
        status: 0,
        message: 'Không tải được tệp lên kho tài liệu. Kiểm tra kết nối rồi thử lại.',
      );
    }
    return await apiCall(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/documents/${req.documentId}/confirm',
      );
      return DocumentItem.fromJson(res.data!);
    });
  }
}
