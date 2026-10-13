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
    bool? isActive,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/customers',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'searchTerm': search,
        'customerType': customerType,
        'isActive': isActive,
      }),
    );
    return Paged.fromJson(res.data!, Customer.fromJson);
  });

  Future<Customer> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/customers/$id');
    return Customer.fromJson(res.data!);
  });

  /// Tạo khách hàng; trả về id. Lỗi 400 kèm `fieldErrors` theo trường (CIF trùng, email sai…).
  Future<String> create({
    required String customerType,
    required String cif,
    required String fullName,
    required String identityNumber,
    required String email,
    required String phone,
    String? address,
    String? businessRegistrationNumber,
    String? representativeName,
    String? representativeTitle,
  }) => apiCall(() async {
    String? blank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/customers',
      data: {
        'customerType': customerType,
        'cif': cif.trim(),
        'fullName': fullName.trim(),
        'identityNumber': identityNumber.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'address': blank(address),
        'businessRegistrationNumber': blank(businessRegistrationNumber),
        'representativeName': blank(representativeName),
        'representativeTitle': blank(representativeTitle),
      },
    );
    return res.data!['id'] as String;
  });
}
