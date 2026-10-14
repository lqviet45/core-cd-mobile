import 'package:core_cd_mobile/features/customer_app/data/customer_app_dto.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

/// DTO của app khách hàng đối chiếu payload THẬT của backend (`tool/capture_customer_fixtures.mjs`).
void main() {
  test('hồ sơ: CCCD và số điện thoại đã che', () {
    final p = CustomerProfile.fromJson(fixtureMap('customer/me'));
    expect(p.fullName, 'Nguyễn Thị Lan');
    expect(p.identityNumberMasked, contains('•'));
    expect(p.phoneMasked, '090•••••67');
  });

  test('tổng quan: tiền là Decimal, ngày đáo hạn là UTC', () {
    final s = CustomerSummary.fromJson(fixtureMap('customer/summary'));
    expect(s.holdingCount, 2);
    expect(s.totalPrincipal, Decimal.fromInt(300000000));
    expect(s.nextMaturityDate!.isUtc, isTrue);
    expect(s.nextMaturityCertificateId, isNotNull);
  });

  test('danh sách + chi tiết CCTG; không có trường nội bộ của nhân viên', () {
    final page = fixtureMap('customer/certificates_page');
    final items = (page['items'] as List<dynamic>)
        .map((e) => CustCertificate.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(items, isNotEmpty);
    expect(items.every((c) => c.isHolding), isTrue);

    final d = CustCertificate.fromJson(
      fixtureMap('customer/certificate_detail'),
    );
    expect(d.paymentMethod, 'Monthly');
    expect(d.annualRatePercent, Decimal.parse('7.3'));
    expect(d.redemptionDate, isNull);
    expect(d.interestPayments, isEmpty);
    // Payload của khách không chứa các trường nhân viên (ghi chú, hạn mức phong toả, mã lô, tên người tạo...).
    final raw = fixtureMap('customer/certificate_detail');
    for (final k in [
      'notes',
      'holdAmount',
      'lotCode',
      'createdBy',
      'customerId',
    ]) {
      expect(raw.containsKey(k), isFalse, reason: k);
    }
  });

  test('lịch lãi: trạng thái kỳ chỉ có Paid/Upcoming/Due', () {
    final s = CustInterestSchedule.fromJson(
      fixtureMap('customer/interest_schedule_monthly'),
    );
    expect(s.periods.length, greaterThan(1));
    expect(
      s.periods.every((p) => {'Paid', 'Upcoming', 'Due'}.contains(p.status)),
      isTrue,
    );
    final sum = s.periods.fold(Decimal.zero, (a, p) => a + p.amount);
    expect(sum, s.contractInterest, reason: 'tổng các kỳ = lãi hợp đồng');

    final one = CustInterestSchedule.fromJson(
      fixtureMap('customer/interest_schedule_at_maturity'),
    );
    expect(one.periods, isEmpty);
  });

  test('giao dịch: không lộ kênh/người thao tác/lỗi nội bộ', () {
    final t = CustTransaction.fromJson(
      fixtureMap('customer/transaction_detail'),
    );
    expect(t.status, 'Pending');
    expect(t.hasContract, isFalse);
    final raw = fixtureMap('customer/transaction_detail');
    for (final k in [
      'channel',
      'cif',
      'createdBy',
      'errorDescription',
      'makerId',
    ]) {
      expect(raw.containsKey(k), isFalse, reason: k);
    }
  });

  test('đăng nhập OTP: payload khớp mô hình', () {
    final j = fixtureMap('customer/auth_verify');
    expect(
      CustomerProfile.fromJson(j['customer'] as Map<String, dynamic>).cif,
      isNotEmpty,
    );
  });
}
