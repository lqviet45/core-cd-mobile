import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/utils/format.dart';
import 'interest_dto.dart';

class InterestRepository {
  InterestRepository(this._dio);
  final Dio _dio;

  Future<InterestSummary> summary() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/settlement/interest/summary',
    );
    return InterestSummary.fromJson(res.data!);
  });

  /// [bucket]: `due` (đến hạn) · `overdue` (quá hạn) · `paid` (đã chi).
  Future<Paged<InterestDueItem>> due({
    required String bucket,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/settlement/interest/due',
      queryParameters: cleanQuery({
        'bucket': bucket,
        'pageNumber': page,
        'pageSize': pageSize,
      }),
    );
    return Paged.fromJson(res.data!, InterestDueItem.fromJson);
  });

  /// Chi nhiều kỳ một lần. Số tiền do máy chủ tính theo lịch nên không gửi lên; kỳ đã chi hoặc không khớp lịch
  /// được báo lại từng dòng (gửi lặp không chi hai lần).
  Future<BulkResult> bulkPay(List<InterestDueItem> items) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/settlement/interest/bulk-pay',
      data: {
        'items': [
          for (final i in items)
            {
              'certificateId': i.certificateId,
              'periodStart': formatIsoDate(i.periodStart),
              'periodEnd': formatIsoDate(i.periodEnd),
            },
        ],
      },
    );
    return BulkResult.fromJson(res.data!);
  });
}
