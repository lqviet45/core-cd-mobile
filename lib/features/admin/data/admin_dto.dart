import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'admin_dto.g.dart';

/// Tài khoản nhân viên (`GET /api/users`, chỉ Admin).
@JsonSerializable(createToJson: false)
@UtcDateConverter()
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });
  factory AdminUser.fromJson(Map<String, dynamic> json) =>
      _$AdminUserFromJson(json);

  final String id;
  final String username;
  final String fullName;

  /// `Viewer | Operator | Admin`.
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
}

/// Nhật ký thao tác (`GET /api/audit-logs`, chỉ Admin). `payload` đã được backend che dữ liệu nhạy cảm.
@JsonSerializable(createToJson: false)
@UtcDateConverter()
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.userName,
    required this.action,
    required this.createdAt,
    this.role,
    this.payload,
    this.ipAddress,
    this.traceId,
  });
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) =>
      _$AuditLogEntryFromJson(json);

  final String id;
  final String userName;
  final String? role;

  /// Tên lệnh nghiệp vụ (vd `BuyCertificate`).
  final String action;
  final String? payload;
  final String? ipAddress;
  final String? traceId;
  final DateTime createdAt;
}

/// Chính sách lãi suất theo kỳ hạn (`GET /api/interest-rate-policies`).
@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class RatePolicy {
  const RatePolicy({
    required this.id,
    required this.termName,
    required this.termDays,
    required this.annualRatePercent,
    required this.paymentMethod,
    required this.isActive,
    required this.effectiveFrom,
    required this.createdAt,
    this.effectiveTo,
    this.description,
  });
  factory RatePolicy.fromJson(Map<String, dynamic> json) =>
      _$RatePolicyFromJson(json);

  final String id;
  final String termName;
  final int termDays;

  /// Lãi suất năm theo phần trăm (4,0 = 4%/năm).
  final Decimal annualRatePercent;

  /// `AtMaturity | Monthly | Quarterly`.
  final String paymentMethod;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? description;
  final DateTime createdAt;
}
