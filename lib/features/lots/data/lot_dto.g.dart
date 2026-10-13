// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lot_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lot _$LotFromJson(Map<String, dynamic> json) => Lot(
  id: json['id'] as String,
  lotCode: json['lotCode'] as String,
  termName: json['termName'] as String,
  annualRatePct: const DecimalConverter().fromJson(json['annualRatePct']),
  paymentMethod: json['paymentMethod'] as String,
  totalFaceValue: const DecimalConverter().fromJson(json['totalFaceValue']),
  issuedFaceValue: const DecimalConverter().fromJson(json['issuedFaceValue']),
  remainingFaceValue: const DecimalConverter().fromJson(
    json['remainingFaceValue'],
  ),
  minPurchaseAmount: const DecimalConverter().fromJson(
    json['minPurchaseAmount'],
  ),
  issueDate: const UtcDateConverter().fromJson(json['issueDate'] as String),
  maturityDate: const UtcDateConverter().fromJson(
    json['maturityDate'] as String,
  ),
  status: json['status'] as String,
  certificateCount: (json['certificateCount'] as num).toInt(),
  description: json['description'] as String?,
);

LotSummary _$LotSummaryFromJson(Map<String, dynamic> json) => LotSummary(
  openTotalFaceValue: const DecimalConverter().fromJson(
    json['openTotalFaceValue'],
  ),
  openIssuedFaceValue: const DecimalConverter().fromJson(
    json['openIssuedFaceValue'],
  ),
  openRemainingFaceValue: const DecimalConverter().fromJson(
    json['openRemainingFaceValue'],
  ),
  nearlySoldOutCount: (json['nearlySoldOutCount'] as num).toInt(),
  totalCount: (json['totalCount'] as num).toInt(),
);

DailyIssued _$DailyIssuedFromJson(Map<String, dynamic> json) => DailyIssued(
  date: const UtcDateConverter().fromJson(json['date'] as String),
  count: (json['count'] as num).toInt(),
  amount: const DecimalConverter().fromJson(json['amount']),
);

BuyerMix _$BuyerMixFromJson(Map<String, dynamic> json) => BuyerMix(
  customerType: json['customerType'] as String,
  certificateCount: (json['certificateCount'] as num).toInt(),
  principal: const DecimalConverter().fromJson(json['principal']),
  percent: const DecimalConverter().fromJson(json['percent']),
);

LotStats _$LotStatsFromJson(Map<String, dynamic> json) => LotStats(
  certificateCount: (json['certificateCount'] as num).toInt(),
  soldPercent: const DecimalConverter().fromJson(json['soldPercent']),
  expectedInterest: const DecimalConverter().fromJson(json['expectedInterest']),
  averagePrincipal: const DecimalConverter().fromJson(json['averagePrincipal']),
  maxPrincipal: const DecimalConverter().fromJson(json['maxPrincipal']),
  issuedByDay: (json['issuedByDay'] as List<dynamic>)
      .map((e) => DailyIssued.fromJson(e as Map<String, dynamic>))
      .toList(),
  buyerMix: (json['buyerMix'] as List<dynamic>)
      .map((e) => BuyerMix.fromJson(e as Map<String, dynamic>))
      .toList(),
);
