// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterestPayment _$InterestPaymentFromJson(
  Map<String, dynamic> json,
) => InterestPayment(
  id: json['id'] as String,
  paymentDate: const UtcDateConverter().fromJson(json['paymentDate'] as String),
  amount: const DecimalConverter().fromJson(json['amount']),
  periodStart: const UtcDateConverter().fromJson(json['periodStart'] as String),
  periodEnd: const UtcDateConverter().fromJson(json['periodEnd'] as String),
);

Certificate _$CertificateFromJson(Map<String, dynamic> json) => Certificate(
  id: json['id'] as String,
  certificateNumber: json['certificateNumber'] as String,
  lotId: json['lotId'] as String,
  lotCode: json['lotCode'] as String,
  customerId: json['customerId'] as String,
  customerName: json['customerName'] as String,
  customerIdentityNumber: json['customerIdentityNumber'] as String,
  principal: const DecimalConverter().fromJson(json['principal']),
  annualRatePercent: const DecimalConverter().fromJson(
    json['annualRatePercent'],
  ),
  termDays: (json['termDays'] as num).toInt(),
  termName: json['termName'] as String,
  paymentMethod: json['paymentMethod'] as String,
  issueDate: const UtcDateConverter().fromJson(json['issueDate'] as String),
  maturityDate: const UtcDateConverter().fromJson(
    json['maturityDate'] as String,
  ),
  status: json['status'] as String,
  estimatedInterest: const DecimalConverter().fromJson(
    json['estimatedInterest'],
  ),
  holdAmount: const DecimalConverter().fromJson(json['holdAmount']),
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  totalInterestPaid: const NullableDecimalConverter().fromJson(
    json['totalInterestPaid'],
  ),
  penaltyAmount: const NullableDecimalConverter().fromJson(
    json['penaltyAmount'],
  ),
  netAmountAtRedemption: const NullableDecimalConverter().fromJson(
    json['netAmountAtRedemption'],
  ),
  earlyRedemptionFee: const NullableDecimalConverter().fromJson(
    json['earlyRedemptionFee'],
  ),
  redemptionDate: const NullableUtcDateConverter().fromJson(
    json['redemptionDate'] as String?,
  ),
  notes: json['notes'] as String?,
  interestPayments:
      (json['interestPayments'] as List<dynamic>?)
          ?.map((e) => InterestPayment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

InterestPeriod _$InterestPeriodFromJson(Map<String, dynamic> json) =>
    InterestPeriod(
      index: (json['index'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      start: const UtcDateConverter().fromJson(json['start'] as String),
      end: const UtcDateConverter().fromJson(json['end'] as String),
      days: (json['days'] as num).toInt(),
      amount: const DecimalConverter().fromJson(json['amount']),
      status: json['status'] as String,
      paidDate: const NullableUtcDateConverter().fromJson(
        json['paidDate'] as String?,
      ),
    );

InterestSchedule _$InterestScheduleFromJson(Map<String, dynamic> json) =>
    InterestSchedule(
      certificateId: json['certificateId'] as String,
      method: json['method'] as String,
      contractInterest: const DecimalConverter().fromJson(
        json['contractInterest'],
      ),
      paidTotal: const DecimalConverter().fromJson(json['paidTotal']),
      periods: (json['periods'] as List<dynamic>)
          .map((e) => InterestPeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
