import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../dashboard/data/dashboard_dto.dart';

class TransactionRepository {
  TransactionRepository(this._dio);
  final Dio _dio;

  Future<Paged<Transaction>> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? cif,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/transactions',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'status': status,
        'cif': cif,
      }),
    );
    return Paged.fromJson(res.data!, Transaction.fromJson);
  });
}
