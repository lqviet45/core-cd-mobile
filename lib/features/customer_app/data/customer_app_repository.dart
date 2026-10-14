import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_exception.dart';
import 'customer_app_dto.dart';

/// Link tải ngắn hạn do API cấp (không log, không lưu).
class CustDownloadLink {
  const CustDownloadLink({required this.url, required this.fileName});
  final String url;
  final String fileName;
}

/// API `/api/customer/*`: chỉ đọc, chỉ dữ liệu của chính khách đang đăng nhập (máy chủ xác định từ token).
class CustomerAppRepository {
  CustomerAppRepository(this._dio);
  final Dio _dio;

  Future<CustomerProfile> me() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/customer/me');
    return CustomerProfile.fromJson(res.data!);
  });

  Future<CustomerSummary> summary() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/customer/summary');
    return CustomerSummary.fromJson(res.data!);
  });

  /// [scope]: `All | Holding | Closed`.
  Future<Paged<CustCertificate>> certificates({
    String scope = 'All',
    int page = 1,
    int pageSize = 20,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customer/certificates',
      queryParameters: {
        'scope': scope,
        'pageNumber': page,
        'pageSize': pageSize,
      },
    );
    return Paged.fromJson(res.data!, CustCertificate.fromJson);
  });

  Future<CustCertificate> certificate(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customer/certificates/$id',
    );
    return CustCertificate.fromJson(res.data!);
  });

  Future<CustInterestSchedule> interestSchedule(String certificateId) =>
      apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/customer/certificates/$certificateId/interest-schedule',
        );
        return CustInterestSchedule.fromJson(res.data!);
      });

  Future<Paged<CustTransaction>> transactions({
    int page = 1,
    int pageSize = 20,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customer/transactions',
      queryParameters: {'pageNumber': page, 'pageSize': pageSize},
    );
    return Paged.fromJson(res.data!, CustTransaction.fromJson);
  });

  Future<CustTransaction> transaction(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customer/transactions/$id',
    );
    return CustTransaction.fromJson(res.data!);
  });

  /// [ownerType]: `certificates | transactions`.
  Future<List<CustDocument>> documents(String ownerType, String ownerId) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '/api/customer/$ownerType/$ownerId/documents',
        );
        return res.data!
            .map((e) => CustDocument.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<CustDownloadLink> downloadLink(String documentId) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/customer/documents/$documentId/download-link',
    );
    final j = res.data!;
    return CustDownloadLink(
      url: j['url'] as String,
      fileName: j['fileName'] as String,
    );
  });
}

/// Lỗi OTP hiển thị cho người dùng (429 = quá nhiều lần thử trên cùng địa chỉ).
String otpErrorMessage(ApiException e) => switch (e.status) {
  429 => 'Bạn thao tác quá nhanh. Vui lòng chờ một phút rồi thử lại.',
  400 => e.fieldErrors.values.firstOrNull ?? e.message,
  _ => e.message,
};
