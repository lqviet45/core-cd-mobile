// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  id: json['id'] as String,
  cif: json['cif'] as String,
  customerType: json['customerType'] as String,
  fullName: json['fullName'] as String,
  identityNumber: json['identityNumber'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String,
  isActive: json['isActive'] as bool,
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  totalCertificates: (json['totalCertificates'] as num).toInt(),
  outstandingPrincipal: const DecimalConverter().fromJson(
    json['outstandingPrincipal'],
  ),
  address: json['address'] as String?,
  businessRegistrationNumber: json['businessRegistrationNumber'] as String?,
  representativeName: json['representativeName'] as String?,
  representativeTitle: json['representativeTitle'] as String?,
);
