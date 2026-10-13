import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'certificate_dto.g.dart';

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class InterestPayment {
  const InterestPayment({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
  });

  factory InterestPayment.fromJson(Map<String, dynamic> json) =>
      _$InterestPaymentFromJson(json);

  final String id;
  final DateTime paymentDate;
  final Decimal amount;
  final DateTime periodStart;
  final DateTime periodEnd;
}

/// CCTG – dùng chung cho danh sách và chi tiết (danh sách có `interestPayments` rỗng).
@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class Certificate {
  const Certificate({
    required this.id,
    required this.certificateNumber,
    required this.lotId,
    required this.lotCode,
    required this.customerId,
    required this.customerName,
    required this.customerIdentityNumber,
    required this.principal,
    required this.annualRatePercent,
    required this.termDays,
    required this.termName,
    required this.paymentMethod,
    required this.issueDate,
    required this.maturityDate,
    required this.status,
    required this.estimatedInterest,
    required this.holdAmount,
    required this.createdAt,
    this.totalInterestPaid,
    this.penaltyAmount,
    this.netAmountAtRedemption,
    this.earlyRedemptionFee,
    this.redemptionDate,
    this.notes,
    this.interestPayments = const [],
  });

  factory Certificate.fromJson(Map<String, dynamic> json) =>
      _$CertificateFromJson(json);

  final String id;
  final String certificateNumber;
  final String lotId;
  final String lotCode;
  final String customerId;
  final String customerName;

  /// Backend đã che (`072•••••9999`).
  final String customerIdentityNumber;
  final Decimal principal;
  final Decimal annualRatePercent;
  final int termDays;
  final String termName;

  /// `AtMaturity | Monthly | Quarterly` – tên hiển thị tự dịch ở `labels.dart`.
  final String paymentMethod;
  final DateTime issueDate;
  final DateTime maturityDate;
  final String status;
  final Decimal estimatedInterest;
  final Decimal holdAmount;
  final DateTime createdAt;
  @NullableDecimalConverter()
  final Decimal? totalInterestPaid;
  @NullableDecimalConverter()
  final Decimal? penaltyAmount;
  @NullableDecimalConverter()
  final Decimal? netAmountAtRedemption;
  @NullableDecimalConverter()
  final Decimal? earlyRedemptionFee;
  @NullableUtcDateConverter()
  final DateTime? redemptionDate;
  final String? notes;
  @JsonKey(defaultValue: <InterestPayment>[])
  final List<InterestPayment> interestPayments;

  bool get isRedeemed =>
      status == 'RedeemedAtMaturity' || status == 'RedeemedEarly';
  bool get isOnHold => holdAmount > Decimal.zero;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class InterestPeriod {
  const InterestPeriod({
    required this.index,
    required this.total,
    required this.start,
    required this.end,
    required this.days,
    required this.amount,
    required this.status,
    this.paidDate,
  });

  factory InterestPeriod.fromJson(Map<String, dynamic> json) =>
      _$InterestPeriodFromJson(json);

  final int index;
  final int total;
  final DateTime start;
  final DateTime end;
  final int days;
  final Decimal amount;

  /// `Paid | Upcoming | Today | Overdue | Blocked`.
  final String status;
  @NullableUtcDateConverter()
  final DateTime? paidDate;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class InterestSchedule {
  const InterestSchedule({
    required this.certificateId,
    required this.method,
    required this.contractInterest,
    required this.paidTotal,
    required this.periods,
  });

  factory InterestSchedule.fromJson(Map<String, dynamic> json) =>
      _$InterestScheduleFromJson(json);

  final String certificateId;
  final String method;
  final Decimal contractInterest;
  final Decimal paidTotal;
  final List<InterestPeriod> periods;
}

/// Xem trước tất toán trước hạn (máy chủ tính). Lãi KKH ở dạng thập phân (0,001 = 0,1%/năm).
@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class EarlyRedemptionPreview {
  const EarlyRedemptionPreview({
    required this.certificateNumber,
    required this.principal,
    required this.actualDays,
    required this.demandRate,
    required this.interestEarned,
    required this.penaltyAmount,
    required this.netAmount,
    required this.redemptionDate,
    required this.fee,
    required this.feeEnabled,
    required this.feeRate,
    required this.feeWindowDays,
  });

  factory EarlyRedemptionPreview.fromJson(Map<String, dynamic> json) =>
      _$EarlyRedemptionPreviewFromJson(json);

  final String certificateNumber;
  final Decimal principal;
  final int actualDays;
  final Decimal demandRate;
  final Decimal interestEarned;

  /// Lãi cam kết khách hàng bị mất do tất toán sớm.
  final Decimal penaltyAmount;
  final Decimal netAmount;
  final DateTime redemptionDate;

  /// Phí tất toán sớm đã trừ vào [netAmount] (tính theo công thức tạm thời, mặc định tắt).
  final Decimal fee;
  final bool feeEnabled;
  final Decimal feeRate;
  final int feeWindowDays;
}
