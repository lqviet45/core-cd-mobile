import 'package:core_cd_mobile/features/customer_app/data/customer_app_dto.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/kh_format.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/kh_theme.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

List<T> _items<T>(String name, T Function(Map<String, dynamic>) f) =>
    (fixtureMap(name)['items'] as List<dynamic>)
        .map((e) => f(e as Map<String, dynamic>))
        .toList();

/// DTO của app khách hàng đối chiếu payload THẬT của backend (`tool/capture_customer_fixtures.mjs`).
void main() {
  test(
    'hồ sơ: CCCD, số điện thoại và email đều đã che; không có email thô',
    () {
      final raw = fixtureMap('customer/me');
      final p = CustomerProfile.fromJson(raw);
      expect(p.fullName, 'Nguyễn Thị Lan');
      expect(p.identityNumberMasked, contains('•'));
      expect(p.phoneMasked, '090•••••67');
      expect(p.emailMasked, contains('•'));
      expect(raw.containsKey('email'), isFalse);
    },
  );

  test('tổng quan: tiền là Decimal; có số CCTG đã đóng', () {
    final s = CustomerSummary.fromJson(fixtureMap('customer/summary'));
    expect(s.holdingCount, 3);
    expect(s.closedCount, 1);
    expect(s.totalPrincipal, Decimal.fromInt(330000000));
    expect(s.nextMaturityDate!.isUtc, isTrue);
  });

  test('CCTG đang giữ và đã đóng; không có trường nội bộ của nhân viên', () {
    final holding = _items(
      'customer/certificates_holding',
      CustCertificate.fromJson,
    );
    expect(holding, hasLength(3));
    expect(holding.every((c) => c.isHolding), isTrue);
    final closed = _items(
      'customer/certificates_closed',
      CustCertificate.fromJson,
    ).single;
    expect(closed.isHolding, isFalse);
    expect(closed.status, 'RedeemedEarly');
    expect(closed.redemptionDate, isNotNull);
    expect(closed.netAmountAtRedemption, isNotNull);

    final d = CustCertificate.fromJson(
      fixtureMap('customer/certificate_detail'),
    );
    expect(d.paymentMethod, 'Monthly');
    expect(d.annualRatePercent, Decimal.parse('7.3'));
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

  test('lịch lãi: trạng thái kỳ chỉ có Paid/Upcoming/Due; tổng các kỳ = lãi hợp đồng', () {
    final s = CustInterestSchedule.fromJson(
      fixtureMap('customer/interest_schedule_monthly'),
    );
    expect(s.periods.length, greaterThan(1));
    expect(
      s.periods.every((p) => {'Paid', 'Upcoming', 'Due'}.contains(p.status)),
      isTrue,
    );
    expect(
      s.periods.fold(Decimal.zero, (a, p) => a + p.amount),
      s.contractInterest,
    );
    expect(
      CustInterestSchedule.fromJson(
        fixtureMap('customer/interest_schedule_at_maturity'),
      ).periods,
      isEmpty,
    );
  });

  test('lịch nhận tiền: kỳ lãi + đáo hạn, đã sắp theo ngày, có phương thức nhận lãi', () {
    final u = CustUpcoming.fromJson(fixtureMap('customer/upcoming_366'));
    expect(u.items, isNotEmpty);
    expect(
      u.items.map((i) => i.kind).toSet(),
      containsAll(['Interest', 'Maturity']),
    );
    expect(u.items.every((i) => i.date.isUtc), isTrue);
    expect(
      u.items.map((i) => i.date).toList(),
      orderedEquals([...u.items.map((i) => i.date)]..sort()),
    );
    expect(u.items.fold(Decimal.zero, (a, i) => a + i.amount), u.totalAmount);
    final bullet = u.items.firstWhere(
      (i) => i.isMaturity && i.paymentMethod == 'AtMaturity',
    );
    final monthly = u.items.firstWhere(
      (i) => i.isMaturity && i.paymentMethod == 'Monthly',
    );
    expect(
      bullet.amount,
      greaterThan(Decimal.fromInt(30000000)),
      reason: 'gốc + lãi cuối kỳ',
    );
    expect(monthly.amount, Decimal.fromInt(200000000), reason: 'chỉ gốc');
    final soon = CustUpcoming.fromJson(fixtureMap('customer/upcoming_30'));
    expect(
      soon.items.single.isMaturity,
      isTrue,
      reason: '30 ngày tới chỉ có CCTG sắp đáo hạn',
    );
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
    expect(
      _items('customer/transactions_out', CustTransaction.fromJson),
      isNotEmpty,
    );
  });

  test(
    'đăng nhập lần đầu: cờ phải đổi mật khẩu; lỗi 403 có thông điệp tiếng Việt',
    () {
      expect(
        fixtureMap('customer/auth_login_first')['mustChangePassword'],
        isTrue,
      );
      expect(fixtureMap('customer/auth_login')['mustChangePassword'], isFalse);
      expect(
        fixtureMap('customer/problem_must_change_password')['title'],
        contains('đổi mật khẩu'),
      );
      final access = fixtureMap('customer/app_access_enabled');
      expect(access['hasPassword'], isTrue);
    },
  );

  group('định dạng theo thiết kế', () {
    test('khCompact: tr/tỷ như artboard', () {
      expect(khCompact(Decimal.fromInt(500000000)), '500 tr');
      expect(khCompact(Decimal.parse('309776712')), '309,8 tr');
      expect(khCompact(Decimal.parse('3100000')), '3,1 tr');
      expect(khCompact(Decimal.parse('1250000000')), '1,25 tỷ');
      expect(khCompact(Decimal.fromInt(850000)), '850.000 ₫');
      expect(khSignedCompact(Decimal.parse('309776712')), '+309,8 tr');
    });

    test('lãi suất luôn hai chữ số; tên kỳ hạn; hình thức nhận lãi', () {
      expect(khPercent(Decimal.parse('7.3')), '7,30%');
      expect(khPercent(Decimal.parse('6.5')), '6,50%');
      expect(khTerm('12 tháng - Trả hàng tháng'), 'CCTG 12 tháng');
      expect(khTerm('6 tháng'), 'CCTG 6 tháng');
      expect(khMethodLong('Monthly'), 'lãi hàng tháng');
      expect(khMethodShort('AtMaturity'), 'Cuối kỳ');
    });

    test('dấu tiền vào/ra, đếm ngược, tiến độ', () {
      expect(
        khSignedMoney(Decimal.fromInt(405545205), incoming: true),
        '+405.545.205 ₫',
      );
      expect(
        khSignedMoney(Decimal.fromInt(500000000), incoming: false),
        '−500.000.000 ₫',
      );
      final today = DateTime.utc(2026, 10, 12);
      expect(khDaysUntil(DateTime.utc(2026, 10, 15), today), 3);
      expect(khCountdown(3), 'Còn 3 ngày');
      expect(khCountdown(0), 'Hôm nay');
      expect(khCountdown(-1), 'Đã đến hạn');
      expect(
        khProgress(
          DateTime.utc(2026, 10, 2),
          DateTime.utc(2027, 10, 2),
          DateTime.utc(2026, 10, 2),
        ),
        0,
      );
      expect(
        khProgress(
          DateTime.utc(2026, 10, 2),
          DateTime.utc(2027, 10, 2),
          DateTime.utc(2030),
        ),
        1,
      );
      expect(khMonthGroup(DateTime.utc(2026, 10, 2)), 'Tháng 10/2026');
    });
  });

  test('bảng màu khớp kh.css của thiết kế (sáng và tối)', () {
    expect(KhColors.light.bg, const Color(0xFFF4F3EE));
    expect(KhColors.light.pri, const Color(0xFF0B5D55));
    expect(KhColors.light.amb, const Color(0xFF8A5A00));
    expect(KhColors.light.ok, const Color(0xFF1D6B45));
    expect(KhColors.dark.bg, const Color(0xFF0C1312));
    expect(KhColors.dark.pri, const Color(0xFF7AD8CC));
    expect(
      buildKhTheme(Brightness.dark).extension<KhColors>(),
      same(KhColors.dark),
    );
    expect(
      buildKhTheme(Brightness.light).textTheme.bodyMedium?.fontFamily,
      'BeVietnamPro',
    );
  });
}
