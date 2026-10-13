import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import 'certificate_dto.dart';

class CertificateRepository {
  CertificateRepository(this._dio);
  final Dio _dio;

  Future<Paged<Certificate>> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String? customerId,
    String? lotId,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/certificates',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'status': status,
        'searchTerm': search,
        'customerId': customerId,
        'lotId': lotId,
      }),
    );
    return Paged.fromJson(res.data!, Certificate.fromJson);
  });

  Future<Certificate> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/certificates/$id');
    return Certificate.fromJson(res.data!);
  });

  Future<InterestSchedule> schedule(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/certificates/$id/interest-schedule',
    );
    return InterestSchedule.fromJson(res.data!);
  });
}
