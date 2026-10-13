import 'package:core_cd_mobile/app.dart';
import 'package:core_cd_mobile/core/auth/auth_api.dart';
import 'package:core_cd_mobile/core/auth/biometric.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/auth_interceptor.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

class _FakeBiometric implements BiometricAuthenticator {
  _FakeBiometric({this.available = true, this.passes = true});
  final bool available;
  bool passes;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return passes;
  }
}

Map<String, FakeHandler> _routes({bool loginOk = true}) {
  final login = {
    ...fixtureMap('auth_login'),
    'accessTokenExpiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  };
  return {
    'POST /api/auth/login': (_) =>
        loginOk ? ok(login) : failure(401, 'Sai tên đăng nhập hoặc mật khẩu.'),
    'POST /api/auth/refresh': (_) => ok(login),
    'GET /api/dashboard/summary': (_) => ok(fixture('dashboard_summary')),
    'GET /api/reports/upcoming-maturities': (_) =>
        ok(fixture('report_upcoming')),
    'GET /api/notifications/unread-count': (_) => ok({'count': 2}),
  };
}

Future<_FakeBiometric> _pump(
  WidgetTester tester, {
  required Map<String, FakeHandler> routes,
  String? storedToken,
  _FakeBiometric? bio,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final biometric = bio ?? _FakeBiometric();
  final adapter = FakeAdapter(routes);
  final store = InMemoryTokenStore(storedToken);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://fake', envName: 'dev'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        biometricProvider.overrideWithValue(biometric),
        sharedPrefsProvider.overrideWithValue(prefs),
        authApiProvider.overrideWithValue(
          AuthApi(fakeDio(adapter), deviceName: 'test'),
        ),
        dioProvider.overrideWith((ref) {
          final dio = fakeDio(adapter);
          dio.interceptors.add(
            AuthInterceptor(ref.watch(sessionManagerProvider), dio),
          );
          return dio;
        }),
      ],
      child: const CoreCdApp(),
    ),
  );
  return biometric;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  testWidgets('chưa có phiên → màn đăng nhập; sai mật khẩu hiện lỗi', (
    tester,
  ) async {
    await _pump(tester, routes: _routes(loginOk: false));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'sai');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Sai tên đăng nhập hoặc mật khẩu.'), findsOneWidget);
  });

  testWidgets('đăng nhập đúng → Tổng quan, không bị khoá', (tester) async {
    final bio = await _pump(tester, routes: _routes());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'mat-khau-gia');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Xin chào'), findsOneWidget);
    expect(find.text('Dư nợ gốc'), findsOneWidget);
    expect(bio.prompts, 0);
  });

  testWidgets('mở lại app với phiên đã lưu → khoá; xác thực lỗi vẫn khoá, '
      'xác thực đúng thì vào Tổng quan', (tester) async {
    final bio = await _pump(
      tester,
      routes: _routes(),
      storedToken: 'REFRESH_TOKEN',
      bio: _FakeBiometric(passes: false),
    );
    await tester.pumpAndSettle();
    expect(bio.prompts, 1, reason: 'tự hiện hộp thoại xác thực khi khoá');
    expect(find.text('Ứng dụng đã khoá'), findsOneWidget);
    expect(find.text('Dư nợ gốc'), findsNothing, reason: 'không lộ dữ liệu');

    bio.passes = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Mở khoá'));
    await tester.pumpAndSettle();
    expect(bio.prompts, 2);
    expect(find.text('Ứng dụng đã khoá'), findsNothing);
    expect(find.textContaining('Xin chào'), findsOneWidget);
  });

  testWidgets('thiết bị không có khoá màn hình → bỏ qua khoá nhanh', (
    tester,
  ) async {
    await _pump(
      tester,
      routes: _routes(),
      storedToken: 'REFRESH_TOKEN',
      bio: _FakeBiometric(available: false),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Xin chào'), findsOneWidget);
  });

  testWidgets('thanh điều hướng có 5 tab và chuyển được tab', (tester) async {
    await _pump(
      tester,
      routes: {
        ..._routes(),
        'GET /api/certificates': (_) => ok(fixture('certificates_page')),
      },
      storedToken: 'REFRESH_TOKEN',
      bio: _FakeBiometric(available: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await tester.tap(find.text('CCTG').last);
    await tester.pumpAndSettle();
    expect(find.text('Chứng chỉ tiền gửi'), findsOneWidget);
  });
}
