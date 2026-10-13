import 'package:core_cd_mobile/features/search/presentation/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

Map<String, dynamic> get _customer =>
    (fixtureMap('customers_page')['items'] as List).first
        as Map<String, dynamic>;

Map<String, FakeHandler> _routes({FakeHandler? certs, FakeHandler? trx}) => {
  'GET /api/customers': (_) => ok(fixture('customers_page')),
  'GET /api/certificates': certs ?? (_) => ok(fixture('certificates_page')),
  'GET /api/transactions':
      trx ??
      (_) => ok({
        'items': [fixture('transaction_detail')],
        'pageNumber': 1,
        'pageSize': 5,
        'totalCount': 1,
        'totalPages': 1,
      }),
  'GET /api/customers/${_customer['id']}': (_) => ok(_customer),
  'GET /api/customers/${_customer['id']}/certificates': (_) =>
      ok(fixture('customer_certificates')),
};

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.pump(const Duration(milliseconds: 400)); // quá thời gian debounce
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  test('nhận diện từ khoá giống CIF', () {
    expect(looksLikeCif('E2E057823'), isTrue);
    expect(looksLikeCif('CIF1003'), isTrue);
    expect(looksLikeCif('Nguyễn Văn A'), isFalse);
    expect(looksLikeCif('0901234567'), isFalse);
    expect(looksLikeCif('A1'), isFalse);
  });

  testWidgets('gõ dưới 2 ký tự: không gọi API', (t) async {
    final h = await pumpSignedIn(t, routes: _routes());
    await h.push('/search');
    await _type(t, 'K');
    expect(h.adapter.count('GET /api/customers'), 0);
    expect(find.text('Tìm khách hàng, CCTG, giao dịch'), findsOneWidget);
  });

  testWidgets('tên: tìm khách hàng và CCTG, không tìm giao dịch', (t) async {
    final h = await pumpSignedIn(t, routes: _routes());
    await h.push('/search');
    await _type(t, 'Khách');
    expect(
      h.requestsOf('GET /api/customers').single.queryParameters['searchTerm'],
      'Khách',
    );
    expect(h.adapter.count('GET /api/certificates'), 1);
    expect(h.adapter.count('GET /api/transactions'), 0);
    expect(find.text(_customer['fullName'] as String), findsOneWidget);
  });

  testWidgets('giống CIF: tra thêm giao dịch theo CIF', (t) async {
    final h = await pumpSignedIn(t, routes: _routes());
    await h.push('/search');
    await _type(t, 'CIF1003');
    expect(
      h.requestsOf('GET /api/transactions').single.queryParameters['cif'],
      'CIF1003',
    );
    expect(find.text('Giao dịch'), findsWidgets);
  });

  testWidgets('một nhóm lỗi: báo nhóm lỗi, vẫn hiện nhóm còn lại', (t) async {
    final h = await pumpSignedIn(
      t,
      routes: _routes(certs: (_) => failure(500, 'Lỗi')),
    );
    await h.push('/search');
    await _type(t, 'Khách');
    expect(find.textContaining('Không tìm được: CCTG'), findsOneWidget);
    expect(find.text(_customer['fullName'] as String), findsOneWidget);
  });

  testWidgets('mở kết quả: ghi lịch sử từ khoá', (t) async {
    final h = await pumpSignedIn(t, routes: _routes());
    await h.push('/search');
    await _type(t, 'Khách');
    await t.tap(find.text(_customer['fullName'] as String));
    await t.pumpAndSettle();
    expect(h.prefs.getStringList('pref.search_history'), ['Khách']);
  });

  testWidgets('lịch sử hiện ở màn tìm kiếm và xoá được', (t) async {
    final h = await pumpSignedIn(
      t,
      routes: _routes(),
      prefs: {
        'pref.search_history': ['Khách', 'CIF1003'],
      },
    );
    await h.push('/search');
    expect(find.text('Gần đây'), findsOneWidget);
    expect(find.text('CIF1003'), findsOneWidget);

    await t.tap(find.text('CIF1003'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'CIF1003',
    );
    await t.pumpAndSettle();
    expect(h.adapter.count('GET /api/transactions'), 1);

    await t.tap(find.byTooltip('Xoá'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá'));
    await t.pumpAndSettle();
    expect(h.prefs.getStringList('pref.search_history'), isNull);
  });

  testWidgets('lịch sử tối đa 8 mục, mới nhất đứng đầu, không trùng', (
    t,
  ) async {
    final h = await pumpSignedIn(t, routes: _routes());
    final n = h.container.read(searchHistoryProvider.notifier);
    for (var i = 0; i < 12; i++) {
      await n.add('từ khoá $i');
    }
    await n.add('TỪ KHOÁ 10'); // trùng (không phân biệt hoa thường) → lên đầu
    final list = h.container.read(searchHistoryProvider);
    expect(list.length, SearchHistoryNotifier.max);
    expect(list.first, 'TỪ KHOÁ 10');
    expect(list.where((e) => e.toLowerCase() == 'từ khoá 10'), hasLength(1));
    await n.add('a'); // quá ngắn → bỏ qua
    expect(h.container.read(searchHistoryProvider).first, 'TỪ KHOÁ 10');
  });
}
