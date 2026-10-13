import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import 'customer_dto.dart';

class CustomerRepository {
  CustomerRepository(this._dio);
  final Dio _dio;

  Future<Paged<Customer>> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? customerType,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customers',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'searchTerm': search,
        'customerType': customerType,
      }),
    );
    return Paged.fromJson(res.data!, Customer.fromJson);
  });

  Future<Customer> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/customers/$id');
    return Customer.fromJson(res.data!);
  });
}
