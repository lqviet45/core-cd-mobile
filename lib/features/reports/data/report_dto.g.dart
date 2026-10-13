// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TopCustomer _$TopCustomerFromJson(Map<String, dynamic> json) => TopCustomer(
  customerName: json['customerName'] as String,
  identityNumber: json['identityNumber'] as String,
  customerType: json['customerType'] as String,
  certificateCount: (json['certificateCount'] as num).toInt(),
  totalPrincipal: const DecimalConverter().fromJson(json['totalPrincipal']),
);

UpcomingItem _$UpcomingItemFromJson(Map<String, dynamic> json) => UpcomingItem(
  certificateNumber: json['certificateNumber'] as String,
  customerName: json['customerName'] as String,
  principal: const DecimalConverter().fromJson(json['principal']),
  estimatedInterest: const DecimalConverter().fromJson(
    json['estimatedInterest'],
  ),
  estimatedPayout: const DecimalConverter().fromJson(json['estimatedPayout']),
  status: json['status'] as String,
);

UpcomingGroup _$UpcomingGroupFromJson(Map<String, dynamic> json) =>
    UpcomingGroup(
      maturityDate: const UtcDateConverter().fromJson(
        json['maturityDate'] as String,
      ),
      daysRemaining: (json['daysRemaining'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      totalPrincipal: const DecimalConverter().fromJson(json['totalPrincipal']),
      totalEstimatedPayout: const DecimalConverter().fromJson(
        json['totalEstimatedPayout'],
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => UpcomingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

UpcomingReport _$UpcomingReportFromJson(Map<String, dynamic> json) =>
    UpcomingReport(
      daysAhead: (json['daysAhead'] as num).toInt(),
      totalCount: (json['totalCount'] as num).toInt(),
      totalPrincipal: const DecimalConverter().fromJson(json['totalPrincipal']),
      totalEstimatedPayout: const DecimalConverter().fromJson(
        json['totalEstimatedPayout'],
      ),
      byDate: (json['byDate'] as List<dynamic>)
          .map((e) => UpcomingGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

LiquidityPeriod _$LiquidityPeriodFromJson(Map<String, dynamic> json) =>
    LiquidityPeriod(
      periodLabel: json['periodLabel'] as String,
      maturityCount: (json['maturityCount'] as num).toInt(),
      principalOutflow: const DecimalConverter().fromJson(
        json['principalOutflow'],
      ),
      periodicInterestOutflow: const DecimalConverter().fromJson(
        json['periodicInterestOutflow'],
      ),
      maturityInterestOutflow: const DecimalConverter().fromJson(
        json['maturityInterestOutflow'],
      ),
      totalOutflow: const DecimalConverter().fromJson(json['totalOutflow']),
    );

LiquidityReport _$LiquidityReportFromJson(Map<String, dynamic> json) =>
    LiquidityReport(
      totalPrincipalOutflow: const DecimalConverter().fromJson(
        json['totalPrincipalOutflow'],
      ),
      totalInterestOutflow: const DecimalConverter().fromJson(
        json['totalInterestOutflow'],
      ),
      totalOutflow: const DecimalConverter().fromJson(json['totalOutflow']),
      byPeriod: (json['byPeriod'] as List<dynamic>)
          .map((e) => LiquidityPeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
