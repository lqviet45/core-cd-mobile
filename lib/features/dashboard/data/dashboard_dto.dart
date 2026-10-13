import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';
import '../../lots/data/lot_dto.dart';

part 'dashboard_dto.g.dart';

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class Transaction {
  const Transaction({
    required this.id,
    required this.trxNo,
    required this.channel,
    required this.cif,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.errorDescription,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  final String id;
  final String trxNo;
  final String channel;
  final String cif;
  final String type;
  final Decimal amount;
  final String status;
  final DateTime createdAt;
  final String? errorDescription;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class StatusCount {
  const StatusCount({
    required this.status,
    required this.count,
    required this.principal,
  });
  factory StatusCount.fromJson(Map<String, dynamic> json) =>
      _$StatusCountFromJson(json);

  final String status;
  final int count;
  final Decimal principal;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class Dashboard {
  const Dashboard({
    required this.asOfDate,
    required this.activeCustomers,
    required this.holdingCertificates,
    required this.outstandingPrincipal,
    required this.openLots,
    required this.openLotsRemainingFaceValue,
    required this.maturing7DaysCount,
    required this.maturing7DaysPrincipal,
    required this.maturing30DaysCount,
    required this.maturing30DaysPrincipal,
    required this.pendingTransactions,
    required this.failedTransactionsLast24h,
    required this.issuedThisMonth,
    required this.certificatesByStatus,
    required this.issuedLast30Days,
    required this.recentTransactions,
    required this.lotsNearlySoldOut,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) =>
      _$DashboardFromJson(json);

  final DateTime asOfDate;
  final int activeCustomers;
  final int holdingCertificates;
  final Decimal outstandingPrincipal;
  final int openLots;
  final Decimal openLotsRemainingFaceValue;
  final int maturing7DaysCount;
  final Decimal maturing7DaysPrincipal;
  final int maturing30DaysCount;
  final Decimal maturing30DaysPrincipal;
  final int pendingTransactions;
  final int failedTransactionsLast24h;
  final Decimal issuedThisMonth;
  final List<StatusCount> certificatesByStatus;
  final List<DailyIssued> issuedLast30Days;
  final List<Transaction> recentTransactions;
  final int lotsNearlySoldOut;
}
