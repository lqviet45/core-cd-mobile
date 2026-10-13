import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'interest_dto.g.dart';

/// Một kỳ lãi cần chi / đã chi (CCTG trả lãi hàng tháng, hàng quý).
@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class InterestDueItem {
  const InterestDueItem({
    required this.certificateId,
    required this.certificateNumber,
    required this.customerName,
    required this.method,
    required this.periodIndex,
    required this.periodTotal,
    required this.periodStart,
    required this.periodEnd,
    required this.days,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.daysOverdue,
  });
  factory InterestDueItem.fromJson(Map<String, dynamic> json) =>
      _$InterestDueItemFromJson(json);

  final String certificateId;
  final String certificateNumber;
  final String customerName;

  /// `Monthly | Quarterly`.
  final String method;
  final int periodIndex;
  final int periodTotal;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int days;
  final Decimal amount;
  final DateTime dueDate;

  /// `Upcoming | Today | Overdue | Paid`.
  final String status;
  final int daysOverdue;

  /// Khoá duy nhất của một kỳ (một CCTG có nhiều kỳ).
  String get key =>
      '$certificateId|${periodStart.toIso8601String()}|${periodEnd.toIso8601String()}';
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class InterestSummary {
  const InterestSummary({
    required this.weekCount,
    required this.weekAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.paidThisMonthCount,
    required this.paidThisMonthAmount,
  });
  factory InterestSummary.fromJson(Map<String, dynamic> json) =>
      _$InterestSummaryFromJson(json);

  final int weekCount;
  final Decimal weekAmount;
  final int overdueCount;
  final Decimal overdueAmount;
  final int paidThisMonthCount;
  final Decimal paidThisMonthAmount;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class BulkItemResult {
  const BulkItemResult({
    required this.certificateNumber,
    required this.status,
    required this.amount,
    this.reason,
  });
  factory BulkItemResult.fromJson(Map<String, dynamic> json) =>
      _$BulkItemResultFromJson(json);

  final String certificateNumber;

  /// `Paid | Skipped | Failed`.
  final String status;
  final Decimal amount;
  final String? reason;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class BulkResult {
  const BulkResult({
    required this.succeededCount,
    required this.skippedCount,
    required this.failedCount,
    required this.totalAmount,
    required this.items,
  });
  factory BulkResult.fromJson(Map<String, dynamic> json) =>
      _$BulkResultFromJson(json);

  final int succeededCount;
  final int skippedCount;
  final int failedCount;
  final Decimal totalAmount;
  final List<BulkItemResult> items;
}
