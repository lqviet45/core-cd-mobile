import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import 'lot_dto.dart';

class LotRepository {
  LotRepository(this._dio);
  final Dio _dio;

  /// Không phân trang (số đợt phát hành đang mở nhỏ).
  Future<List<Lot>> list({String? status}) => apiCall(() async {
    final res = await _dio.get<List<dynamic>>(
      '/api/cdlots',
      queryParameters: cleanQuery({'status': status}),
    );
    return res.data!
        .map((e) => Lot.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<LotSummary> summary() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/cdlots/summary');
    return LotSummary.fromJson(res.data!);
  });

  Future<Lot> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/cdlots/$id');
    return Lot.fromJson(res.data!);
  });

  Future<LotStats> stats(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/cdlots/$id/stats');
    return LotStats.fromJson(res.data!);
  });
}
