import 'dart:async';

import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:core_cd_mobile/core/ui/widgets.dart';
import 'package:core_cd_mobile/features/more/presentation/change_password_screen.dart';
import 'package:core_cd_mobile/features/search/presentation/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';

Finder _switchOf(String title) => find.descendant(
  of: find.widgetWithText(ListRow, title),
  matching: find.byType(Switch),
);

Map<String, FakeHandler> _routes({
  List<Map<String, Object?>>? prefs,
  FakeHandler? putPrefs,
  FakeHandler? changePassword,
}) => {
  'GET /api/auth/sessions': (_) => ok(<Object>[]),
  'GET /api/notifications/preferences': (_) => ok(
    prefs ??
        [
          {'type': 'NearMaturity', 'muted': true},
        ],
  ),
  'PUT /api/notifications/preferences': putPrefs ?? (_) => ok(null),
  'POST /api/auth/change-password': changePassword ?? (_) => ok(null),
  'POST /api/auth/logout': (_) => ok(null),
};

ProviderContainer _c(Harness h) => h.container;

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('Tuỳ chọn trên thiết bị', () {
    testWidgets('lưu và đọc lại đúng giá trị; mặc định an toàn', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      final p = _c(h).read(appPrefsProvider);
      expect(p.themeMode, ThemeMode.system);
      expect(p.lockEnabled, isTrue, reason: 'mặc định phải bật khoá nhanh');
      expect(p.hideAmounts, isFalse);

      final n = _c(h).read(appPrefsProvider.notifier);
      await n.setThemeMode(ThemeMode.dark);
      await n.setLockAfter(const Duration(minutes: 5));
      await n.setHideAmounts(true);
      await t.pumpAndSettle();

      expect(h.prefs.getString('pref.theme'), 'dark');
      expect(h.prefs.getInt('pref.lock_after_secs'), 300);
      expect(h.prefs.getBool('pref.hide_amounts'), isTrue);
      expect(
        t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('khởi động lại: đọc giá trị đã lưu', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes(),
        prefs: {'pref.theme': 'light', 'pref.hide_amounts': true},
      );
      final p = _c(h).read(appPrefsProvider);
      expect(p.themeMode, ThemeMode.light);
      expect(p.hideAmounts, isTrue);
    });

    testWidgets('ẩn số tiền: Tổng quan không lộ số dư nợ', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes(),
        prefs: {'pref.hide_amounts': true},
      );
      await h.go('/home');
      expect(find.text('••••••'), findsWidgets);
    });
  });

  group('Khoá nhanh', () {
    testWidgets('tắt khoá nhanh phải xác thực; xác thực hỏng thì giữ bật', (
      t,
    ) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/account');
      expect(t.widget<Switch>(_switchOf('Khoá nhanh')).value, isTrue);

      h.bio.passes = false;
      final before = h.bio.prompts;
      await t.tap(_switchOf('Khoá nhanh'));
      await t.pumpAndSettle();
      expect(h.bio.prompts, before + 1);
      expect(_c(h).read(appPrefsProvider).lockEnabled, isTrue);

      h.bio.passes = true;
      await t.tap(_switchOf('Khoá nhanh'));
      await t.pumpAndSettle();
      expect(_c(h).read(appPrefsProvider).lockEnabled, isFalse);
      expect(h.prefs.getBool('pref.lock_enabled'), isFalse);

      // Bật lại không cần xác thực thêm.
      final prompts = h.bio.prompts;
      await t.tap(_switchOf('Khoá nhanh'));
      await t.pumpAndSettle();
      expect(h.bio.prompts, prompts);
      expect(_c(h).read(appPrefsProvider).lockEnabled, isTrue);
    });
  });

  group('Thông báo (phía máy chủ)', () {
    testWidgets('hiện đúng trạng thái và gửi danh sách loại bị tắt', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.go('/more/account');
      await t.binding.setSurfaceSize(const Size(390, 2400));
      await t.pumpAndSettle();
      expect(
        t.widget<Switch>(_switchOf('Nhắc CCTG sắp đáo hạn')).value,
        isFalse,
        reason: 'NearMaturity đang bị tắt',
      );
      expect(
        t.widget<Switch>(_switchOf('Cảnh báo giao dịch thất bại')).value,
        isTrue,
      );

      await t.tap(_switchOf('Cảnh báo giao dịch thất bại'));
      await t.pumpAndSettle();
      final body =
          h.bodiesOf('PUT /api/notifications/preferences').single
              as Map<String, dynamic>;
      expect((body['mutedTypes'] as List).toSet(), {
        'NearMaturity',
        'TransactionFailed',
      });
    });

    testWidgets('lỗi lưu → công tắc khôi phục và báo lỗi', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes(putPrefs: (_) => failure(500, 'Lỗi máy chủ')),
      );
      await h.go('/more/account');
      await t.binding.setSurfaceSize(const Size(390, 2400));
      await t.pumpAndSettle();
      await t.tap(_switchOf('Cảnh báo giao dịch thất bại'));
      await t.pumpAndSettle();
      expect(
        t.widget<Switch>(_switchOf('Cảnh báo giao dịch thất bại')).value,
        isTrue,
        reason: 'phải trở về trạng thái bật vì máy chủ chưa lưu',
      );
      expect(find.text('Lỗi máy chủ'), findsOneWidget);
    });
  });

  group('Đổi mật khẩu', () {
    test('chính sách mật khẩu khớp backend', () {
      expect(passwordProblem('Ab1'), isNotNull);
      expect(passwordProblem('abcdefghi1'), contains('chữ hoa'));
      expect(passwordProblem('ABCDEFGHI1'), contains('chữ thường'));
      expect(passwordProblem('Abcdefghij'), contains('chữ số'));
      expect(passwordProblem('Abcdefghi1'), isNull);
    });

    Future<void> fill(
      WidgetTester t,
      String cur,
      String next,
      String again,
    ) async {
      final f = find.byType(TextField);
      await t.enterText(f.at(0), cur);
      await t.enterText(f.at(1), next);
      await t.enterText(f.at(2), again);
      await t.tap(find.text('Lưu mật khẩu mới'));
      await t.pumpAndSettle();
    }

    testWidgets('dữ liệu sai không gọi API', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.push('/more/account/password');
      await fill(t, 'cu', 'yeu', 'khac');
      expect(h.adapter.count('POST /api/auth/change-password'), 0);
      expect(find.text('Tối thiểu 10 ký tự.'), findsOneWidget);
      expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
    });

    testWidgets('thành công: gửi đúng body rồi đóng màn', (t) async {
      final h = await pumpSignedIn(t, routes: _routes());
      await h.push('/more/account/password');
      await fill(t, 'MatKhauCu1', 'MatKhauMoi12', 'MatKhauMoi12');
      expect(h.bodiesOf('POST /api/auth/change-password').single, {
        'currentPassword': 'MatKhauCu1',
        'newPassword': 'MatKhauMoi12',
      });
      expect(find.text('Đổi mật khẩu'), findsNothing);
    });

    testWidgets('máy chủ từ chối mật khẩu hiện tại → hiện lỗi, ở lại màn', (
      t,
    ) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes(
          changePassword: (_) => failure(400, 'Mật khẩu hiện tại không đúng.'),
        ),
      );
      await h.push('/more/account/password');
      await fill(t, 'SaiMatKhau1', 'MatKhauMoi12', 'MatKhauMoi12');
      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsWidgets);
    });
  });

  testWidgets('đăng xuất xoá lịch sử tìm kiếm trên máy', (t) async {
    final h = await pumpSignedIn(t, routes: _routes());
    await _c(h).read(searchHistoryProvider.notifier).add('Nguyễn Văn A');
    expect(h.prefs.getStringList('pref.search_history'), ['Nguyễn Văn A']);

    unawaited(_c(h).read(authControllerProvider.notifier).logout());
    await t.pumpAndSettle();

    expect(_c(h).read(searchHistoryProvider), isEmpty);
    expect(h.prefs.getStringList('pref.search_history'), isNull);
  });

  testWidgets(
    'lỗi tải: hiện ngay trạng thái lỗi, chỉ gọi API một lần (không tự thử lại)',
    (t) async {
      final h = await pumpSignedIn(
        t,
        routes: {
          ..._routes(),
          'GET /api/reports/portfolio': (_) => failure(500, 'Máy chủ lỗi'),
        },
      );
      await h.go('/more/reports');
      expect(find.text('Máy chủ lỗi'), findsWidgets);
      expect(find.text('Thử lại'), findsOneWidget);
      await t.pump(const Duration(seconds: 30));
      expect(h.adapter.count('GET /api/reports/portfolio'), 1);
    },
  );
}
