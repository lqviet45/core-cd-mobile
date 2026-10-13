import 'dart:async';

import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/features/documents/data/document_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

final _trx = {
  ...fixtureMap('transaction_detail'),
  'status': 'Success',
  'fundTransferStatus': 'Success',
  'cdTransferStatus': 'Success',
};
final _trxId = _trx['id']! as String;

Map<String, Object?> _doc({
  String id = 'd1',
  String kind = 'TradeContract',
  String status = 'Available',
}) => {
  'id': id,
  'ownerType': 'Transaction',
  'ownerId': _trxId,
  'kind': kind,
  'status': status,
  'version': 1,
  'fileName': 'hop-dong.pdf',
  'contentType': 'application/pdf',
  'size': 1234,
  'createdAt': '2026-10-13T02:00:00Z',
  'createdBy': 'admin',
};

Map<String, FakeHandler> _routes({
  List<Map<String, Object?>>? docs,
  FakeHandler? list,
  FakeHandler? generate,
  FakeHandler? uploads,
  FakeHandler? confirm,
}) => {
  'GET /api/transactions/$_trxId': (_) => ok(_trx),
  'GET /api/documents': list ?? (_) => ok(docs ?? [_doc()]),
  'POST /api/documents/d1/download-link': (_) => ok({
    'url': 'https://storage.test/dl/d1?sig=abc',
    'expiresAt': '2026-10-13T02:05:00Z',
    'fileName': 'hop-dong.pdf',
  }),
  'POST /api/transactions/$_trxId/contract':
      generate ?? (_) => ok(_doc(id: 'd2')),
  'POST /api/documents/uploads':
      uploads ??
      (_) => ok({
        'documentId': 'd3',
        'uploadUrl': 'https://storage.test/up/d3?sig=xyz',
        'expiresAt': '2026-10-13T02:05:00Z',
        'contentType': 'image/jpeg',
        'maxBytes': 1000000,
      }),
  'POST /api/documents/d3/confirm':
      confirm ?? (_) => ok(_doc(id: 'd3', kind: 'SignedContract')),
};

FakeAdapter _storage() => FakeAdapter({
  'GET https://storage.test/dl/d1?sig=abc': (_) => ok('PDF'),
  'PUT https://storage.test/up/d3?sig=xyz': (_) => ok(null),
});

Future<Harness> _openTrx(
  WidgetTester t, {
  Map<String, FakeHandler>? routes,
  String role = 'Admin',
  FakeAdapter? storage,
}) async {
  final h = await pumpSignedIn(
    t,
    routes: routes ?? _routes(),
    role: role,
    storage: storage,
  );
  await t.binding.setSurfaceSize(const Size(390, 2400));
  await h.go('/transactions/$_trxId');
  return h;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('Tài liệu', () {
    testWidgets('hiện danh sách; chạm để mở bằng URL ngắn hạn', (t) async {
      final h = await _openTrx(t);
      expect(find.text('Tài liệu'), findsOneWidget);
      expect(find.text('Hợp đồng'), findsOneWidget);

      await t.tap(find.text('Hợp đồng'));
      await t.pumpAndSettle();
      expect(h.opener.opened, ['https://storage.test/dl/d1?sig=abc']);
      // Danh sách chỉ chứa metadata: URL không được lưu/hiện ở đâu.
      expect(find.textContaining('storage.test'), findsNothing);
    });

    testWidgets('không có ứng dụng mở → báo lỗi', (t) async {
      final h = await _openTrx(t);
      h.opener.canOpen = false;
      await t.tap(find.text('Hợp đồng'));
      await t.pumpAndSettle();
      expect(
        find.text('Không có ứng dụng nào mở được tệp này.'),
        findsOneWidget,
      );
    });

    testWidgets('chia sẻ: tải nội dung bằng Dio trần, không kèm token', (
      t,
    ) async {
      final storage = _storage();
      final h = await _openTrx(t, storage: storage);
      await t.tap(find.byTooltip('Chia sẻ'));
      await t.pumpAndSettle();

      expect(h.opener.shared.single.name, 'hop-dong.pdf');
      expect(h.opener.shared.single.type, 'application/pdf');
      expect(h.opener.shared.single.bytes, isNotEmpty);
      final get = storage.requests.single;
      expect(
        get.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    testWidgets('tài liệu đang chờ xác nhận: không mở/chia sẻ được', (t) async {
      final h = await _openTrx(
        t,
        routes: _routes(docs: [_doc(status: 'Pending')]),
      );
      expect(find.text('Đang chờ xác nhận tệp'), findsOneWidget);
      expect(find.byTooltip('Chia sẻ'), findsNothing);
      await t.tap(find.text('Hợp đồng'));
      await t.pumpAndSettle();
      expect(h.opener.opened, isEmpty);
      expect(h.adapter.count('POST /api/documents/d1/download-link'), 0);
    });

    testWidgets('tạo hợp đồng: gọi API sinh rồi tải lại danh sách', (t) async {
      var generated = false;
      final h = await _openTrx(
        t,
        routes: _routes(
          list: (_) => ok(generated ? [_doc(), _doc(id: 'd2')] : [_doc()]),
          generate: (_) {
            generated = true;
            return ok(_doc(id: 'd2'));
          },
        ),
      );
      expect(find.text('Hợp đồng'), findsOneWidget);
      await t.tap(find.text('Tạo hợp đồng'));
      await t.pumpAndSettle();
      expect(h.adapter.count('POST /api/transactions/$_trxId/contract'), 1);
      expect(find.text('Hợp đồng'), findsNWidgets(2));
    });

    testWidgets(
      'kho tài liệu chưa bật (503) → thông báo rõ, không có nút thử lại',
      (t) async {
        await _openTrx(
          t,
          routes: _routes(list: (_) => failure(503, 'Service Unavailable')),
        );
        expect(
          find.text('Kho tài liệu chưa được bật trên máy chủ.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsNothing);
      },
    );

    testWidgets('Viewer không thấy mục Tài liệu và không gọi API', (t) async {
      final h = await _openTrx(t, role: 'Viewer');
      expect(find.text('Tài liệu'), findsNothing);
      expect(h.adapter.count('GET /api/documents'), 0);
    });

    testWidgets('tải ảnh lên: xin URL → PUT lên kho không token → xác nhận', (
      t,
    ) async {
      final storage = _storage();
      final h = await _openTrx(t, storage: storage);
      h.picker.next = UploadFile(
        name: 'cccd.jpg',
        contentType: 'image/jpeg',
        bytes: List<int>.filled(500, 1),
      );

      await t.tap(find.text('Tải bản đã ký'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chụp ảnh'));
      await t.pumpAndSettle();

      expect(h.picker.calls, [true]);
      expect(h.bodiesOf('POST /api/documents/uploads').single, {
        'kind': 'SignedContract',
        'ownerId': _trxId,
        'fileName': 'cccd.jpg',
        'contentType': 'image/jpeg',
        'size': 500,
      });
      final put = storage.requests.single;
      expect(put.method, 'PUT');
      expect(
        put.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        put.headers['content-type'] ?? put.headers['Content-Type'],
        'image/jpeg',
      );
      expect(h.adapter.count('POST /api/documents/d3/confirm'), 1);
      // Thứ tự: xin URL trước, xác nhận sau cùng.
      final order = [
        for (final r in h.adapter.requests)
          if (r.path.startsWith('/api/documents/')) '${r.method} ${r.path}',
      ];
      expect(
        order.indexOf('POST /api/documents/uploads'),
        lessThan(order.indexOf('POST /api/documents/d3/confirm')),
      );
    });

    testWidgets('huỷ chọn ảnh: không gọi API nào', (t) async {
      final h = await _openTrx(t);
      h.picker.next = null;
      await t.tap(find.text('Tải bản đã ký'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn từ thư viện'));
      await t.pumpAndSettle();
      expect(h.picker.calls, [false]);
      expect(h.adapter.count('POST /api/documents/uploads'), 0);
    });

    testWidgets('tệp vượt giới hạn máy chủ: không PUT, không xác nhận', (
      t,
    ) async {
      final storage = _storage();
      final h = await _openTrx(
        t,
        storage: storage,
        routes: _routes(
          uploads: (_) => ok({
            'documentId': 'd3',
            'uploadUrl': 'https://storage.test/up/d3?sig=xyz',
            'expiresAt': '2026-10-13T02:05:00Z',
            'contentType': 'image/jpeg',
            'maxBytes': 100,
          }),
        ),
      );
      h.picker.next = UploadFile(
        name: 'to.jpg',
        contentType: 'image/jpeg',
        bytes: List<int>.filled(500, 1),
      );
      await t.tap(find.text('Tải bản đã ký'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chụp ảnh'));
      await t.pumpAndSettle();
      expect(storage.requests, isEmpty);
      expect(h.adapter.count('POST /api/documents/d3/confirm'), 0);
      expect(
        find.text('Tệp quá lớn so với giới hạn của hệ thống.'),
        findsOneWidget,
      );
    });
  });

  group('Đăng ký push', () {
    Map<String, FakeHandler> push({FakeHandler? register}) => {
      'POST /api/devices': register ?? (_) => ok(null),
      'POST /api/devices/unregister': (_) => ok(null),
      'POST /api/auth/logout': (_) => ok(null),
      'GET /api/transactions': (_) => ok({
        'items': <Object>[],
        'pageNumber': 1,
        'pageSize': 20,
        'totalCount': 0,
        'totalPages': 0,
      }),
      'GET /api/transactions/$_trxId': (_) => ok(_trx),
    };

    testWidgets('đăng nhập có token → đăng ký đúng một lần', (t) async {
      final h = await pumpSignedIn(t, routes: push(), pushToken: 'tok1');
      final body = h.bodiesOf('POST /api/devices').single as Map;
      expect(body['token'], 'tok1');
      expect(body['platform'], anyOf('Android', 'iOS'));
      expect(body['appVersion'], isNotEmpty);
      expect(body['deviceName'], isNotEmpty);
    });

    testWidgets('chưa cấu hình push (không token) → không gọi API', (t) async {
      final h = await pumpSignedIn(t, routes: push());
      expect(h.adapter.count('POST /api/devices'), 0);
    });

    testWidgets('token xoay vòng → đăng ký lại; cùng token → bỏ qua', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: push(), pushToken: 'tok1');
      h.pushSource.refresh('tok2');
      await t.pumpAndSettle();
      h.pushSource.refresh('tok2');
      await t.pumpAndSettle();
      expect(
        [for (final b in h.bodiesOf('POST /api/devices')) (b as Map)['token']],
        ['tok1', 'tok2'],
      );
    });

    testWidgets('đăng ký lỗi (500) không làm hỏng phiên', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: push(register: (_) => failure(500)),
        pushToken: 'tok1',
      );
      await h.go('/home');
      expect(h.router.routeInformationProvider.value.uri.path, '/home');
    });

    testWidgets('đăng xuất: huỷ đăng ký TRƯỚC khi thu hồi phiên, xoá token', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: push(), pushToken: 'tok1');
      unawaited(h.container.read(authControllerProvider.notifier).logout());
      await t.pumpAndSettle();

      final order = [
        for (final r in h.adapter.requests) '${r.method} ${r.path}',
      ];
      expect(
        order.indexOf('POST /api/devices/unregister'),
        lessThan(order.indexOf('POST /api/auth/logout')),
      );
      expect(h.bodiesOf('POST /api/devices/unregister').single, {
        'token': 'tok1',
      });
      expect(h.pushSource.deleted, 1);
    });

    testWidgets('chạm thông báo đẩy → mở đúng màn hình', (t) async {
      final h = await pumpSignedIn(t, routes: push(), pushToken: 'tok1');
      h.pushSource.tap({'type': 'TransactionFailed'});
      await t.pumpAndSettle();
      expect(h.router.routeInformationProvider.value.uri.path, '/transactions');

      h.pushSource.tap({'link': '/transactions/$_trxId'});
      await t.pumpAndSettle();
      expect(
        h.router.routeInformationProvider.value.uri.path,
        '/transactions/$_trxId',
      );
    });
  });
}
