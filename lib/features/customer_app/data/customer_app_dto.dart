import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'customer_app_dto.g.dart';

/// Hồ sơ của chính khách hàng (CCCD/MST và số điện thoại đã che từ API).
@JsonSerializable(createToJson: false)
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.cif,
    required this.fullName,
    required this.customerType,
    required this.identityNumberMasked,
    required this.email,
    required this.phoneMasked,
    this.address,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      _$CustomerProfileFromJson(json);

  final String id;
  final String cif;
  final String fullName;
  final String customerType;
  final String identityNumberMasked;
  final String email;
  final String phoneMasked;
  final String? address;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@NullableUtcDateConverter()
class CustomerSummary {
  const CustomerSummary({
    required this.holdingCount,
    required this.totalPrincipal,
    required this.estimatedInterestTotal,
    required this.interestReceivedTotal,
    this.nextMaturityDate,
    this.nextMaturityCertificateId,
    this.nextMaturityCertificateNumber,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) =>
      _$CustomerSummaryFromJson(json);

  final int holdingCount;
  final Decimal totalPrincipal;
  final Decimal estimatedInterestTotal;
  final Decimal interestReceivedTotal;
  final DateTime? nextMaturityDate;
  final String? nextMaturityCertificateId;
  final String? nextMaturityCertificateNumber;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class CustInterestPayment {
  const CustInterestPayment({
    required this.paymentDate,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
  });

  factory CustInterestPayment.fromJson(Map<String, dynamic> json) =>
      _$CustInterestPaymentFromJson(json);

  final DateTime paymentDate;
  final Decimal amount;
  final DateTime periodStart;
  final DateTime periodEnd;
}

/// CCTG của khách (dùng chung cho danh sách và chi tiết).
@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class CustCertificate {
  const CustCertificate({
    required this.id,
    required this.certificateNumber,
    required this.principal,
    required this.annualRatePercent,
    required this.termDays,
    required this.termName,
    required this.paymentMethod,
    required this.issueDate,
    required this.maturityDate,
    required this.status,
    required this.estimatedInterest,
    required this.totalInterestPaid,
    this.redemptionDate,
    this.netAmountAtRedemption,
    this.interestPayments = const [],
  });

  factory CustCertificate.fromJson(Map<String, dynamic> json) =>
      _$CustCertificateFromJson(json);

  final String id;
  final String certificateNumber;
  final Decimal principal;
  final Decimal annualRatePercent;
  final int termDays;
  final String termName;
  final String paymentMethod;
  final DateTime issueDate;
  final DateTime maturityDate;
  final String status;
  final Decimal estimatedInterest;
  final Decimal totalInterestPaid;
  @NullableUtcDateConverter()
  final DateTime? redemptionDate;
  @NullableDecimalConverter()
  final Decimal? netAmountAtRedemption;
  @JsonKey(defaultValue: <CustInterestPayment>[])
  final List<CustInterestPayment> interestPayments;

  /// Đang nắm giữ (chưa tất toán/huỷ) – khớp `CurrentCustomer.HoldingStatuses` ở backend.
  bool get isHolding =>
      status == 'Active' || status == 'NearMaturity' || status == 'Matured';
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class CustInterestPeriod {
  const CustInterestPeriod({
    required this.index,
    required this.total,
    required this.start,
    required this.end,
    required this.days,
    required this.amount,
    required this.status,
    this.paidDate,
  });

  factory CustInterestPeriod.fromJson(Map<String, dynamic> json) =>
      _$CustInterestPeriodFromJson(json);

  final int index;
  final int total;
  final DateTime start;
  final DateTime end;
  final int days;
  final Decimal amount;

  /// `Paid | Upcoming | Due`.
  final String status;
  @NullableUtcDateConverter()
  final DateTime? paidDate;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class CustInterestSchedule {
  const CustInterestSchedule({
    required this.certificateId,
    required this.certificateNumber,
    required this.paymentMethod,
    required this.contractInterest,
    required this.paidTotal,
    required this.periods,
  });

  factory CustInterestSchedule.fromJson(Map<String, dynamic> json) =>
      _$CustInterestScheduleFromJson(json);

  final String certificateId;
  final String certificateNumber;
  final String paymentMethod;
  final Decimal contractInterest;
  final Decimal paidTotal;
  final List<CustInterestPeriod> periods;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class CustTransaction {
  const CustTransaction({
    required this.id,
    required this.trxNo,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.hasContract,
    this.updatedAt,
    this.contractCode,
  });

  factory CustTransaction.fromJson(Map<String, dynamic> json) =>
      _$CustTransactionFromJson(json);

  final String id;
  final String trxNo;
  final String type;
  final Decimal amount;
  final String status;
  @UtcDateConverter()
  final DateTime createdAt;
  @NullableUtcDateConverter()
  final DateTime? updatedAt;
  final String? contractCode;
  final bool hasContract;
}

@JsonSerializable(createToJson: false)
@UtcDateConverter()
class CustDocument {
  const CustDocument({
    required this.id,
    required this.kind,
    required this.version,
    required this.fileName,
    required this.size,
    required this.createdAt,
  });

  factory CustDocument.fromJson(Map<String, dynamic> json) =>
      _$CustDocumentFromJson(json);

  final String id;

  /// `TradeContract | SignedContract | CertificatePdf`.
  final String kind;
  final int version;
  final String fileName;
  final int size;
  final DateTime createdAt;
}

@JsonSerializable(createToJson: false)
class OtpRequested {
  const OtpRequested({
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  factory OtpRequested.fromJson(Map<String, dynamic> json) =>
      _$OtpRequestedFromJson(json);

  final int expiresInSeconds;
  final int resendAfterSeconds;
}
