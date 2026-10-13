import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'report_dto.g.dart';

class GroupTotal {
  const GroupTotal({
    required this.label,
    required this.count,
    required this.totalPrincipal,
  });

  /// Backend dùng tên khoá khác nhau cho nhãn (`termBucket`, `paymentMethod`, `customerType`, `status`) –
  /// [PortfolioReport] gom về một trường `label`.
  final String label;
  final int count;
  final Decimal totalPrincipal;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class TopCustomer {
  const TopCustomer({
    required this.customerName,
    required this.identityNumber,
    required this.customerType,
    required this.certificateCount,
    required this.totalPrincipal,
  });
  factory TopCustomer.fromJson(Map<String, dynamic> json) =>
      _$TopCustomerFromJson(json);

  final String customerName;
  final String identityNumber;
  final String customerType;
  final int certificateCount;
  final Decimal totalPrincipal;
}

class PortfolioReport {
  const PortfolioReport({
    required this.totalActiveCertificates,
    required this.totalOutstandingPrincipal,
    required this.totalEstimatedInterest,
    required this.byStatus,
    required this.byTerm,
    required this.byPaymentMethod,
    required this.byCustomerType,
    required this.top10Customers,
  });

  factory PortfolioReport.fromJson(Map<String, dynamic> j) {
    List<GroupTotal> groups(String key, String labelKey) =>
        (j[key] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .map(
              (m) => GroupTotal(
                label: m[labelKey] as String,
                count: m['count'] as int,
                totalPrincipal: decimalFromJson(m['totalPrincipal']),
              ),
            )
            .toList();
    return PortfolioReport(
      totalActiveCertificates: j['totalActiveCertificates'] as int,
      totalOutstandingPrincipal: decimalFromJson(
        j['totalOutstandingPrincipal'],
      ),
      totalEstimatedInterest: decimalFromJson(j['totalEstimatedInterest']),
      byStatus: groups('byStatus', 'status'),
      byTerm: groups('byTerm', 'termBucket'),
      byPaymentMethod: groups('byPaymentMethod', 'paymentMethod'),
      byCustomerType: groups('byCustomerType', 'customerType'),
      top10Customers: (j['top10Customers'] as List<dynamic>)
          .map((e) => TopCustomer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int totalActiveCertificates;
  final Decimal totalOutstandingPrincipal;
  final Decimal totalEstimatedInterest;
  final List<GroupTotal> byStatus;
  final List<GroupTotal> byTerm;
  final List<GroupTotal> byPaymentMethod;
  final List<GroupTotal> byCustomerType;
  final List<TopCustomer> top10Customers;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class UpcomingItem {
  const UpcomingItem({
    required this.certificateNumber,
    required this.customerName,
    required this.principal,
    required this.estimatedInterest,
    required this.estimatedPayout,
    required this.status,
  });
  factory UpcomingItem.fromJson(Map<String, dynamic> json) =>
      _$UpcomingItemFromJson(json);

  final String certificateNumber;
  final String customerName;
  final Decimal principal;
  final Decimal estimatedInterest;
  final Decimal estimatedPayout;
  final String status;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
@UtcDateConverter()
class UpcomingGroup {
  const UpcomingGroup({
    required this.maturityDate,
    required this.daysRemaining,
    required this.count,
    required this.totalPrincipal,
    required this.totalEstimatedPayout,
    required this.items,
  });
  factory UpcomingGroup.fromJson(Map<String, dynamic> json) =>
      _$UpcomingGroupFromJson(json);

  final DateTime maturityDate;
  final int daysRemaining;
  final int count;
  final Decimal totalPrincipal;
  final Decimal totalEstimatedPayout;
  final List<UpcomingItem> items;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class UpcomingReport {
  const UpcomingReport({
    required this.daysAhead,
    required this.totalCount,
    required this.totalPrincipal,
    required this.totalEstimatedPayout,
    required this.byDate,
  });
  factory UpcomingReport.fromJson(Map<String, dynamic> json) =>
      _$UpcomingReportFromJson(json);

  final int daysAhead;
  final int totalCount;
  final Decimal totalPrincipal;
  final Decimal totalEstimatedPayout;
  final List<UpcomingGroup> byDate;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class LiquidityPeriod {
  const LiquidityPeriod({
    required this.periodLabel,
    required this.maturityCount,
    required this.principalOutflow,
    required this.periodicInterestOutflow,
    required this.maturityInterestOutflow,
    required this.totalOutflow,
  });
  factory LiquidityPeriod.fromJson(Map<String, dynamic> json) =>
      _$LiquidityPeriodFromJson(json);

  final String periodLabel;
  final int maturityCount;
  final Decimal principalOutflow;
  final Decimal periodicInterestOutflow;
  final Decimal maturityInterestOutflow;
  final Decimal totalOutflow;
}

@JsonSerializable(createToJson: false)
@DecimalConverter()
class LiquidityReport {
  const LiquidityReport({
    required this.totalPrincipalOutflow,
    required this.totalInterestOutflow,
    required this.totalOutflow,
    required this.byPeriod,
  });
  factory LiquidityReport.fromJson(Map<String, dynamic> json) =>
      _$LiquidityReportFromJson(json);

  final Decimal totalPrincipalOutflow;
  final Decimal totalInterestOutflow;
  final Decimal totalOutflow;
  final List<LiquidityPeriod> byPeriod;
}
