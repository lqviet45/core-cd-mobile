import 'package:core_cd_mobile/app.dart';
import 'package:core_cd_mobile/core/auth/api_providers.dart';
import 'package:core_cd_mobile/core/auth/auth_api.dart';
import 'package:core_cd_mobile/core/auth/biometric.dart';
import 'package:core_cd_mobile/core/auth/pin_service.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/cache/blob_store.dart';
import 'package:core_cd_mobile/core/cache/encrypted_cache.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/auth_interceptor.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/core/push/push_registrar.dart';
import 'package:core_cd_mobile/core/router/app_router.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:core_cd_mobile/features/documents/presentation/document_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fakes.dart';
import 'fixtures.dart';

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({this.available = true, this.passes = true});
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

/// Phản hồi đăng nhập/làm mới cho vai trò [role] (dựa trên payload thật).
Map<String, dynamic> loginPayload({String role = 'Admin'}) {
  final base = fixtureMap('auth_login');
  return {
    ...base,
    'accessTokenExpiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
    'user': {...(base['user'] as Map<String, dynamic>), 'role': role},
  };
}

/// Các route nền cho một phiên đã đăng nhập (Tổng quan cần dữ liệu tối thiểu).
Map<String, FakeHandler> baseRoutes({String role = 'Admin'}) => {
  'POST /api/auth/login': (_) => ok(loginPayload(role: role)),
  'POST /api/auth/refresh': (_) => ok(loginPayload(role: role)),
  'GET /api/dashboard/summary': (_) => ok(fixture('dashboard_summary')),
  'GET /api/reports/upcoming-maturities': (_) => ok(fixture('report_upcoming')),
  'GET /api/notifications/unread-count': (_) => ok({'count': 0}),
};

class Harness {
  Harness(
    this.tester,
    this.adapter,
    this.bio,
    this.container, {
    required this.pushSource,
    required this.opener,
    required this.picker,
    required this.prefs,
    required this.pins,
  });
  final InMemoryPinStorage pins;
  final FakePushTokenSource pushSource;
  final FakeOpener opener;
  final FakePicker picker;
  final SharedPreferences prefs;
  final WidgetTester tester;
  final FakeAdapter adapter;
  final FakeBiometric bio;
  final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  Future<void> go(String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> push(String location) async {
    // ignore: unawaited_futures
    router.push(location);
    await tester.pumpAndSettle();
  }

  List<dynamic> bodiesOf(String key) => [
    for (final r in adapter.requests)
      if ('${r.method} ${r.path}' == key) r.data,
  ];

  List<RequestOptions> requestsOf(String key) => [
    for (final r in adapter.requests)
      if ('${r.method} ${r.path}' == key) r,
  ];
}

/// Dựng app đã đăng nhập (qua refresh token đã lưu), mở khoá màn khoá nhanh rồi trả về [Harness].
Future<Harness> pumpSignedIn(
  WidgetTester tester, {
  required Map<String, FakeHandler> routes,
  String role = 'Admin',
  Map<String, Object> prefs = const {},
  String? pushToken,
  FakeAdapter? storage,
  String? pin,
  bool bioPasses = true,
}) async {
  final bio = FakeBiometric(passes: bioPasses);
  final pins = InMemoryPinStorage();
  final pinService = PinService(pins, iterations: 1000);
  if (pin != null) {
    await pinService.set(
      (loginPayload()['user'] as Map<String, dynamic>)['id'] as String,
      pin,
    );
  }
  final pushSource = FakePushTokenSource(pushToken);
  final opener = FakeOpener();
  final picker = FakePicker();
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final adapter = FakeAdapter({...baseRoutes(role: role), ...routes});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://fake', envName: 'dev'),
        ),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('REFRESH')),
        biometricProvider.overrideWithValue(bio),
        pinStorageProvider.overrideWithValue(pins),
        pinServiceProvider.overrideWithValue(pinService),
        sharedPrefsProvider.overrideWithValue(sp),
        cacheProvider.overrideWithValue(
          EncryptedCache(
            MemoryBlobStore(),
            FixedCacheKeyProvider(List<int>.filled(32, 7)),
          ),
        ),
        if (storage != null)
          storageDioProvider.overrideWithValue(fakeDio(storage)),
        pushTokenSourceProvider.overrideWithValue(pushSource),
        documentOpenerProvider.overrideWithValue(opener),
        imageSourcePickerProvider.overrideWithValue(picker),
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
  await tester.pumpAndSettle(); // khôi phục phiên → khoá → tự mở khoá bằng FakeBiometric
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CoreCdApp)),
  );
  return Harness(
    tester,
    adapter,
    bio,
    container,
    pushSource: pushSource,
    opener: opener,
    picker: picker,
    prefs: sp,
    pins: pins,
  );
}
