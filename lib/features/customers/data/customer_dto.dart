import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'customer_dto.g.dart';

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class Customer {
  const Customer({
    required this.id,
    required this.cif,
    required this.customerType,
    required this.fullName,
    required this.identityNumber,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.createdAt,
    required this.totalCertificates,
    required this.outstandingPrincipal,
    this.address,
    this.businessRegistrationNumber,
    this.representativeName,
    this.representativeTitle,
  });

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  final String id;
  final String cif;

  /// `Individual | Business`.
  final String customerType;
  final String fullName;

  /// Đã che (`070•••••9999`); xem đầy đủ là hành động có ghi nhật ký, thuộc mốc sau.
  final String identityNumber;
  final String email;
  final String phone;
  final bool isActive;
  final DateTime createdAt;
  final int totalCertificates;
  final Decimal outstandingPrincipal;
  final String? address;
  final String? businessRegistrationNumber;
  final String? representativeName;
  final String? representativeTitle;

  bool get isBusiness => customerType == 'Business';
}
