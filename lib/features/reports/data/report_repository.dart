import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import 'report_dto.dart';

class ReportRepository {
  ReportRepository(this._dio);
  final Dio _dio;

  Future<PortfolioReport> portfolio() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/reports/portfolio');
    return PortfolioReport.fromJson(res.data!);
  });

  Future<UpcomingReport> upcoming({int daysAhead = 30}) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/reports/upcoming-maturities',
      queryParameters: {'daysAhead': daysAhead},
    );
    return UpcomingReport.fromJson(res.data!);
  });

  Future<LiquidityReport> liquidity({
    required DateTime from,
    required DateTime to,
    String groupBy = 'Month',
  }) => apiCall(() async {
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/reports/liquidity',
      queryParameters: {
        'dateFrom': d(from),
        'dateTo': d(to),
        'groupBy': groupBy,
      },
    );
    return LiquidityReport.fromJson(res.data!);
  });
}
