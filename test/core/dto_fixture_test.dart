import 'package:core_cd_mobile/core/auth/auth_models.dart';
import 'package:core_cd_mobile/core/models/paged.dart';
import 'package:core_cd_mobile/features/certificates/data/certificate_dto.dart';
import 'package:core_cd_mobile/features/customers/data/customer_dto.dart';
import 'package:core_cd_mobile/features/dashboard/data/dashboard_dto.dart';
import 'package:core_cd_mobile/features/lots/data/lot_dto.dart';
import 'package:core_cd_mobile/features/notifications/data/notification_repository.dart';
import 'package:core_cd_mobile/features/reports/data/report_dto.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

/// Các DTO tự viết tay phải đọc được ĐÚNG dữ liệu mà backend thật trả về (fixture lấy từ API đang chạy).
/// Nếu backend đổi tên/kiểu trường, test này đỏ trước khi app hỏng.
void main() {
  test('đăng nhập: token, hạn dùng, người dùng và vai trò', () {
    final t = AuthTokens.fromJson(fixtureMap('auth_login'));
    expect(t.accessToken, 'ACCESS_TOKEN');
    expect(t.refreshToken, 'REFRESH_TOKEN');
    expect(t.user.role, Role.admin);
    expect(t.user.initials, isNotEmpty);
    expect(t.accessTokenExpiresAt.isUtc, isTrue);
    expect(AuthUser.fromJson(fixtureMap('auth_me')).username, 'admin');
  });

  test(
    'vai trò lạ rơi về quyền thấp nhất',
    () => expect(Role.parse('Superuser'), Role.viewer),
  );

  test('quyền theo thứ bậc Viewer < Operator < Admin', () {
    expect(Role.admin.atLeast(Role.operator), isTrue);
    expect(Role.viewer.atLeast(Role.operator), isFalse);
  });

  test('trang CCTG và chi tiết (có kỳ chi lãi)', () {
    final page = Paged.fromJson(
      fixtureMap('certificates_page'),
      Certificate.fromJson,
    );
    expect(page.items, isNotEmpty);
    expect(page.totalCount, greaterThan(0));
    final c = page.items.first;
    expect(c.principal, greaterThan(Decimal.zero));
    expect(c.interestPayments, isEmpty); // danh sách không kèm kỳ chi lãi

    final d = Certificate.fromJson(fixtureMap('certificate_detail'));
    expect(d.paymentMethod, 'Monthly');
    expect(d.interestPayments, isNotEmpty);
    expect(d.annualRatePercent, Decimal.parse('6.3'));
    expect(d.maturityDate.isUtc, isTrue);
    expect(d.isRedeemed, isFalse);
  });

  test('CCTG đã tất toán sớm có phí và kết quả', () {
    final c = Certificate.fromJson(fixtureMap('certificate_detail_redeemed'));
    expect(c.isRedeemed, isTrue);
    expect(c.netAmountAtRedemption, isNotNull);
    expect(c.redemptionDate, isNotNull);
  });

  test('lịch chi lãi: tổng các kỳ đúng bằng lãi hợp đồng ở dữ liệu thật', () {
    final s = InterestSchedule.fromJson(
      fixtureMap('certificate_interest_schedule'),
    );
    final sum = s.periods.fold<Decimal>(Decimal.zero, (a, p) => a + p.amount);
    expect(sum, s.contractInterest);
    expect(
      s.periods.first.status,
      anyOf('Paid', 'Overdue', 'Upcoming', 'Today', 'Blocked'),
    );
  });

  test('khách hàng', () {
    final page = Paged.fromJson(
      fixtureMap('customers_page'),
      Customer.fromJson,
    );
    expect(page.items, isNotEmpty);
    final c = Customer.fromJson(fixtureMap('customer_detail'));
    expect(c.identityNumber, contains('•')); // backend đã che CCCD/MST
    expect(c.isBusiness, isFalse);
    expect(c.outstandingPrincipal, greaterThanOrEqualTo(Decimal.zero));
  });

  test('đợt phát hành và thống kê', () {
    final lots = (fixture('lots_list')! as List)
        .map((e) => Lot.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(lots, isNotEmpty);
    final l = Lot.fromJson(fixtureMap('lot_detail'));
    expect(l.issuedFaceValue + l.remainingFaceValue, l.totalFaceValue);
    expect(l.issuedPercent, inInclusiveRange(0, 100));
    final s = LotStats.fromJson(fixtureMap('lot_stats'));
    expect(s.issuedByDay, isNotEmpty);
    expect(
      LotSummary.fromJson(fixtureMap('lots_summary')).totalCount,
      greaterThan(0),
    );
  });

  test('tổng quan', () {
    final d = Dashboard.fromJson(fixtureMap('dashboard_summary'));
    expect(d.holdingCertificates, greaterThan(0));
    expect(d.recentTransactions, isNotEmpty);
    expect(d.recentTransactions.first.type, isNotEmpty);
    expect(d.asOfDate.isUtc, isTrue);
  });

  test('báo cáo danh mục, thanh khoản và sắp đáo hạn', () {
    final p = PortfolioReport.fromJson(fixtureMap('report_portfolio'));
    expect(p.byTerm, isNotEmpty);
    expect(p.byTerm.first.label, isNotEmpty); // nhãn gom từ khoá `termBucket`
    expect(p.top10Customers.first.identityNumber, contains('•'));
    final l = LiquidityReport.fromJson(fixtureMap('report_liquidity'));
    expect(l.byPeriod, isNotEmpty);
    expect(l.totalOutflow, l.totalPrincipalOutflow + l.totalInterestOutflow);
    final u = UpcomingReport.fromJson(fixtureMap('report_upcoming'));
    expect(u.daysAhead, 30);
  });
  test('thông báo', () {
    final n = AppNotification.fromJson({
      'id': 'a',
      'type': 'NearMaturity',
      'severity': 'Info',
      'title': 't',
      'body': 'b',
      'linkUrl': '/settlement',
      'createdAt': '2026-10-13T04:00:00Z',
      'isRead': false,
    });
    expect(n.isRead, isFalse);
    expect(n.createdAt.isUtc, isTrue);
  });
}
