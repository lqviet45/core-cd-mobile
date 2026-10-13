import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'lot_dto.g.dart';

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class Lot {
  const Lot({
    required this.id,
    required this.lotCode,
    required this.termName,
    required this.annualRatePct,
    required this.paymentMethod,
    required this.totalFaceValue,
    required this.issuedFaceValue,
    required this.remainingFaceValue,
    required this.minPurchaseAmount,
    required this.issueDate,
    required this.maturityDate,
    required this.status,
    required this.certificateCount,
    this.description,
  });

  factory Lot.fromJson(Map<String, dynamic> json) => _$LotFromJson(json);

  final String id;
  final String lotCode;
  final String termName;
  final Decimal annualRatePct;
  final String paymentMethod;
  final Decimal totalFaceValue;
  final Decimal issuedFaceValue;
  final Decimal remainingFaceValue;
  final Decimal minPurchaseAmount;
  final DateTime issueDate;
  final DateTime maturityDate;

  /// `Open | Closed | SoldOut | Matured`.
  final String status;
  final int certificateCount;
  final String? description;

  /// Tỷ lệ đã phát hành, 0–100 (không dùng cho tiền nên `double` là đủ cho thanh tiến độ).
  double get issuedPercent => totalFaceValue == Decimal.zero
      ? 0
      : (issuedFaceValue / totalFaceValue).toDouble() * 100;

  /// Còn ≤ 10% hạn mức (cùng quy tắc với backend/web).
  bool get isNearlySoldOut => status == 'Open' && issuedPercent > 90;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class LotSummary {
  const LotSummary({
    required this.openTotalFaceValue,
    required this.openIssuedFaceValue,
    required this.openRemainingFaceValue,
    required this.nearlySoldOutCount,
    required this.totalCount,
  });

  factory LotSummary.fromJson(Map<String, dynamic> json) =>
      _$LotSummaryFromJson(json);

  final Decimal openTotalFaceValue;
  final Decimal openIssuedFaceValue;
  final Decimal openRemainingFaceValue;
  final int nearlySoldOutCount;
  final int totalCount;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class DailyIssued {
  const DailyIssued({
    required this.date,
    required this.count,
    required this.amount,
  });
  factory DailyIssued.fromJson(Map<String, dynamic> json) =>
      _$DailyIssuedFromJson(json);

  final DateTime date;
  final int count;
  final Decimal amount;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class BuyerMix {
  const BuyerMix({
    required this.customerType,
    required this.certificateCount,
    required this.principal,
    required this.percent,
  });
  factory BuyerMix.fromJson(Map<String, dynamic> json) =>
      _$BuyerMixFromJson(json);

  final String customerType;
  final int certificateCount;
  final Decimal principal;
  final Decimal percent;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class LotStats {
  const LotStats({
    required this.certificateCount,
    required this.soldPercent,
    required this.expectedInterest,
    required this.averagePrincipal,
    required this.maxPrincipal,
    required this.issuedByDay,
    required this.buyerMix,
  });

  factory LotStats.fromJson(Map<String, dynamic> json) =>
      _$LotStatsFromJson(json);

  final int certificateCount;
  final Decimal soldPercent;
  final Decimal expectedInterest;
  final Decimal averagePrincipal;
  final Decimal maxPrincipal;
  final List<DailyIssued> issuedByDay;
  final List<BuyerMix> buyerMix;
}
