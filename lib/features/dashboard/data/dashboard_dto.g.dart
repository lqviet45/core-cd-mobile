// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  trxNo: json['trxNo'] as String,
  channel: json['channel'] as String,
  cif: json['cif'] as String,
  type: json['type'] as String,
  amount: const DecimalConverter().fromJson(json['amount']),
  status: json['status'] as String,
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  errorDescription: json['errorDescription'] as String?,
);

StatusCount _$StatusCountFromJson(Map<String, dynamic> json) => StatusCount(
  status: json['status'] as String,
  count: (json['count'] as num).toInt(),
  principal: const DecimalConverter().fromJson(json['principal']),
);

Dashboard _$DashboardFromJson(Map<String, dynamic> json) => Dashboard(
  asOfDate: const UtcDateConverter().fromJson(json['asOfDate'] as String),
  activeCustomers: (json['activeCustomers'] as num).toInt(),
  holdingCertificates: (json['holdingCertificates'] as num).toInt(),
  outstandingPrincipal: const DecimalConverter().fromJson(
    json['outstandingPrincipal'],
  ),
  openLots: (json['openLots'] as num).toInt(),
  openLotsRemainingFaceValue: const DecimalConverter().fromJson(
    json['openLotsRemainingFaceValue'],
  ),
  maturing7DaysCount: (json['maturing7DaysCount'] as num).toInt(),
  maturing7DaysPrincipal: const DecimalConverter().fromJson(
    json['maturing7DaysPrincipal'],
  ),
  maturing30DaysCount: (json['maturing30DaysCount'] as num).toInt(),
  maturing30DaysPrincipal: const DecimalConverter().fromJson(
    json['maturing30DaysPrincipal'],
  ),
  pendingTransactions: (json['pendingTransactions'] as num).toInt(),
  failedTransactionsLast24h: (json['failedTransactionsLast24h'] as num).toInt(),
  issuedThisMonth: const DecimalConverter().fromJson(json['issuedThisMonth']),
  certificatesByStatus: (json['certificatesByStatus'] as List<dynamic>)
      .map((e) => StatusCount.fromJson(e as Map<String, dynamic>))
      .toList(),
  issuedLast30Days: (json['issuedLast30Days'] as List<dynamic>)
      .map((e) => DailyIssued.fromJson(e as Map<String, dynamic>))
      .toList(),
  recentTransactions: (json['recentTransactions'] as List<dynamic>)
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .toList(),
  lotsNearlySoldOut: (json['lotsNearlySoldOut'] as num).toInt(),
);
