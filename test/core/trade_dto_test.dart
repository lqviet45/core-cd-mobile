import 'package:core_cd_mobile/core/money/money_gate.dart';
import 'package:core_cd_mobile/core/network/api_exception.dart';
import 'package:core_cd_mobile/features/certificates/data/certificate_dto.dart';
import 'package:core_cd_mobile/features/dashboard/data/dashboard_dto.dart';
import 'package:core_cd_mobile/features/interest/data/interest_dto.dart';
import 'package:core_cd_mobile/features/transactions/data/trade_dto.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

/// DTO của luồng ghi phải đọc được payload THẬT (lấy từ backend bằng tool/capture_fixtures.mjs).
void main() {
  test('lệnh mua đã tạo', () {
    final c = TrxCreated.fromJson(fixtureMap('buy_created'));
    expect(c.transactionId, isNotEmpty);
    expect(c.trxNo, startsWith('TRX'));
    expect(c.status, 'Pending');
  });

  test('chi tiết giao dịch có các bút toán và trạng thái kết thúc', () {
    final t = Transaction.fromJson(fixtureMap('transaction_detail'));
    expect(t.fundTransferStatus, isNotEmpty);
    expect(t.cdTransferStatus, isNotEmpty);
    expect(t.isTerminal, isFalse, reason: 'fixture là lệnh Pending');
    final done = Transaction.fromJson({
      ...fixtureMap('transaction_detail'),
      'status': 'Success',
    });
    expect(done.isTerminal, isTrue);
  });

  test('giao dịch trong danh sách (thiếu trường bút toán) vẫn đọc được', () {
    final j = {...fixtureMap('transaction_detail')}
      ..remove('fundTransferStatus')
      ..remove('cdTransferStatus');
    final t = Transaction.fromJson(j);
    expect(t.fundTransferStatus, 'Pending');
  });

  test('xem trước lệnh bán: tổng khớp từng CCTG', () {
    final p = SellPreview.fromJson(fixtureMap('sell_preview'));
    expect(p.canSubmit, isTrue);
    expect(p.items, isNotEmpty);
    Decimal sum(Decimal Function(SellPreviewItem) f) =>
        p.items.fold(Decimal.zero, (a, b) => a + f(b));
    expect(sum((i) => i.principal), p.totalPrincipal);
    expect(sum((i) => i.netAmount), p.totalNetAmount);
    expect(p.items.where((i) => i.isEarly).length, p.earlyCount);
  });

  test(
    'xem trước tất toán sớm: thực nhận = gốc + lãi − phí (+ trừ lãi đã chi)',
    () {
      final e = EarlyRedemptionPreview.fromJson(fixtureMap('early_preview'));
      expect(e.demandRate, Decimal.parse('0.001'));
      expect(
        e.principal + e.interestEarned - e.fee,
        greaterThanOrEqualTo(e.netAmount),
      );
      expect(e.actualDays, greaterThan(0));
    },
  );

  test('chi lãi: kỳ đến hạn và kết quả hàng loạt có dòng lỗi kèm lý do', () {
    final due = fixtureMap('interest_due_overdue');
    final items = (due['items'] as List)
        .map((e) => InterestDueItem.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(items, isNotEmpty);
    expect(items.map((i) => i.key).toSet(), hasLength(items.length));
    expect(items.first.status, 'Overdue');

    final r = BulkResult.fromJson(fixtureMap('bulk_pay_result'));
    expect(r.succeededCount + r.failedCount + r.skippedCount, r.items.length);
    expect(
      r.items.where((i) => i.status == 'Failed').every((i) => i.reason != null),
      isTrue,
    );
    final s = InterestSummary.fromJson(fixtureMap('interest_summary'));
    expect(s.overdueCount, greaterThanOrEqualTo(0));
  });

  test('lỗi 400 của máy chủ → lỗi theo trường (khoá viết thường chữ đầu)', () {
    final res = Response<dynamic>(
      requestOptions: RequestOptions(path: '/api/customers'),
      statusCode: 400,
      data: fixtureMap('problem_validation'),
    );
    final e = ApiException.fromDio(
      DioException(requestOptions: res.requestOptions, response: res),
    );
    expect(e.status, 400);
    expect(e.fieldErrors.keys, containsAll(['cif', 'fullName', 'email']));
    expect(e.fieldErrors['cif'], isNotEmpty);
  });

  test(
    'thông điệp của cổng ghi tiền: mỗi lý do chặn đều có lời giải thích',
    () {
      for (final r in GateResult.values.where((r) => r != GateResult.ok)) {
        expect(gateMessage(r), isNotEmpty, reason: '$r');
      }
      expect(gateMessage(GateResult.ok), isEmpty);
    },
  );
}
