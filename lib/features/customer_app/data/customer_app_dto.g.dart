// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_app_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerProfile _$CustomerProfileFromJson(Map<String, dynamic> json) =>
    CustomerProfile(
      id: json['id'] as String,
      cif: json['cif'] as String,
      fullName: json['fullName'] as String,
      customerType: json['customerType'] as String,
      identityNumberMasked: json['identityNumberMasked'] as String,
      emailMasked: json['emailMasked'] as String,
      phoneMasked: json['phoneMasked'] as String,
      address: json['address'] as String?,
    );

CustomerSummary _$CustomerSummaryFromJson(Map<String, dynamic> json) =>
    CustomerSummary(
      holdingCount: (json['holdingCount'] as num).toInt(),
      closedCount: (json['closedCount'] as num).toInt(),
      totalPrincipal: const DecimalConverter().fromJson(json['totalPrincipal']),
      estimatedInterestTotal: const DecimalConverter().fromJson(
        json['estimatedInterestTotal'],
      ),
      interestReceivedTotal: const DecimalConverter().fromJson(
        json['interestReceivedTotal'],
      ),
      nextMaturityDate: const NullableUtcDateConverter().fromJson(
        json['nextMaturityDate'] as String?,
      ),
      nextMaturityCertificateId: json['nextMaturityCertificateId'] as String?,
      nextMaturityCertificateNumber:
          json['nextMaturityCertificateNumber'] as String?,
    );

CustInterestPayment _$CustInterestPaymentFromJson(
  Map<String, dynamic> json,
) => CustInterestPayment(
  paymentDate: const UtcDateConverter().fromJson(json['paymentDate'] as String),
  amount: const DecimalConverter().fromJson(json['amount']),
  periodStart: const UtcDateConverter().fromJson(json['periodStart'] as String),
  periodEnd: const UtcDateConverter().fromJson(json['periodEnd'] as String),
);

CustCertificate _$CustCertificateFromJson(Map<String, dynamic> json) =>
    CustCertificate(
      id: json['id'] as String,
      certificateNumber: json['certificateNumber'] as String,
      principal: const DecimalConverter().fromJson(json['principal']),
      annualRatePercent: const DecimalConverter().fromJson(
        json['annualRatePercent'],
      ),
      termDays: (json['termDays'] as num).toInt(),
      termName: json['termName'] as String,
      paymentMethod: json['paymentMethod'] as String,
      issueDate: const UtcDateConverter().fromJson(json['issueDate'] as String),
      maturityDate: const UtcDateConverter().fromJson(
        json['maturityDate'] as String,
      ),
      status: json['status'] as String,
      estimatedInterest: const DecimalConverter().fromJson(
        json['estimatedInterest'],
      ),
      totalInterestPaid: const DecimalConverter().fromJson(
        json['totalInterestPaid'],
      ),
      redemptionDate: const NullableUtcDateConverter().fromJson(
        json['redemptionDate'] as String?,
      ),
      netAmountAtRedemption: const NullableDecimalConverter().fromJson(
        json['netAmountAtRedemption'],
      ),
      interestPayments:
          (json['interestPayments'] as List<dynamic>?)
              ?.map(
                (e) => CustInterestPayment.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );

CustInterestPeriod _$CustInterestPeriodFromJson(Map<String, dynamic> json) =>
    CustInterestPeriod(
      index: (json['index'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      start: const UtcDateConverter().fromJson(json['start'] as String),
      end: const UtcDateConverter().fromJson(json['end'] as String),
      days: (json['days'] as num).toInt(),
      amount: const DecimalConverter().fromJson(json['amount']),
      status: json['status'] as String,
      paidDate: const NullableUtcDateConverter().fromJson(
        json['paidDate'] as String?,
      ),
    );

CustInterestSchedule _$CustInterestScheduleFromJson(
  Map<String, dynamic> json,
) => CustInterestSchedule(
  certificateId: json['certificateId'] as String,
  certificateNumber: json['certificateNumber'] as String,
  paymentMethod: json['paymentMethod'] as String,
  contractInterest: const DecimalConverter().fromJson(json['contractInterest']),
  paidTotal: const DecimalConverter().fromJson(json['paidTotal']),
  periods: (json['periods'] as List<dynamic>)
      .map((e) => CustInterestPeriod.fromJson(e as Map<String, dynamic>))
      .toList(),
);

CustTransaction _$CustTransactionFromJson(Map<String, dynamic> json) =>
    CustTransaction(
      id: json['id'] as String,
      trxNo: json['trxNo'] as String,
      type: json['type'] as String,
      amount: const DecimalConverter().fromJson(json['amount']),
      status: json['status'] as String,
      createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
      hasContract: json['hasContract'] as bool,
      updatedAt: const NullableUtcDateConverter().fromJson(
        json['updatedAt'] as String?,
      ),
      contractCode: json['contractCode'] as String?,
    );

CustDocument _$CustDocumentFromJson(Map<String, dynamic> json) => CustDocument(
  id: json['id'] as String,
  kind: json['kind'] as String,
  version: (json['version'] as num).toInt(),
  fileName: json['fileName'] as String,
  size: (json['size'] as num).toInt(),
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
);

CustReceipt _$CustReceiptFromJson(Map<String, dynamic> json) => CustReceipt(
  date: const UtcDateConverter().fromJson(json['date'] as String),
  kind: json['kind'] as String,
  certificateId: json['certificateId'] as String,
  certificateNumber: json['certificateNumber'] as String,
  termName: json['termName'] as String,
  paymentMethod: json['paymentMethod'] as String,
  amount: const DecimalConverter().fromJson(json['amount']),
  isDue: json['isDue'] as bool,
  periodIndex: (json['periodIndex'] as num?)?.toInt(),
  periodTotal: (json['periodTotal'] as num?)?.toInt(),
);

CustUpcoming _$CustUpcomingFromJson(Map<String, dynamic> json) => CustUpcoming(
  days: (json['days'] as num).toInt(),
  totalAmount: const DecimalConverter().fromJson(json['totalAmount']),
  items: (json['items'] as List<dynamic>)
      .map((e) => CustReceipt.fromJson(e as Map<String, dynamic>))
      .toList(),
);
