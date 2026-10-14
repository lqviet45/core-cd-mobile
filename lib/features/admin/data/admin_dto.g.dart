// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminUser _$AdminUserFromJson(Map<String, dynamic> json) => AdminUser(
  id: json['id'] as String,
  username: json['username'] as String,
  fullName: json['fullName'] as String,
  role: json['role'] as String,
  isActive: json['isActive'] as bool,
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  lastLoginAt: _$JsonConverterFromJson<String, DateTime>(
    json['lastLoginAt'],
    const UtcDateConverter().fromJson,
  ),
);

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

AuditLogEntry _$AuditLogEntryFromJson(Map<String, dynamic> json) =>
    AuditLogEntry(
      id: json['id'] as String,
      userName: json['userName'] as String,
      action: json['action'] as String,
      createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
      role: json['role'] as String?,
      payload: json['payload'] as String?,
      ipAddress: json['ipAddress'] as String?,
      traceId: json['traceId'] as String?,
    );

RatePolicy _$RatePolicyFromJson(Map<String, dynamic> json) => RatePolicy(
  id: json['id'] as String,
  termName: json['termName'] as String,
  termDays: (json['termDays'] as num).toInt(),
  annualRatePercent: const DecimalConverter().fromJson(
    json['annualRatePercent'],
  ),
  paymentMethod: json['paymentMethod'] as String,
  isActive: json['isActive'] as bool,
  effectiveFrom: const UtcDateConverter().fromJson(
    json['effectiveFrom'] as String,
  ),
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  effectiveTo: _$JsonConverterFromJson<String, DateTime>(
    json['effectiveTo'],
    const UtcDateConverter().fromJson,
  ),
  description: json['description'] as String?,
);
