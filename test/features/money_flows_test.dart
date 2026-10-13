import 'package:core_cd_mobile/core/utils/format.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _iso(int daysFromToday) => DateTime.now()
    .toUtc()
    .add(Duration(days: daysFromToday))
    .toIso8601String()
    .substring(0, 10);

String get _today => formatIsoDate(todayBusinessDate());

/// Lô mở bán có ngày phù hợp với hôm nay (fixture thật nhưng ngày dịch theo đồng hồ để test không "hết hạn").
Map<String, dynamic> _lot() => {
  ...((fixture('lots_list')! as List).first as Map<String, dynamic>),
  'issueDate': '${_iso(-30)}T00:00:00Z',
  'maturityDate': '${_iso(300)}T00:00:00Z',
};

Map<String, dynamic> get _customerRow =>
    (fixtureMap('customers_page')['items'] as List).first
        as Map<String, dynamic>;

Map<String, dynamic> _cert({String method = 'AtMaturity'}) => {
  ...fixtureMap('certificate_detail'),
  'status': 'Active',
  'paymentMethod': method,
  'holdAmount': 0,
  'issueDate': '${_iso(-30)}T00:00:00Z',
  'maturityDate': '${_iso(100)}T00:00:00Z',
  'annualRatePercent': 5.5,
};

Map<String, FakeHandler> _buyRoutes({required FakeHandler buy}) {
  final cid = _customerRow['id'];
  final created = fixtureMap('buy_created');
  return {
    'GET /api/cdlots': (_) => ok([_lot()]),
    'GET /api/customers': (_) => ok(fixture('customers_page')),
    'GET /api/customers/$cid': (_) => ok(_customerRow),
    'POST /api/transactions/buy': buy,
    'GET /api/transactions/${created['transactionId']}': (_) => ok({
      ...fixtureMap('transaction_detail'),
      'status': 'Success',
      'fundTransferStatus': 'Success',
      'cdTransferStatus': 'Success',
    }),
  };
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

/// Đi qua 3 bước mua tới màn xác nhận.
Future<void> _toBuyReview(Harness h) async {
  await h.push('/trade/buy?customerId=${_customerRow['id']}');
  await h.tester.tap(find.textContaining('12 tháng').first);
  await h.tester.pumpAndSettle();
  await _tapText(h.tester, 'Tiếp tục');
  await h.tester.enterText(find.byType(TextField).first, '10000000');
  await h.tester.pumpAndSettle();
  await _tapText(h.tester, 'Xem lại');
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('Mua CCTG', () {
    testWidgets(
      'xác thực rồi gửi đúng một lệnh với Idempotency-Key, sang màn theo dõi',
      (t) async {
        final h = await pumpSignedIn(
          t,
          routes: _buyRoutes(buy: (_) => ok(fixture('buy_created'))),
        );
        await _toBuyReview(h);
        expect(find.text('Xác nhận lệnh mua'), findsOneWidget);
        final before = h.bio.prompts;

        final confirm = find.text('Xác nhận bằng sinh trắc');
        await t.tap(confirm);
        await t.tap(confirm, warnIfMissed: false); // bấm đúp
        await t.pumpAndSettle();

        expect(h.bio.prompts, before + 1, reason: 'một lần xác thực');
        final posts = h.requestsOf('POST /api/transactions/buy');
        expect(posts, hasLength(1), reason: 'bấm đúp không gửi hai lệnh');
        expect(posts.single.headers['Idempotency-Key'], matches(_uuid));
        final body = posts.single.data as Map;
        expect(body['principal'], 10000000);
        expect(body['channel'], 'MOBILE');
        expect(body['issueDate'], _today);
        expect(find.text('Mua CCTG thành công'), findsOneWidget);
      },
    );

    testWidgets('xác thực thất bại → KHÔNG gửi lệnh', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _buyRoutes(buy: (_) => ok(fixture('buy_created'))),
      );
      await _toBuyReview(h);
      h.bio.passes = false;
      await _tapText(t, 'Xác nhận bằng sinh trắc');
      expect(h.requestsOf('POST /api/transactions/buy'), isEmpty);
      expect(find.text('Xác nhận lệnh mua'), findsOneWidget);
      expect(find.textContaining('Xác thực không thành công'), findsOneWidget);
    });

    testWidgets('mất mạng giữa chừng → thử lại dùng CÙNG Idempotency-Key', (
      t,
    ) async {
      var calls = 0;
      final h = await pumpSignedIn(
        t,
        routes: _buyRoutes(
          buy: (o) {
            if (++calls == 1) {
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              );
            }
            return ok(fixture('buy_created'));
          },
        ),
      );
      await _toBuyReview(h);
      await _tapText(t, 'Xác nhận bằng sinh trắc');
      expect(find.textContaining('Chưa rõ lệnh đã được gửi'), findsOneWidget);
      await _tapText(t, 'Xác nhận bằng sinh trắc');

      final keys = [
        for (final r in h.requestsOf('POST /api/transactions/buy'))
          r.headers['Idempotency-Key'],
      ];
      expect(keys, hasLength(2));
      expect(
        keys[0],
        keys[1],
        reason: 'cùng khoá → máy chủ không tạo lệnh trùng',
      );
      expect(find.text('Mua CCTG thành công'), findsOneWidget);
    });

    testWidgets('số tiền dưới mức tối thiểu bị chặn ở bước nhập', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _buyRoutes(buy: (_) => ok(fixture('buy_created'))),
      );
      await h.push('/trade/buy?customerId=${_customerRow['id']}');
      await t.tap(find.textContaining('12 tháng').first);
      await t.pumpAndSettle();
      await _tapText(t, 'Tiếp tục');
      await t.enterText(find.byType(TextField).first, '500000');
      await t.pumpAndSettle();
      expect(find.textContaining('Tối thiểu'), findsWidgets);
      final next = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xem lại'),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('Phân quyền', () {
    testWidgets('Viewer không thấy nút tạo giao dịch; Operator thấy', (
      t,
    ) async {
      final routes = {
        'GET /api/transactions': (_) => ok(fixture('customer_transactions')),
      };
      var h = await pumpSignedIn(t, routes: routes, role: 'Viewer');
      await h.go('/transactions');
      expect(find.byIcon(LucideIcons.plus), findsNothing);
      await h.go('/more');
      expect(find.text('Chi lãi định kỳ'), findsNothing);

      await t.pumpWidget(const SizedBox());
      h = await pumpSignedIn(t, routes: routes, role: 'Operator');
      await h.go('/transactions');
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      await h.go('/more');
      expect(find.text('Chi lãi định kỳ'), findsOneWidget);
    });

    testWidgets('Viewer không có nút tất toán trên chi tiết CCTG', (t) async {
      final c = _cert();
      final h = await pumpSignedIn(
        t,
        role: 'Viewer',
        routes: {'GET /api/certificates/${c['id']}': (_) => ok(c)},
      );
      await h.go('/certificates/${c['id']}');
      expect(find.text('Tất toán sớm'), findsNothing);
    });
  });

  group('Tất toán trước hạn', () {
    Map<String, FakeHandler> routes(Map<String, dynamic> c) => {
      'GET /api/certificates/${c['id']}': (_) => ok(c),
      'GET /api/certificates/${c['id']}/preview-early-redemption': (_) =>
          ok(fixture('early_preview')),
      'POST /api/certificates/${c['id']}/redeem-early': (_) => ok(null),
    };

    testWidgets('xem trước → xác thực → gửi ngày và lãi KKH đúng', (t) async {
      final c = _cert();
      final h = await pumpSignedIn(t, routes: routes(c));
      await h.go('/certificates/${c['id']}');
      await _tapText(t, 'Tất toán sớm');
      expect(find.textContaining('Thực nhận'), findsOneWidget);
      await _tapText(t, 'Xác nhận tất toán');

      final posts = h.bodiesOf(
        'POST /api/certificates/${c['id']}/redeem-early',
      );
      expect(posts, hasLength(1));
      expect((posts.single as Map)['redemptionDate'], _today);
      expect((posts.single as Map)['demandRate'], 0.001);
      expect(find.text('Đã tất toán trước hạn'), findsOneWidget);
    });

    testWidgets('xác thực thất bại → KHÔNG tất toán', (t) async {
      final c = _cert();
      final h = await pumpSignedIn(t, routes: routes(c));
      await h.go('/certificates/${c['id']}');
      await _tapText(t, 'Tất toán sớm');
      h.bio.passes = false;
      await _tapText(t, 'Xác nhận tất toán');
      expect(
        h.bodiesOf('POST /api/certificates/${c['id']}/redeem-early'),
        isEmpty,
      );
    });

    testWidgets('CCTG đang phong tỏa: nút bị khoá', (t) async {
      final c = {..._cert(), 'holdAmount': 1000000};
      final h = await pumpSignedIn(t, routes: routes(c));
      await h.go('/certificates/${c['id']}');
      final btn = t.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Tất toán sớm'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(btn.onPressed, isNull);
      expect(find.textContaining('đang phong tỏa'), findsWidgets);
    });
  });

  group('Thêm khách hàng', () {
    testWidgets('kiểm tra tại chỗ, rồi hiện lỗi theo trường từ máy chủ', (
      t,
    ) async {
      var calls = 0;
      final problem = fixtureMap('problem_validation');
      final h = await pumpSignedIn(
        t,
        routes: {
          'POST /api/customers': (_) => ++calls == 1
              ? (
                  status: 400,
                  body: {
                    'title': problem['title'],
                    'errors': {
                      'Cif': ["CIF 'FX1' đã tồn tại trong hệ thống."],
                    },
                  },
                )
              : ok(fixture('customer_created')),
          'GET /api/customers/${fixtureMap('customer_created')['id']}': (_) =>
              ok(_customerRow),
          'GET /api/certificates': (_) => ok(fixture('customer_certificates')),
        },
      );
      await h.push('/customers/new');
      await _tapText(t, 'Tạo khách hàng');
      expect(
        h.requestsOf('POST /api/customers'),
        isEmpty,
        reason: 'chặn tại chỗ',
      );
      expect(find.text('CIF không được trống.'), findsOneWidget);

      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'FX1');
      await t.enterText(fields.at(1), 'Hoàng Anh Tuấn');
      await t.enterText(fields.at(2), '079201004455');
      await t.enterText(fields.at(3), '0903456123');
      await t.enterText(fields.at(4), 'tuan@example.com');
      await _tapText(t, 'Tạo khách hàng');
      expect(find.textContaining('đã tồn tại'), findsOneWidget);

      await t.enterText(fields.at(0), 'FX2');
      await _tapText(t, 'Tạo khách hàng');
      expect(h.requestsOf('POST /api/customers'), hasLength(2));
      expect(find.text(_customerRow['fullName'] as String), findsWidgets);
    });
  });

  group('Chi lãi định kỳ', () {
    testWidgets('chọn kỳ → xác thực → gửi (không kèm số tiền) → báo kỳ lỗi', (
      t,
    ) async {
      final h = await pumpSignedIn(
        t,
        routes: {
          'GET /api/settlement/interest/summary': (_) =>
              ok(fixture('interest_summary')),
          'GET /api/settlement/interest/due': (_) =>
              ok(fixture('interest_due_overdue')),
          'POST /api/settlement/interest/bulk-pay': (_) =>
              ok(fixture('bulk_pay_result')),
        },
      );
      await h.go('/more/interest');
      await t.tap(find.byIcon(LucideIcons.square).first);
      await t.pumpAndSettle();
      await _tapText(t, 'Chi lãi 1 kỳ');
      await _tapText(t, 'Tiếp tục');

      final posts = h.bodiesOf('POST /api/settlement/interest/bulk-pay');
      expect(posts, hasLength(1));
      final item = ((posts.single as Map)['items'] as List).single as Map;
      expect(
        item.containsKey('amount'),
        isFalse,
        reason: 'số tiền do máy chủ tính',
      );
      expect(
        item.keys,
        containsAll(['certificateId', 'periodStart', 'periodEnd']),
      );
      expect(find.text('Kết quả chi lãi'), findsOneWidget);
      expect(find.textContaining('không chi được'), findsOneWidget);
    });
  });

  group('Bán / Tất toán', () {
    testWidgets('xem trước → xác nhận → gửi lệnh bán với Idempotency-Key', (
      t,
    ) async {
      final preview = fixtureMap('sell_preview');
      final h = await pumpSignedIn(
        t,
        routes: {
          'GET /api/customers/${_customerRow['id']}': (_) => ok(_customerRow),
          'POST /api/transactions/sell/preview': (_) => ok(preview),
          'POST /api/transactions/sell': (_) => ok(fixture('buy_created')),
          'GET /api/transactions/${fixtureMap('buy_created')['transactionId']}':
              (_) => ok({
                ...fixtureMap('transaction_detail'),
                'type': 'SellSecondary',
                'status': 'Success',
              }),
        },
      );
      await h.push('/trade/sell?customerId=${_customerRow['id']}');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.text('Sẽ tất toán'), findsOneWidget);

      await _tapText(t, 'Xem lại');
      await _tapText(t, 'Xác nhận');

      final posts = h.requestsOf('POST /api/transactions/sell');
      expect(posts, hasLength(1));
      expect(posts.single.headers['Idempotency-Key'], matches(_uuid));
      final body = posts.single.data as Map;
      expect(body['sellType'], 'All');
      expect(body['channel'], 'MOBILE');
      expect(body['customerId'], _customerRow['id']);
      expect(find.textContaining('thành công'), findsWidgets);
    });
  });
}
