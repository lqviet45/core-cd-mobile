import 'package:core_cd_mobile/core/auth/auth_models.dart';
import 'package:core_cd_mobile/features/admin/data/admin_repository.dart';
import 'package:core_cd_mobile/features/admin/presentation/audit_screen.dart';
import 'package:core_cd_mobile/features/admin/presentation/rates_screen.dart';
import 'package:core_cd_mobile/features/admin/presentation/users_screen.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

const _me = 'c7b9e9ad-5683-40ca-a536-1df8f9f6c678';

Map<String, Object?> _user({
  String id = 'u2',
  String username = 'lan.nguyen',
  String name = 'Nguyễn Thị Lan',
  String role = 'Operator',
  bool active = true,
}) => {
  'id': id,
  'username': username,
  'fullName': name,
  'role': role,
  'isActive': active,
  'lastLoginAt': '2026-10-13T06:10:37Z',
  'createdAt': '2026-10-13T02:50:20Z',
};

Map<String, Object?> _page(List<Object?> items) => {
  'items': items,
  'pageNumber': 1,
  'pageSize': 20,
  'totalCount': items.length,
  'totalPages': 1,
  'hasPreviousPage': false,
  'hasNextPage': false,
};

Map<String, Object?> _rate({
  String id = 'r1',
  bool active = true,
  double percent = 5.5,
}) => {
  'id': id,
  'termName': '3 tháng',
  'termDays': 91,
  'annualRate': percent / 100,
  'annualRatePercent': percent,
  'paymentMethod': 'AtMaturity',
  'paymentMethodName': 'Trả cuối kỳ',
  'isActive': active,
  'effectiveFrom': '2024-01-01T00:00:00Z',
  'effectiveTo': null,
  'description': 'ghi chú',
  'createdAt': '2026-10-13T06:40:26Z',
};

Map<String, FakeHandler> _routes({
  FakeHandler? users,
  FakeHandler? putUser,
  FakeHandler? postUser,
  FakeHandler? rates,
  FakeHandler? putRate,
  FakeHandler? postRate,
  FakeHandler? deleteRate,
}) => {
  'GET /api/users':
      users ??
      (_) => ok(
        _page([
          _user(
            id: _me,
            username: 'admin',
            name: 'Quản trị viên',
            role: 'Admin',
          ),
          _user(),
          _user(
            id: 'u3',
            username: 'old.user',
            name: 'Trần Văn Cũ',
            role: 'Viewer',
            active: false,
          ),
        ]),
      ),
  'PUT /api/users/u2': putUser ?? (_) => ok(null),
  'PUT /api/users/$_me': (_) => ok(null),
  'POST /api/users': postUser ?? (_) => ok(null),
  'POST /api/users/u2/reset-password': (_) => ok(null),
  'GET /api/audit-logs': (_) => ok(fixture('audit_page')),
  'GET /api/interest-rate-policies':
      rates ??
      (_) => ok(_page([_rate(), _rate(id: 'r2', active: false, percent: 4)])),
  'PUT /api/interest-rate-policies/r1': putRate ?? (_) => ok(null),
  'POST /api/interest-rate-policies': postRate ?? (_) => ok(null),
  'DELETE /api/interest-rate-policies/r1': deleteRate ?? (_) => ok(null),
};

final _sheetFields = find.descendant(
  of: find.byType(UserFormSheet),
  matching: find.byType(TextField),
);
final _dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> _tall(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(390, 2000));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('DTO theo payload thật', () {
    test('người dùng, nhật ký, chính sách lãi suất', () {
      final u = fixtureMap('users_page')['items'] as List;
      expect(u, isNotEmpty);
      final r = fixtureMap('rates_page')['items'] as List;
      expect(r, isNotEmpty);
      expect(fixtureMap('audit_page')['items'], isNotEmpty);
    });
  });

  group('Tab Thêm', () {
    testWidgets('Admin thấy mục Quản trị và Chính sách lãi suất', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more');
      await _tall(t);
      expect(find.text('Chính sách lãi suất'), findsOneWidget);
      expect(find.text('Quản trị (chỉ Admin)'), findsOneWidget);
      expect(find.text('Người dùng'), findsOneWidget);
      expect(find.text('Nhật ký thao tác'), findsOneWidget);
    });

    for (final role in ['Operator', 'Viewer']) {
      testWidgets(
        '$role thấy chính sách lãi suất nhưng không thấy mục Quản trị',
        (t) async {
          final h = await pumpSignedIn(t, routes: _routes(), role: role);
          await h.go('/more');
          await _tall(t);
          expect(find.text('Chính sách lãi suất'), findsOneWidget);
          expect(find.text('Quản trị (chỉ Admin)'), findsNothing);
          expect(find.text('Người dùng'), findsNothing);
        },
      );
    }

    testWidgets('Operator mở thẳng đường dẫn Admin: bị chặn, không gọi API', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: _routes(), role: 'Operator');
      await h.go('/more/admin/users');
      expect(find.text('Chỉ dành cho quản trị viên'), findsOneWidget);
      await h.go('/more/admin/audit');
      expect(find.text('Chỉ dành cho quản trị viên'), findsOneWidget);
      expect(h.adapter.count('GET /api/users'), 0);
      expect(h.adapter.count('GET /api/audit-logs'), 0);
    });
  });

  group('Người dùng', () {
    testWidgets('hiện danh sách, đánh dấu bản thân và tài khoản vô hiệu', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
      expect(find.textContaining('@lan.nguyen · Nghiệp vụ'), findsOneWidget);
      expect(find.textContaining('· bạn'), findsOneWidget);
      expect(find.text('Vô hiệu'), findsOneWidget);
    });

    testWidgets('lọc theo vai trò gửi đúng tham số', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.text('Quản trị').first);
      await t.pumpAndSettle();
      expect(
        h.requestsOf('GET /api/users').last.queryParameters['role'],
        'Admin',
      );
    });

    testWidgets('sửa: xác thực sinh trắc rồi PUT đúng nội dung', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.text('Nguyễn Thị Lan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chỉ xem').last);
      await t.pumpAndSettle();
      final before = h.bio.prompts;
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.bio.prompts, before + 1);
      expect(h.bodiesOf('PUT /api/users/u2').single, {
        'id': 'u2',
        'fullName': 'Nguyễn Thị Lan',
        'role': 'Viewer',
        'isActive': true,
      });
    });

    testWidgets('xác thực sinh trắc hỏng: không gửi gì', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.text('Nguyễn Thị Lan'));
      await t.pumpAndSettle();
      h.bio.passes = false;
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.adapter.count('PUT /api/users/u2'), 0);
      expect(
        find.text('Xác thực không thành công. Lệnh chưa được gửi.'),
        findsOneWidget,
      );
    });

    testWidgets('không tự đổi vai trò/vô hiệu hoá chính mình', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.textContaining('· bạn'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .onSelectionChanged,
        isNull,
      );
      expect(
        find.text('Bạn không thể đổi vai trò hoặc vô hiệu hoá chính mình.'),
        findsOneWidget,
      );
      expect(find.text('Đặt lại mật khẩu'), findsNothing);
    });

    testWidgets('thêm: kiểm tra phía máy, rồi POST với đủ trường', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.byTooltip('Thêm người dùng'));
      await _tall(t);
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.adapter.count('POST /api/users'), 0);
      expect(find.text('Họ và tên không được trống.'), findsOneWidget);

      final f = _sheetFields;
      await t.enterText(f.at(0), 'a b');
      await t.enterText(f.at(1), 'Lê Văn Bình');
      await t.enterText(f.at(2), 'yeu');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.adapter.count('POST /api/users'), 0);
      expect(find.textContaining('3–50 ký tự'), findsOneWidget);
      expect(find.text('Tối thiểu 10 ký tự.'), findsOneWidget);

      await t.enterText(f.at(0), 'binh.le');
      await t.enterText(f.at(2), 'MatKhauTam12');
      await t.tap(find.text('Nghiệp vụ').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.bodiesOf('POST /api/users').single, {
        'username': 'binh.le',
        'password': 'MatKhauTam12',
        'fullName': 'Lê Văn Bình',
        'role': 'Operator',
      });
    });

    testWidgets('máy chủ từ chối theo trường (tên trùng): hiện ngay dưới ô', (
      t,
    ) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes(
          postUser: (_) => (
            status: 400,
            body: {
              'title': 'Dữ liệu không hợp lệ',
              'errors': {
                'Username': ['Tên đăng nhập đã tồn tại.'],
              },
            },
          ),
        ),
      );
      await h.go('/more/admin/users');
      await t.tap(find.byTooltip('Thêm người dùng'));
      await _tall(t);
      final f = _sheetFields;
      await t.enterText(f.at(0), 'admin');
      await t.enterText(f.at(1), 'Ai Đó');
      await t.enterText(f.at(2), 'MatKhauTam12');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(find.text('Tên đăng nhập đã tồn tại.'), findsOneWidget);
    });

    testWidgets('đặt lại mật khẩu: chính sách mật khẩu, sinh trắc, POST', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/admin/users');
      await t.tap(find.text('Nguyễn Thị Lan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đặt lại mật khẩu'));
      await t.pumpAndSettle();
      await t.enterText(_dialogField, 'yeu');
      await t.tap(find.text('Đặt lại'));
      await t.pumpAndSettle();
      expect(h.adapter.count('POST /api/users/u2/reset-password'), 0);
      expect(find.text('Tối thiểu 10 ký tự.'), findsOneWidget);

      await t.enterText(_dialogField, 'MatKhauMoi99');
      final before = h.bio.prompts;
      await t.tap(find.text('Đặt lại'));
      await t.pumpAndSettle();
      expect(h.bio.prompts, before + 1);
      expect(h.bodiesOf('POST /api/users/u2/reset-password').single, {
        'newPassword': 'MatKhauMoi99',
      });
    });
  });

  group('Nhật ký thao tác', () {
    test('nhãn lệnh tiếng Việt, lệnh lạ được tách chữ', () {
      expect(auditActionLabel('BuyCertificate'), 'Mua CCTG');
      expect(
        auditActionLabel('SomethingNewHappened'),
        'Something New Happened',
      );
    });

    test('payload hiển thị thụt lề; không phải JSON thì giữ nguyên', () {
      expect(prettyPayload('{"a":1}'), contains('\n  "a": 1'));
      expect(prettyPayload('không phải json'), 'không phải json');
      expect(prettyPayload(null), '—');
    });

    testWidgets(
      'hiện danh sách, lọc 7 ngày gửi tham số from, chi tiết có payload',
      (t) async {
        final h = await pumpSignedIn(t, routes: _routes());
        await h.go('/more/admin/audit');
        expect(find.text('Đổi cài đặt thông báo'), findsWidgets);
        expect(
          h
              .requestsOf('GET /api/audit-logs')
              .single
              .queryParameters
              .containsKey('from'),
          isFalse,
        );

        await t.tap(find.text('7 ngày'));
        await t.pumpAndSettle();
        expect(
          h.requestsOf('GET /api/audit-logs').last.queryParameters['from'],
          isNotNull,
        );

        await t.tap(find.text('Đổi cài đặt thông báo').first);
        await t.pumpAndSettle();
        expect(find.textContaining('MutedTypes'), findsOneWidget);
        expect(
          find.text('Dữ liệu nhạy cảm đã được che ở máy chủ.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Chính sách lãi suất', () {
    test('lãi suất nhập theo %, hợp lệ khi 0 < x < 100', () {
      expect(parseRatePercent('5,5'), Decimal.parse('5.5'));
      expect(parseRatePercent('5.5'), Decimal.parse('5.5'));
      expect(parseRatePercent('0'), isNull);
      expect(parseRatePercent('100'), isNull);
      expect(parseRatePercent('abc'), isNull);
      expect(parseRatePercent('-1'), isNull);
    });

    test('đổi % sang tỷ lệ gửi API không sai số', () {
      expect(AdminRepository.rateFraction(Decimal.parse('5.5')), 0.055);
      expect(AdminRepository.rateFraction(Decimal.parse('7.3')), 0.073);
      expect(AdminRepository.rateFraction(Decimal.parse('0.1')), 0.001);
      expect(
        AdminRepository.rateFraction(Decimal.parse('12.345678')),
        0.12345678,
      );
    });

    testWidgets(
      'mặc định chỉ lấy chính sách đang áp dụng; đổi bộ lọc gửi isActive',
      (t) async {
        final h = await pumpSignedIn(t, routes: _routes());
        await h.go('/more/rates');
        expect(
          h
              .requestsOf('GET /api/interest-rate-policies')
              .single
              .queryParameters['isActive'],
          true,
        );
        await t.tap(find.text('Đã ngừng').first);
        await t.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/interest-rate-policies')
              .last
              .queryParameters['isActive'],
          false,
        );
        await t.ensureVisible(find.text('Tất cả'));
        await t.pumpAndSettle();
        await t.tap(find.text('Tất cả'));
        await t.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/interest-rate-policies')
              .last
              .queryParameters
              .containsKey('isActive'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Operator chỉ xem: không có nút thêm, chạm hàng không mở form',
      (t) async {
        final h = await pumpSignedIn(t, routes: _routes(), role: 'Operator');
        await h.go('/more/rates');
        expect(find.text('5,5%/năm'), findsOneWidget);
        expect(find.byTooltip('Thêm chính sách'), findsNothing);
        await t.tap(find.text('5,5%/năm'));
        await t.pumpAndSettle();
        expect(find.text('Sửa chính sách lãi suất'), findsNothing);
      },
    );

    testWidgets('Admin sửa: sinh trắc rồi PUT với lãi suất dạng tỷ lệ', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/rates');
      await t.tap(find.text('5,5%/năm'));
      await t.pumpAndSettle();
      await t.binding.setSurfaceSize(const Size(390, 2000));
      await t.pumpAndSettle();
      final rate = find.widgetWithText(TextField, 'Lãi suất năm');
      await t.enterText(rate, '6,25');
      final before = h.bio.prompts;
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.bio.prompts, before + 1);
      final body =
          h.bodiesOf('PUT /api/interest-rate-policies/r1').single as Map;
      expect(body['id'], 'r1');
      expect(body['annualRate'], 0.0625);
      expect(body['termDays'], 91);
      expect(body['paymentMethod'], 'AtMaturity');
      expect(body['effectiveFrom'], '2024-01-01T00:00:00.000Z');
      expect(body['effectiveTo'], isNull);
    });

    testWidgets('lãi suất ngoài khoảng bị chặn ngay, không gửi', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/rates');
      await t.tap(find.byTooltip('Thêm chính sách'));
      await t.pumpAndSettle();
      await t.binding.setSurfaceSize(const Size(390, 2000));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Tên kỳ hạn (vd 12 tháng)'),
        '12 tháng',
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Số ngày kỳ hạn'),
        '365',
      );
      await t.enterText(find.widgetWithText(TextField, 'Lãi suất năm'), '150');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(h.adapter.count('POST /api/interest-rate-policies'), 0);
      expect(
        find.text('Lãi suất phải lớn hơn 0% và nhỏ hơn 100%.'),
        findsOneWidget,
      );
      expect(find.text('Chọn ngày bắt đầu hiệu lực.'), findsOneWidget);
    });

    testWidgets('ngừng áp dụng: hỏi lại, sinh trắc, DELETE', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/rates');
      await t.tap(find.text('5,5%/năm'));
      await t.pumpAndSettle();
      await t.binding.setSurfaceSize(const Size(390, 2000));
      await t.pumpAndSettle();
      await t.tap(find.text('Ngừng áp dụng').first);
      await t.pumpAndSettle();
      expect(find.text('Ngừng áp dụng chính sách?'), findsOneWidget);
      await t.tap(find.text('Huỷ'));
      await t.pumpAndSettle();
      expect(h.adapter.count('DELETE /api/interest-rate-policies/r1'), 0);

      await t.tap(find.text('Ngừng áp dụng').first);
      await t.pumpAndSettle();
      final before = h.bio.prompts;
      await t.tap(find.text('Ngừng áp dụng').last);
      await t.pumpAndSettle();
      expect(h.bio.prompts, before + 1);
      expect(h.adapter.count('DELETE /api/interest-rate-policies/r1'), 1);
    });
  });

  testWidgets('Role enum khớp mã backend', (t) async {
    expect(
      [for (final r in Role.values) r.code],
      ['Viewer', 'Operator', 'Admin'],
    );
  });
}
