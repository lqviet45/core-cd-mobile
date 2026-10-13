import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'trade_dto.g.dart';

/// Kết quả tạo lệnh mua/bán/tạo lại: lệnh được xử lý nền, theo dõi bằng `GET /api/transactions/{id}`.
@JsonSerializable(createToJson: false)
class TrxCreated {
  const TrxCreated({
    required this.transactionId,
    required this.trxNo,
    required this.status,
  });
  factory TrxCreated.fromJson(Map<String, dynamic> json) =>
      _$TrxCreatedFromJson(json);

  final String transactionId;
  final String trxNo;
  final String status;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class SellPreviewItem {
  const SellPreviewItem({
    required this.certificateId,
    required this.certificateNumber,
    required this.maturityDate,
    required this.principal,
    required this.redemptionType,
    required this.interest,
    required this.interestAlreadyPaid,
    required this.lostInterest,
    required this.netAmount,
    required this.fee,
  });
  factory SellPreviewItem.fromJson(Map<String, dynamic> json) =>
      _$SellPreviewItemFromJson(json);

  final String certificateId;
  final String certificateNumber;
  final DateTime maturityDate;
  final Decimal principal;

  /// `AtMaturity | Early`.
  final String redemptionType;
  final Decimal interest;
  final Decimal interestAlreadyPaid;
  final Decimal lostInterest;
  final Decimal netAmount;
  final Decimal fee;

  bool get isEarly => redemptionType == 'Early';
}

/// Xem trước lệnh bán do server tính (cùng công thức và cách chọn CCTG với lệnh bán thật).
@JsonSerializable(createToJson: false)
@DecimalConverter()
class SellPreview {
  const SellPreview({
    required this.eligibleCount,
    required this.eligibleTotalPrincipal,
    required this.items,
    required this.totalPrincipal,
    required this.totalInterest,
    required this.totalInterestAlreadyPaid,
    required this.totalLostInterest,
    required this.totalFee,
    required this.totalNetAmount,
    required this.earlyCount,
    required this.issues,
    required this.canSubmit,
  });
  factory SellPreview.fromJson(Map<String, dynamic> json) =>
      _$SellPreviewFromJson(json);

  final int eligibleCount;
  final Decimal eligibleTotalPrincipal;
  final List<SellPreviewItem> items;
  final Decimal totalPrincipal;
  final Decimal totalInterest;
  final Decimal totalInterestAlreadyPaid;
  final Decimal totalLostInterest;
  final Decimal totalFee;
  final Decimal totalNetAmount;
  final int earlyCount;
  final List<String> issues;
  final bool canSubmit;
}

/// Tham số lệnh bán (dùng chung cho xem trước và gửi).
@immutable
class SellParams {
  const SellParams({
    required this.customerId,
    required this.sellType,
    required this.redemptionDate,
    required this.demandRate,
    this.quantity,
    this.targetAmount,
  });

  final String customerId;

  /// `All | Quantity | Amount`.
  final String sellType;
  final int? quantity;
  final Decimal? targetAmount;
  final DateTime redemptionDate;

  /// Dạng thập phân (0,001 = 0,1%/năm).
  final Decimal demandRate;

  @override
  bool operator ==(Object other) =>
      other is SellParams &&
      other.customerId == customerId &&
      other.sellType == sellType &&
      other.quantity == quantity &&
      other.targetAmount == targetAmount &&
      other.redemptionDate == redemptionDate &&
      other.demandRate == demandRate;

  @override
  int get hashCode => Object.hash(
    customerId,
    sellType,
    quantity,
    targetAmount,
    redemptionDate,
    demandRate,
  );
}
