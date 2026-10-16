import 'package:core_cd_mobile/core/auth/auth_models.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/session_manager.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_auth_api.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_account.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_certs.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_providers.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_router.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/kh_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import 'customer_harness.dart';

/// Vùng cuộn của một màn hình (nhánh khác của shell vẫn nằm trong cây nên không dùng `.first` toàn cục).
Finder _scrollOf(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

/// Chip lọc (nhãn trùng với nhãn trạng thái trên thẻ nên phải giới hạn trong dãy chip).
Finder _chip(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is KhChips),
  matching: find.text(label),
);

Future<void> _login(
  WidgetTester tester, {
  String id = '0901234567',
  String password = 'Matkhau#Demo2026',
}) async {
  await tester.enterText(
    find.byKey(const Key('identifier')).descendantTextField,
    id,
  );
  await tester.enterText(
    find.byKey(const Key('password')).descendantTextField,
    password,
  );
  await tester.tap(find.widgetWithText(InkWell, 'Đăng nhập').first);
  await tester.pumpAndSettle();
}

extension on Finder {
  Finder get descendantTextField =>
      find.descendant(of: this, matching: find.byType(TextField));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    await loadKhFonts();
  });

  group('điều hướng', () {
    const user = AuthUser(
      id: 'c',
      username: 'K1',
      fullName: 'A',
      role: Role.viewer,
    );

    test(
      'chưa đăng nhập → /login; đang khôi phục → /splash; mất mạng → /offline',
      () {
        String? r(AuthState a, [String loc = '/home']) => customerRedirectFor(
          auth: a,
          mustChangePassword: false,
          location: loc,
        );
        expect(r(const AuthSignedOut()), '/login');
        expect(r(const AuthRestoring()), '/splash');
        expect(r(const AuthOffline()), '/offline');
        expect(r(const AuthSignedIn(user), '/login'), '/home');
        expect(r(const AuthSignedIn(user), '/certificates'), isNull);
      },
    );

    test('còn mật khẩu tạm → chỉ được ở màn đổi mật khẩu bắt buộc', () {
      String? r(String loc) => customerRedirectFor(
        auth: const AuthSignedIn(user),
        mustChangePassword: true,
        location: loc,
      );
      expect(r('/home'), '/change-password');
      expect(r('/certificate/x'), '/change-password');
      expect(r('/change-password'), isNull);
    });
  });

  group('lớp xác thực', () {
    test('login/refresh/đổi mật khẩu/đăng xuất dùng đúng đường dẫn khách; cờ mustChangePassword theo phản hồi', () async {
      final adapter = FakeAdapter({
        ...custRoutes(),
        'POST /api/customer/auth/login': (_) => ok(custFirstLoginPayload()),
      });
      final api = CustomerAuthApi(fakeDio(adapter), deviceName: 'máy test');

      final t = await api.login('0901234567', 'Tam-1234');
      expect(t.user.username, isNotEmpty);
      expect(api.mustChangePassword, isTrue);
      await api.changePassword(
        accessToken: 'AT',
        currentPassword: 'Tam-1234',
        newPassword: 'Matkhau#Moi2026',
      );
      expect(
        api.mustChangePassword,
        isFalse,
        reason: 'sau khi đổi, phản hồi mới không còn cờ',
      );
      await api.refresh('REFRESH');
      await api.logout('REFRESH');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/customer/auth/login',
        'POST /api/customer/auth/change-password',
        'POST /api/customer/auth/refresh',
        'POST /api/customer/auth/logout',
      ]);
      expect(adapter.requests.first.data, {
        'identifier': '0901234567',
        'password': 'Tam-1234',
        'deviceName': 'máy test',
      });
      expect(adapter.requests[1].headers['Authorization'], 'Bearer AT');
    });

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

        await session.signIn(await api.login('0901234567', 'x'));
        await Future<void>.delayed(Duration.zero);

        expect(await store.readRefreshToken(), 'REFRESH_TOKEN');
        expect(events.single, isA<SignedIn>());
        expect(session.accessToken, 'ACCESS_TOKEN');
      },
    );
  });

  group('đăng nhập', () {
    testWidgets(
      'SĐT/CIF + mật khẩu → Trang chủ đúng thiết kế K02 (hero, sắp tới, CCTG của tôi)',
      (tester) async {
        final h = await pumpCustomer(tester, routes: custRoutes());
        await tester.pumpAndSettle();
        expect(
          find.text('Tiền gửi của bạn,\nrõ ràng trong tầm tay.'),
          findsOneWidget,
        );
        expect(
          find.text('Đăng nhập bằng vân tay / Face ID'),
          findsNothing,
          reason: 'chưa có phiên đã lưu',
        );

        await _login(tester, id: 'K945094');
        final body =
            h.requestsOf('POST /api/customer/auth/login').single.data
                as Map<String, dynamic>;
        expect(body['identifier'], 'K945094');
        expect(body['password'], 'Matkhau#Demo2026');

        expect(find.textContaining('Xin chào, Lan'), findsOneWidget);
        expect(find.text('Tổng tiền đang gửi'), findsOneWidget);
        expect(find.text('330.000.000 ₫'), findsOneWidget);
        expect(find.text('3 chứng chỉ đang gửi'), findsOneWidget);
        expect(find.text('Lãi dự kiến cả kỳ'), findsOneWidget);
        expect(find.text('Nhận 30 ngày tới'), findsOneWidget);
        expect(find.text('Sắp tới'), findsOneWidget);
        expect(find.text('CCTG của tôi'), findsOneWidget);
        expect(await h.store.readRefreshToken(), 'REFRESH_TOKEN');
        expect(
          h.prefs.getBool('kh.biometric_unlock'),
          isTrue,
          reason: 'lần đầu tự bật mở khoá sinh trắc nếu thiết bị hỗ trợ',
        );
      },
    );

    testWidgets(
      'sai mật khẩu hiện thông điệp của máy chủ; ô trống bị chặn trước khi gọi',
      (tester) async {
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'POST /api/customer/auth/login': (_) => failure(
              401,
              'Thông tin đăng nhập không đúng, hoặc tài khoản đang bị khóa tạm thời.',
            ),
          },
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(InkWell, 'Đăng nhập').first);
        await tester.pumpAndSettle();
        expect(
          find.text('Nhập số điện thoại hoặc mã khách hàng và mật khẩu.'),
          findsOneWidget,
        );
        expect(h.requestsOf('POST /api/customer/auth/login'), isEmpty);

        await _login(tester, password: 'sai');
        expect(
          find.text(
            'Thông tin đăng nhập không đúng, hoặc tài khoản đang bị khóa tạm thời.',
          ),
          findsOneWidget,
        );
        expect(await h.store.readRefreshToken(), isNull);
      },
    );

    testWidgets('429 hiện thông điệp chờ một phút', (tester) async {
      await pumpCustomer(
        tester,
        routes: {
          ...custRoutes(),
          'POST /api/customer/auth/login': (_) => failure(429),
        },
      );
      await tester.pumpAndSettle();
      await _login(tester);
      expect(
        find.text('Thử đăng nhập quá nhiều lần. Vui lòng chờ một phút.'),
        findsOneWidget,
      );
    });

    testWidgets('Quên mật khẩu: hướng dẫn đến quầy (không có SMS/OTP)', (
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
      expect(find.textContaining('đến chi nhánh'), findsOneWidget);
    });

    testWidgets(
      'mật khẩu tạm: bị đưa tới màn tạo mật khẩu mới; yếu/không khớp bị chặn; đổi xong vào Trang chủ',
      (tester) async {
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'POST /api/customer/auth/login': (_) => ok(custFirstLoginPayload()),
          },
        );
        await tester.pumpAndSettle();
        await _login(tester, password: 'Tam-Pass-1');
        // Router buộc sang màn đổi mật khẩu; chưa gọi bất kỳ API dữ liệu nào.
        expect(find.text('Tạo mật khẩu mới'), findsOneWidget);
        expect(h.requestsOf('GET /api/customer/summary'), isEmpty);

        Future<void> fill(String cur, String next, String again) async {
          await tester.enterText(
            find.byKey(const Key('current')).descendantTextField,
            cur,
          );
          await tester.enterText(
            find.byKey(const Key('new')).descendantTextField,
            next,
          );
          await tester.enterText(
            find.byKey(const Key('confirm')).descendantTextField,
            again,
          );
          await tester.tap(find.widgetWithText(InkWell, 'Lưu mật khẩu').first);
          await tester.pumpAndSettle();
        }

        await fill('Tam-Pass-1', 'yeu', 'yeu');
        expect(find.text('Mật khẩu tối thiểu 10 ký tự.'), findsOneWidget);
        await fill('Tam-Pass-1', 'Matkhau#Moi2026', 'khac-hoan-toan');
        expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
        expect(
          h.requestsOf('POST /api/customer/auth/change-password'),
          isEmpty,
        );

        await fill('Tam-Pass-1', 'Matkhau#Moi2026', 'Matkhau#Moi2026');
        final sent = h
            .requestsOf('POST /api/customer/auth/change-password')
            .single;
        expect((sent.data as Map)['newPassword'], 'Matkhau#Moi2026');
        expect(sent.headers['Authorization'], startsWith('Bearer '));
        expect(find.textContaining('Xin chào, Lan'), findsOneWidget);
      },
    );

    testWidgets(
      'mở lại app có phiên đã lưu (không bật sinh trắc) → vào thẳng Trang chủ',
      (tester) async {
        final h = await pumpCustomer(
          tester,
          routes: custRoutes(),
          storedToken: 'REFRESH_TOKEN',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        expect(find.text('Tổng tiền đang gửi'), findsOneWidget);
        expect(h.requestsOf('POST /api/customer/auth/refresh'), hasLength(1));
        expect(
          h.requestsOf('POST /api/auth/refresh'),
          isEmpty,
          reason: 'không đụng API nhân viên',
        );
        expect(h.bio.prompts, 0);
      },
    );

    testWidgets(
      'bật sinh trắc: mở lại app phải xác thực; thất bại thì ở màn đăng nhập, thành công thì vào Trang chủ',
      (tester) async {
        final bio = FakeBio(passes: false);
        final h = await pumpCustomer(
          tester,
          routes: custRoutes(),
          storedToken: 'REFRESH_TOKEN',
          prefs: {'kh.biometric_unlock': true},
          bio: bio,
        );
        await tester.pumpAndSettle();
        expect(bio.prompts, 1, reason: 'tự hiện hộp thoại xác thực khi mở app');
        expect(find.text('Đăng nhập bằng vân tay / Face ID'), findsOneWidget);
        expect(
          find.text(
            'Chưa xác thực được. Hãy thử lại hoặc đăng nhập bằng mật khẩu.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Tổng tiền đang gửi'),
          findsNothing,
          reason: 'chưa lộ dữ liệu',
        );
        expect(
          h.requestsOf('POST /api/customer/auth/refresh'),
          isEmpty,
          reason: 'chưa làm mới phiên khi chưa xác thực',
        );

        bio.passes = true;
        await tester.tap(find.text('Đăng nhập bằng vân tay / Face ID'));
        await tester.pumpAndSettle();
        expect(find.text('Tổng tiền đang gửi'), findsOneWidget);
        expect(h.requestsOf('POST /api/customer/auth/refresh'), hasLength(1));
      },
    );

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
        prefs: {'kh.biometric_unlock': false},
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        findsOneWidget,
      );
    });
  });

  group('màn hình', () {
    testWidgets(
      'K03: danh sách CCTG, chip lọc gửi đúng scope, thẻ đã tất toán hiện số đã nhận',
      (tester) async {
        final h = await pumpCustomer(
          tester,
          routes: custRoutes(),
          storedToken: 'R',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('CCTG').last);
        await tester.pumpAndSettle();
        expect(find.text('CCTG của tôi'), findsWidgets);
        expect(find.text('3 đang gửi · 1 đã tất toán'), findsOneWidget);
        expect(
          h
              .requestsOf('GET /api/customer/certificates')
              .last
              .queryParameters['scope'],
          'All',
        );

        await tester.tap(_chip('Đang gửi'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/certificates')
              .last
              .queryParameters['scope'],
          'Active',
        );
        await tester.tap(_chip('Sắp đáo hạn'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/certificates')
              .last
              .queryParameters['scope'],
          'NearMaturity',
        );
        await tester.ensureVisible(_chip('Đã tất toán'));
        await tester.pumpAndSettle();
        await tester.tap(_chip('Đã tất toán'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/certificates')
              .last
              .queryParameters['scope'],
          'Closed',
        );
        expect(find.textContaining('Tất toán '), findsOneWidget);
        expect(find.textContaining('đã nhận'), findsOneWidget);
      },
    );

    testWidgets(
      'K04: chi tiết có lịch nhận lãi (thu gọn/xem hết) và nút Hợp đồng',
      (tester) async {
        final cert = fixtureMap('customer/certificate_detail');
        final id = cert['id'] as String;
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'GET /api/customer/certificates/$id': (_) => ok(cert),
            'GET /api/customer/certificates/$id/interest-schedule': (_) =>
                ok(fixture('customer/interest_schedule_monthly')),
            'GET /api/customer/certificates/$id/documents': (_) =>
                ok(<dynamic>[]),
          },
          storedToken: 'R',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        h.container.read(custRepositoryProvider);
        await tester.tap(find.text('CCTG').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(cert['certificateNumber'] as String));
        await tester.pumpAndSettle();

        expect(find.text('Chi tiết CCTG'), findsOneWidget);
        final list = _scrollOf(CustomerCertificateDetailScreen);
        await tester.scrollUntilVisible(
          find.text('Lịch nhận lãi'),
          300,
          scrollable: list,
        );
        final periods =
            (fixtureMap('customer/interest_schedule_monthly')['periods']
                    as List<dynamic>)
                .length;
        expect(find.textContaining('Kỳ 1/$periods'), findsOneWidget);
        expect(
          find.textContaining('Kỳ 4/$periods'),
          findsNothing,
          reason: 'mặc định thu gọn 3 kỳ',
        );
        await tester.tap(find.text('Xem $periods kỳ'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Kỳ 4/$periods'),
          300,
          scrollable: list,
        );

        // Không có tài liệu → báo, không lỗi.
        await tester.tap(find.text('Hợp đồng'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa có hợp đồng'), findsOneWidget);
      },
    );

    testWidgets('K04: Hợp đồng — một tài liệu mở thẳng bằng link ngắn hạn', (
      tester,
    ) async {
      final cert = fixtureMap('customer/certificate_detail');
      final id = cert['id'] as String;
      final h = await pumpCustomer(
        tester,
        routes: {
          ...custRoutes(),
          'GET /api/customer/certificates/$id': (_) => ok(cert),
          'GET /api/customer/certificates/$id/interest-schedule': (_) =>
              ok(fixture('customer/interest_schedule_monthly')),
          'GET /api/customer/certificates/$id/documents': (_) => ok([
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
        prefs: {'kh.biometric_unlock': false},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CCTG').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(cert['certificateNumber'] as String));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hợp đồng'));
      await tester.pumpAndSettle();

      expect(h.opener.opened, ['https://files.example/short-lived']);
      expect(
        h.requestsOf('POST /api/customer/documents/doc-1/download-link'),
        hasLength(1),
      );
    });

    testWidgets(
      'K05: Lịch nhận tiền lọc 30/90 ngày/cả năm và nhóm theo tháng',
      (tester) async {
        await pumpCustomer(
          tester,
          routes: custRoutes(),
          storedToken: 'R',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lịch').last);
        await tester.pumpAndSettle();
        expect(find.text('Lịch nhận tiền'), findsOneWidget);
        expect(find.text('Sẽ nhận trong 30 ngày tới'), findsOneWidget);
        expect(
          find.text('1 khoản'),
          findsOneWidget,
          reason: '30 ngày tới: chỉ CCTG sắp đáo hạn',
        );
        expect(find.textContaining('Đáo hạn CCTG'), findsOneWidget);

        await tester.tap(find.text('90 ngày'));
        await tester.pumpAndSettle();
        expect(find.text('Sẽ nhận trong 90 ngày tới'), findsOneWidget);
        expect(find.text('3 khoản'), findsOneWidget);

        await tester.tap(find.text('Cả năm'));
        await tester.pumpAndSettle();
        expect(find.text('Sẽ nhận trong 12 tháng tới'), findsOneWidget);
        expect(find.text('4 khoản'), findsOneWidget);
        expect(
          find.textContaining(RegExp(r'^Tháng \d{1,2}/\d{4}$')),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'K06: Giao dịch lọc Tiền vào/ra gửi direction; hàng mở chi tiết giao dịch',
      (tester) async {
        final trx = fixtureMap('customer/transaction_detail');
        final id = trx['id'] as String;
        final h = await pumpCustomer(
          tester,
          routes: {
            ...custRoutes(),
            'GET /api/customer/transactions/$id': (_) => ok(trx),
            'GET /api/customer/transactions/$id/documents': (_) =>
                ok(<dynamic>[]),
          },
          storedToken: 'R',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tài khoản').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Lịch sử giao dịch'),
          200,
          scrollable: _scrollOf(CustomerAccountScreen),
        );
        await tester.drag(
          _scrollOf(CustomerAccountScreen),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lịch sử giao dịch'));
        await tester.pumpAndSettle();

        expect(find.text('Giao dịch'), findsOneWidget);
        expect(find.text('Mua CCTG'), findsOneWidget);
        expect(
          find.textContaining('−20.000.000 ₫'),
          findsOneWidget,
          reason: 'mua = tiền ra, dấu trừ',
        );
        expect(
          find.text('Đang xử lý', skipOffstage: false),
          findsNothing,
          reason: 'ghi chú trạng thái nằm trong phụ đề',
        );
        expect(find.textContaining('Đang xử lý'), findsOneWidget);
        expect(
          find.textContaining(RegExp(r'^Tháng \d{1,2}/\d{4}$')),
          findsOneWidget,
        );

        await tester.tap(find.text('Tiền ra'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/transactions')
              .last
              .queryParameters['direction'],
          'Out',
        );
        await tester.tap(find.text('Tiền vào'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/transactions')
              .last
              .queryParameters['direction'],
          'In',
        );
        await tester.tap(find.text('Tất cả'));
        await tester.pumpAndSettle();
        expect(
          h
              .requestsOf('GET /api/customer/transactions')
              .last
              .queryParameters
              .containsKey('direction'),
          isFalse,
        );

        await tester.tap(find.text('Mua CCTG'));
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết giao dịch'), findsOneWidget);
        expect(find.text(trx['trxNo'] as String), findsOneWidget);
        expect(
          find.text(
            'Chưa có tài liệu. Tài liệu sẽ xuất hiện khi ngân hàng phát hành.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'K08: Tài khoản — hồ sơ che, bật/tắt sinh trắc, đăng xuất huỷ phiên',
      (tester) async {
        final h = await pumpCustomer(
          tester,
          routes: custRoutes(),
          storedToken: 'R',
          prefs: {'kh.biometric_unlock': false},
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tài khoản').last);
        await tester.pumpAndSettle();

        expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
        expect(find.textContaining('Mã khách hàng K'), findsOneWidget);
        expect(find.text('090•••••67'), findsOneWidget);
        expect(find.textContaining('••'), findsWidgets);
        expect(find.text('Đổi mật khẩu'), findsOneWidget);

        // Công tắc sinh trắc: bật cần xác thực đúng một lần; tắt thì lưu ngay.
        final sw = find.byType(Switch);
        await tester.tap(sw);
        await tester.pumpAndSettle();
        expect(h.bio.prompts, 1);
        expect(h.prefs.getBool('kh.biometric_unlock'), isTrue);
        await tester.tap(sw);
        await tester.pumpAndSettle();
        expect(h.prefs.getBool('kh.biometric_unlock'), isFalse);

        await tester.scrollUntilVisible(
          find.text('Đăng xuất'),
          200,
          scrollable: _scrollOf(CustomerAccountScreen),
        );
        await tester.drag(
          _scrollOf(CustomerAccountScreen),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đăng xuất'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất').last);
        await tester.pumpAndSettle();

        expect(h.requestsOf('POST /api/customer/auth/logout'), hasLength(1));
        expect(await h.store.readRefreshToken(), isNull);
        expect(
          find.text('Tiền gửi của bạn,\nrõ ràng trong tầm tay.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('K09: giao diện tối dựng được và dùng bảng màu tối', (
      tester,
    ) async {
      await pumpCustomer(
        tester,
        routes: custRoutes(),
        storedToken: 'R',
        prefs: {'kh.biometric_unlock': false},
        brightness: Brightness.dark,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng tiền đang gửi'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(
        scaffold.backgroundColor ??
            Theme.of(tester.element(find.byType(Scaffold).first))
                .scaffoldBackgroundColor,
        const Color(0xFF0C1312),
      );
    });

    testWidgets('lỗi tải hiện mã vết và nút Thử lại; thử lại gọi lại API', (
      tester,
    ) async {
      var calls = 0;
      await pumpCustomer(
        tester,
        routes: {
          ...custRoutes(),
          'GET /api/customer/summary': (_) {
            calls++;
            return calls == 1
                ? failure(500, 'Hệ thống đang gặp sự cố.')
                : ok(fixture('customer/summary'));
          },
        },
        storedToken: 'R',
        prefs: {'kh.biometric_unlock': false},
      );
      await tester.pumpAndSettle();
      expect(find.text('Không tải được dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng tiền đang gửi'), findsOneWidget);
    });
  });
}
