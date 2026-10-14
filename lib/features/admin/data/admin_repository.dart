import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/ui/money_field.dart';
import 'admin_dto.dart';

class AdminRepository {
  AdminRepository(this._dio);
  final Dio _dio;

  // ── Người dùng ──────────────────────────────────────────────────────────────
  Future<Paged<AdminUser>> users({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? role,
    bool? isActive,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/users',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'searchTerm': search,
        'role': role,
        'isActive': isActive,
      }),
    );
    return Paged.fromJson(res.data!, AdminUser.fromJson);
  });

  Future<void> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) => apiCall(() async {
    await _dio.post<void>(
      '/api/users',
      data: {
        'username': username.trim(),
        'password': password,
        'fullName': fullName.trim(),
        'role': role,
      },
    );
  });

  Future<void> updateUser({
    required String id,
    required String fullName,
    required String role,
    required bool isActive,
  }) => apiCall(() async {
    await _dio.put<void>(
      '/api/users/$id',
      data: {
        'id': id,
        'fullName': fullName.trim(),
        'role': role,
        'isActive': isActive,
      },
    );
  });

  Future<void> resetPassword(String id, String newPassword) =>
      apiCall(() async {
        await _dio.post<void>(
          '/api/users/$id/reset-password',
          data: {'newPassword': newPassword},
        );
      });

  // ── Nhật ký ─────────────────────────────────────────────────────────────────
  Future<Paged<AuditLogEntry>> auditLogs({
    int page = 1,
    int pageSize = 30,
    String? userName,
    DateTime? from,
    DateTime? to,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/audit-logs',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'userName': userName,
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
      }),
    );
    return Paged.fromJson(res.data!, AuditLogEntry.fromJson);
  });

  // ── Chính sách lãi suất ─────────────────────────────────────────────────────
  Future<Paged<RatePolicy>> ratePolicies({
    int page = 1,
    int pageSize = 30,
    bool? isActive,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/interest-rate-policies',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'isActive': isActive,
      }),
    );
    return Paged.fromJson(res.data!, RatePolicy.fromJson);
  });

  /// Lãi suất nhập theo %, gửi lên dạng phần trăm/100 (0,055 = 5,5%/năm).
  static num rateFraction(Decimal percent) => jsonNum(
    (percent / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 8),
  );

  Future<void> createRate({
    required String termName,
    required int termDays,
    required Decimal annualRatePercent,
    required String paymentMethod,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? description,
  }) => apiCall(() async {
    await _dio.post<void>(
      '/api/interest-rate-policies',
      data: _rateBody(
        termName: termName,
        termDays: termDays,
        annualRatePercent: annualRatePercent,
        paymentMethod: paymentMethod,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        description: description,
      ),
    );
  });

  Future<void> updateRate({
    required String id,
    required String termName,
    required int termDays,
    required Decimal annualRatePercent,
    required String paymentMethod,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? description,
  }) => apiCall(() async {
    await _dio.put<void>(
      '/api/interest-rate-policies/$id',
      data: {
        'id': id,
        ..._rateBody(
          termName: termName,
          termDays: termDays,
          annualRatePercent: annualRatePercent,
          paymentMethod: paymentMethod,
          effectiveFrom: effectiveFrom,
          effectiveTo: effectiveTo,
          description: description,
        ),
      },
    );
  });

  /// Ngừng áp dụng (backend xoá mềm).
  Future<void> deactivateRate(String id) => apiCall(() async {
    await _dio.delete<void>('/api/interest-rate-policies/$id');
  });

  static Map<String, Object?> _rateBody({
    required String termName,
    required int termDays,
    required Decimal annualRatePercent,
    required String paymentMethod,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? description,
  }) {
    String? blank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    String day(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).toIso8601String();
    return {
      'termName': termName.trim(),
      'termDays': termDays,
      'annualRate': rateFraction(annualRatePercent),
      'paymentMethod': paymentMethod,
      'effectiveFrom': day(effectiveFrom),
      'effectiveTo': effectiveTo == null ? null : day(effectiveTo),
      'description': blank(description),
    };
  }
}
