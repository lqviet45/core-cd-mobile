import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/ui/money_field.dart';
import '../../../core/utils/format.dart';
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

  Future<EarlyRedemptionPreview> previewEarly(
    String id, {
    required DateTime date,
    required Decimal demandRate,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/certificates/$id/preview-early-redemption',
      queryParameters: {
        'redemptionDate': formatIsoDate(date),
        'demandRate': jsonNum(demandRate),
      },
    );
    return EarlyRedemptionPreview.fromJson(res.data!);
  });

  Future<void> redeemEarly(
    String id, {
    required DateTime date,
    required Decimal demandRate,
  }) => apiCall(
    () => _dio.post<void>(
      '/api/certificates/$id/redeem-early',
      data: {
        'redemptionDate': formatIsoDate(date),
        'demandRate': jsonNum(demandRate),
      },
    ),
  );

  Future<void> redeemAtMaturity(String id, {required DateTime date}) => apiCall(
    () => _dio.post<void>(
      '/api/certificates/$id/redeem-at-maturity',
      data: {'redemptionDate': formatIsoDate(date)},
    ),
  );

  /// Chi lãi một kỳ; số tiền do máy chủ tính theo lịch (không gửi lên).
  Future<void> payInterest(
    String id, {
    required DateTime paymentDate,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) => apiCall(
    () => _dio.post<void>(
      '/api/certificates/$id/pay-interest',
      data: {
        'paymentDate': formatIsoDate(paymentDate),
        'periodStart': formatIsoDate(periodStart),
        'periodEnd': formatIsoDate(periodEnd),
      },
    ),
  );
}
