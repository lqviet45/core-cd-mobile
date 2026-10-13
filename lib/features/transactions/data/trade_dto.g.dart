// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrxCreated _$TrxCreatedFromJson(Map<String, dynamic> json) => TrxCreated(
  transactionId: json['transactionId'] as String,
  trxNo: json['trxNo'] as String,
  status: json['status'] as String,
);

SellPreviewItem _$SellPreviewItemFromJson(Map<String, dynamic> json) =>
    SellPreviewItem(
      certificateId: json['certificateId'] as String,
      certificateNumber: json['certificateNumber'] as String,
      maturityDate: const UtcDateConverter().fromJson(
        json['maturityDate'] as String,
      ),
      principal: const DecimalConverter().fromJson(json['principal']),
      redemptionType: json['redemptionType'] as String,
      interest: const DecimalConverter().fromJson(json['interest']),
      interestAlreadyPaid: const DecimalConverter().fromJson(
        json['interestAlreadyPaid'],
      ),
      lostInterest: const DecimalConverter().fromJson(json['lostInterest']),
      netAmount: const DecimalConverter().fromJson(json['netAmount']),
      fee: const DecimalConverter().fromJson(json['fee']),
    );

SellPreview _$SellPreviewFromJson(Map<String, dynamic> json) => SellPreview(
  eligibleCount: (json['eligibleCount'] as num).toInt(),
  eligibleTotalPrincipal: const DecimalConverter().fromJson(
    json['eligibleTotalPrincipal'],
  ),
  items: (json['items'] as List<dynamic>)
      .map((e) => SellPreviewItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalPrincipal: const DecimalConverter().fromJson(json['totalPrincipal']),
  totalInterest: const DecimalConverter().fromJson(json['totalInterest']),
  totalInterestAlreadyPaid: const DecimalConverter().fromJson(
    json['totalInterestAlreadyPaid'],
  ),
  totalLostInterest: const DecimalConverter().fromJson(
    json['totalLostInterest'],
  ),
  totalFee: const DecimalConverter().fromJson(json['totalFee']),
  totalNetAmount: const DecimalConverter().fromJson(json['totalNetAmount']),
  earlyCount: (json['earlyCount'] as num).toInt(),
  issues: (json['issues'] as List<dynamic>).map((e) => e as String).toList(),
  canSubmit: json['canSubmit'] as bool,
);
