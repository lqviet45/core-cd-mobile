import 'package:core_cd_mobile/features/customer_app/presentation/customer_account.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'customer_harness.dart';

Finder _scrollOf(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    await loadKhFonts();
  });

  test('telUri bỏ khoảng trắng/dấu chấm, giữ + đầu số', () {
    expect(telUri('1900 1234').toString(), 'tel:19001234');
    expect(telUri('+84 28.3822.0000').toString(), 'tel:+842838220000');
  });

  testWidgets('chưa cấu hình số: không có nút gọi ở màn Quên mật khẩu', (
    tester,
  ) async {
    await pumpCustomer(tester, routes: custRoutes());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quên mật khẩu?'),
      200,
      scrollable: _scrollOf(Scaffold),
    );
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gọi hotline'), findsNothing);
  });

  testWidgets('có số: Quên mật khẩu hiện nút và mở tel:', (tester) async {
    final launched = <Uri>[];
    await pumpCustomer(
      tester,
      routes: custRoutes(),
      supportPhone: '1900 1234',
      launcher: (u) async {
        launched.add(u);
        return true;
      },
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quên mật khẩu?'),
      200,
      scrollable: _scrollOf(Scaffold),
    );
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gọi hotline 1900 1234'));
    await tester.pumpAndSettle();
    expect(launched.single.toString(), 'tel:19001234');
  });

  testWidgets(
    'có số: màn Tài khoản có dòng Hotline; mở được thì không báo lỗi',
    (tester) async {
      final launched = <Uri>[];
      await pumpCustomer(
        tester,
        routes: custRoutes(),
        storedToken: 'R',
        prefs: {'kh.biometric_unlock': false},
        supportPhone: '1900 1234',
        launcher: (u) async {
          launched.add(u);
          return false; // máy không có trình quay số
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Hotline hỗ trợ'),
        200,
        scrollable: _scrollOf(CustomerAccountScreen),
      );
      await tester.tap(find.text('Hotline hỗ trợ'));
      await tester.pumpAndSettle();
      expect(launched, hasLength(1));
      // Không mở được → báo số để khách tự gọi.
      expect(find.textContaining('Hãy gọi 1900 1234'), findsOneWidget);
    },
  );
}
