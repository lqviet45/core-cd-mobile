// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interest_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterestDueItem _$InterestDueItemFromJson(Map<String, dynamic> json) =>
    InterestDueItem(
      certificateId: json['certificateId'] as String,
      certificateNumber: json['certificateNumber'] as String,
      customerName: json['customerName'] as String,
      method: json['method'] as String,
      periodIndex: (json['periodIndex'] as num).toInt(),
      periodTotal: (json['periodTotal'] as num).toInt(),
      periodStart: const UtcDateConverter().fromJson(
        json['periodStart'] as String,
      ),
      periodEnd: const UtcDateConverter().fromJson(json['periodEnd'] as String),
      days: (json['days'] as num).toInt(),
      amount: const DecimalConverter().fromJson(json['amount']),
      dueDate: const UtcDateConverter().fromJson(json['dueDate'] as String),
      status: json['status'] as String,
      daysOverdue: (json['daysOverdue'] as num).toInt(),
    );

InterestSummary _$InterestSummaryFromJson(Map<String, dynamic> json) =>
    InterestSummary(
      weekCount: (json['weekCount'] as num).toInt(),
      weekAmount: const DecimalConverter().fromJson(json['weekAmount']),
      overdueCount: (json['overdueCount'] as num).toInt(),
      overdueAmount: const DecimalConverter().fromJson(json['overdueAmount']),
      paidThisMonthCount: (json['paidThisMonthCount'] as num).toInt(),
      paidThisMonthAmount: const DecimalConverter().fromJson(
        json['paidThisMonthAmount'],
      ),
    );

BulkItemResult _$BulkItemResultFromJson(Map<String, dynamic> json) =>
    BulkItemResult(
      certificateNumber: json['certificateNumber'] as String,
      status: json['status'] as String,
      amount: const DecimalConverter().fromJson(json['amount']),
      reason: json['reason'] as String?,
    );

BulkResult _$BulkResultFromJson(Map<String, dynamic> json) => BulkResult(
  succeededCount: (json['succeededCount'] as num).toInt(),
  skippedCount: (json['skippedCount'] as num).toInt(),
  failedCount: (json['failedCount'] as num).toInt(),
  totalAmount: const DecimalConverter().fromJson(json['totalAmount']),
  items: (json['items'] as List<dynamic>)
      .map((e) => BulkItemResult.fromJson(e as Map<String, dynamic>))
      .toList(),
);
