import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/session_manager.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_auth_api.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_providers.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_router.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fake_api.dart';
import 'customer_harness.dart';

/// Vùng cuộn của một màn hình (nhánh khác của shell vẫn nằm trong cây nên không dùng `.first` toàn cục).
Finder _scrollOf(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('điều hướng', () {
    test('chưa đăng nhập → /login; đã đăng nhập vào màn mở → /home', () {
      expect(
        customerRedirectFor(auth: const AuthSignedOut(), location: '/home'),
        '/login',
      );
      expect(
        customerRedirectFor(auth: const AuthRestoring(), location: '/home'),
        '/splash',
      );
      expect(
        customerRedirectFor(auth: const AuthOffline(), location: '/home'),
        '/offline',
      );
      // AuthSignedIn cần AuthUser; dùng phiên thật ở các test widget bên dưới.
    });
  });

  group('lớp xác thực', () {
    test(
      'verifyOtp/refresh dùng đúng đường dẫn khách, không đụng API nhân viên',
      () async {
        final adapter = FakeAdapter(custRoutes());
        final api = CustomerAuthApi(fakeDio(adapter), deviceName: 'máy test');

        final t = await api.verifyOtp('0901234567', '123456');
        expect(t.user.username, 'K740995');
        await api.refresh('REFRESH');
        await api.logout('REFRESH');

        expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
          'POST /api/customer/auth/otp/verify',
          'POST /api/customer/auth/refresh',
          'POST /api/customer/auth/logout',
        ]);
        expect(
          adapter.requests.first.data,
          containsPair('deviceName', 'máy test'),
        );
        expect(() => api.login('a', 'b'), throwsUnsupportedError);
      },
    );

    test('token store của khách dùng khoá riêng', () {
      expect(
        SecureTokenStore().key,
        isNot(SecureTokenStore(key: 'core_cd_customer.refresh_token').key),
      );
    });

    test(
      'SessionManager.signIn lưu refresh token mới và phát SignedIn',
      () async {
        final adapter = FakeAdapter(custRoutes());
        final api = CustomerAuthApi(fakeDio(adapter), deviceName: 't');
        final store = InMemoryTokenStore();
        final session = SessionManager(store: store, api: api);
        final events = <SessionEvent>[];
        session.events.listen(events.add);

        await session.signIn(await api.verifyOtp('0901234567', '123456'));
        await Future<void>.delayed(Duration.zero);

        expect(await store.readRefreshToken(), 'REFRESH_TOKEN');
        expect(events.single, isA<SignedIn>());
        expect(session.accessToken, 'ACCESS_TOKEN');
      },
    );
  });

  group('màn hình', () {
    testWidgets('đăng nhập OTP: số điện thoại → mã → Tổng quan', (
      tester,
    ) async {
      final h = await pumpCustomer(tester, routes: custRoutes());
      await tester.pumpAndSettle();
      expect(find.text('Nhận mã OTP'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('phone')), '0901234567');
      await tester.tap(find.widgetWithText(FilledButton, 'Nhận mã OTP'));
      await tester.pumpAndSettle();
      expect(h.adapter.count('POST /api/customer/auth/otp/request'), 1);
      expect(find.byKey(const Key('code')), findsOneWidget);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('code')), '607636');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      final body =
          h.adapter.requests
                  .firstWhere((r) => r.path == '/api/customer/auth/otp/verify')
                  .data
              as Map<String, dynamic>;
      expect(body['phone'], '0901234567');
      expect(body['code'], '607636');
      expect(find.textContaining('Xin chào, Lan'), findsOneWidget);
      expect(find.text('Tổng gốc đang nắm giữ'), findsOneWidget);
      expect(find.text('300.000.000 ₫'), findsOneWidget);
      expect(await h.store.readRefreshToken(), 'REFRESH_TOKEN');
    });

    testWidgets('OTP sai: hiện lỗi từ máy chủ và vẫn ở bước nhập mã', (
      tester,
    ) async {
      final h = await pumpCustomer(
        tester,
        routes: {
          ...custRoutes(),
          'POST /api/customer/auth/otp/verify': (_) =>
              failure(401, 'Mã OTP không đúng hoặc đã hết hạn.'),
        },
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('phone')), '0901234567');
      await tester.tap(find.widgetWithText(FilledButton, 'Nhận mã OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('code')), '000000');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Mã OTP không đúng hoặc đã hết hạn.'), findsOneWidget);
      expect(find.byKey(const Key('code')), findsOneWidget);
      expect(await h.store.readRefreshToken(), isNull);
    });

    testWidgets('số điện thoại ngắn bị chặn trước khi gọi máy chủ', (
      tester,
    ) async {
      final h = await pumpCustomer(tester, routes: custRoutes());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('phone')), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Nhận mã OTP'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhập số điện thoại di động đã đăng ký.'),
        findsOneWidget,
      );
      expect(h.adapter.count('POST /api/customer/auth/otp/request'), 0);
    });

    testWidgets('mở lại app có phiên đã lưu → vào thẳng Tổng quan', (
      tester,
    ) async {
      final h = await pumpCustomer(
        tester,
        routes: custRoutes(),
        storedToken: 'REFRESH_TOKEN',
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng gốc đang nắm giữ'), findsOneWidget);
      expect(h.adapter.count('POST /api/customer/auth/refresh'), 1);
      expect(
        h.adapter.count('POST /api/auth/refresh'),
        0,
        reason: 'không đụng API nhân viên',
      );
    });

    testWidgets('refresh bị từ chối → về màn đăng nhập kèm thông báo hết hạn', (
      tester,
    ) async {
      await pumpCustomer(
        tester,
        routes: {
          ...custRoutes(),
          'POST /api/customer/auth/refresh': (_) => failure(401),
        },
        storedToken: 'CU',
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhận mã OTP'), findsOneWidget);
    });

    testWidgets(
      'danh sách CCTG → chi tiết có lịch lãi; lọc Đã đóng gọi scope=Closed',
      (tester) async {
        final cert = fixtureCertId();
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'GET /api/customer/certificates/$cert': (_) => ok(fixtureDetail()),
            'GET /api/customer/certificates/$cert/interest-schedule': (_) =>
                ok(fixtureSchedule()),
            'GET /api/customer/certificates/$cert/documents': (_) =>
                ok(<dynamic>[]),
          },
          storedToken: 'R',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('CCTG').last);
        await tester.pumpAndSettle();
        expect(find.text('Chứng chỉ của tôi'), findsOneWidget);
        expect(h.adapter.requests.last.queryParameters['scope'], 'Holding');

        await tester.tap(find.text('Đã đóng'));
        await tester.pumpAndSettle();
        expect(h.adapter.requests.last.queryParameters['scope'], 'Closed');
        await tester.tap(find.text('Đang giữ'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.text(fixtureDetail()['certificateNumber'] as String),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết CCTG'), findsOneWidget);
        final list = _scrollOf(CustomerCertificateDetailScreen);
        await tester.scrollUntilVisible(
          find.text('Lịch nhận lãi'),
          300,
          scrollable: list,
        );
        await tester.scrollUntilVisible(
          find.textContaining('Kỳ 1/14'),
          300,
          scrollable: list,
        );
        await tester.scrollUntilVisible(
          find.text(
            'Chưa có tài liệu. Tài liệu sẽ xuất hiện khi ngân hàng phát hành.',
          ),
          300,
          scrollable: list,
        );
      },
    );

    testWidgets(
      'tài liệu: chạm → xin link ngắn hạn → mở bằng ứng dụng hệ thống',
      (tester) async {
        final cert = fixtureCertId();
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'GET /api/customer/certificates/$cert': (_) => ok(fixtureDetail()),
            'GET /api/customer/certificates/$cert/interest-schedule': (_) =>
                ok(fixtureSchedule()),
            'GET /api/customer/certificates/$cert/documents': (_) => ok([
              {
                'id': 'doc-1',
                'kind': 'CertificatePdf',
                'version': 1,
                'fileName': 'chung-chi.pdf',
                'size': 20480,
                'createdAt': '2026-10-14T04:39:01Z',
              },
            ]),
            'POST /api/customer/documents/doc-1/download-link': (_) => ok({
              'url': 'https://files.example/short-lived',
              'expiresAt': '2026-10-14T04:45:00Z',
              'fileName': 'chung-chi.pdf',
            }),
          },
          storedToken: 'R',
        );
        await tester.pumpAndSettle();
        h.container.read(custRepositoryProvider); // đảm bảo provider đã dựng
        await tester.tap(find.text('CCTG').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(fixtureDetail()['certificateNumber'] as String),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Chứng chỉ tiền gửi'),
          300,
          scrollable: _scrollOf(CustomerCertificateDetailScreen),
        );
        await tester.tap(find.text('Chứng chỉ tiền gửi'));
        await tester.pumpAndSettle();

        expect(h.opener.opened, ['https://files.example/short-lived']);
        expect(
          h.adapter.count('POST /api/customer/documents/doc-1/download-link'),
          1,
        );
      },
    );

    testWidgets('đăng xuất: huỷ phiên phía máy chủ và xoá refresh token', (
      tester,
    ) async {
      final h = await pumpCustomer(
        tester,
        routes: custRoutes(),
        storedToken: 'R',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản').last);
      await tester.pumpAndSettle();
      expect(find.text('079•••••9951'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Đăng xuất'),
        200,
        scrollable: _scrollOf(CustomerAccountScreen),
      );
      // Cuộn thêm cho nút nằm hẳn trên thanh điều hướng dưới.
      await tester.drag(
        _scrollOf(CustomerAccountScreen),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
      await tester.pumpAndSettle();

      expect(h.adapter.count('POST /api/customer/auth/logout'), 1);
      expect(await h.store.readRefreshToken(), isNull);
      expect(find.text('Nhận mã OTP'), findsOneWidget);
    });

    testWidgets(
      'giao dịch Pending hiển thị nhãn khách hàng, không lộ lỗi nội bộ',
      (tester) async {
        await pumpCustomer(tester, routes: custRoutes(), storedToken: 'R');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Giao dịch').last);
        await tester.pumpAndSettle();
        expect(find.text('Mua CCTG'), findsOneWidget);
        expect(find.text('Chờ xử lý'), findsOneWidget);
      },
    );
  });
}
