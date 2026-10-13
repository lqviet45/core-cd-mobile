import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import 'dashboard_dto.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<Dashboard> summary() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/dashboard/summary');
    return Dashboard.fromJson(res.data!);
  });
}
