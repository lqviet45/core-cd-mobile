import 'dart:io';
import 'dart:typed_data';

import 'package:core_cd_mobile/core/auth/biometric.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/auth_interceptor.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_app_repository.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_auth_api.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_app.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_documents.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_providers.dart';
import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';

/// Nạp font thật của app khách (mặc định `flutter test` dùng font Ahem rộng gấp đôi, làm bố cục tràn sai).
Future<void> loadKhFonts() async {
  final loader = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

class FakeCustOpener implements CustDocumentOpener {
  final opened = <String>[];
  bool canOpen = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return canOpen;
  }
}

class FakeBio implements BiometricAuthenticator {
  FakeBio({this.available = true, this.passes = true});
  bool available;
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

Map<String, dynamic> _expiring(Map<String, dynamic> j) => {
  ...j,
  'accessTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};

/// Phản hồi đăng nhập/làm mới dựa trên payload THẬT (`test/fixtures/customer/auth_login.json`).
Map<String, dynamic> custAuthPayload() =>
    _expiring(fixtureMap('customer/auth_login'));

/// Đăng nhập lần đầu bằng mật khẩu tạm (`mustChangePassword = true`).
Map<String, dynamic> custFirstLoginPayload() =>
    _expiring(fixtureMap('customer/auth_login_first'));

/// Lịch nhận tiền với ngày tương đối so với hôm nay (fixture thật có ngày cố định nên sẽ lệch theo thời gian).
/// Giữ nguyên cấu trúc/trường của payload thật, chỉ dời ngày: 1 khoản sau 3 ngày, 2 khoản sau 45 ngày, 1 sau 200 ngày.
Map<String, dynamic> custUpcomingPayload() {
  final raw = fixtureMap('customer/upcoming_366');
  final items = (raw['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  final offsets = [3, 45, 46, 200];
  final today = DateTime.now();
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < offsets.length; i++) {
    final base = items[i % items.length];
    final d = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: offsets[i]));
    out.add({...base, 'date': d.toIso8601String(), 'isDue': false});
  }
  final total = out.fold<num>(0, (a, e) => a + (e['amount'] as num));
  return {'days': 366, 'totalAmount': total, 'items': out};
}

/// Route nền cho phiên khách đã đăng nhập; test ghi đè/bổ sung theo nhu cầu.
Map<String, FakeHandler> custRoutes() => {
  'POST /api/customer/auth/login': (_) => ok(custAuthPayload()),
  'POST /api/customer/auth/refresh': (_) => ok(custAuthPayload()),
  'POST /api/customer/auth/change-password': (_) => ok(custAuthPayload()),
  'POST /api/customer/auth/logout': (_) => (status: 204, body: null),
  'GET /api/customer/me': (_) => ok(fixture('customer/me')),
  'GET /api/customer/summary': (_) => ok(fixture('customer/summary')),
  'GET /api/customer/upcoming': (_) => ok(custUpcomingPayload()),
  'GET /api/customer/certificates': (o) {
    final scope = o.queryParameters['scope'];
    return ok(
      scope == 'Closed'
          ? fixture('customer/certificates_closed')
          : scope == 'Holding' || scope == 'Active'
          ? fixture('customer/certificates_holding')
          : fixture('customer/certificates_all'),
    );
  },
  'GET /api/customer/transactions': (_) =>
      ok(fixture('customer/transactions_page')),
};

class CustHarness {
  CustHarness(
    this.adapter,
    this.store,
    this.opener,
    this.bio,
    this.prefs,
    this.container,
  );
  final FakeAdapter adapter;
  final InMemoryTokenStore store;
  final FakeCustOpener opener;
  final FakeBio bio;
  final SharedPreferences prefs;
  final ProviderContainer container;

  List<RequestOptions> requestsOf(String key) => [
    for (final r in adapter.requests)
      if ('${r.method} ${r.path}' == key) r,
  ];
}

/// Dựng app khách hàng với máy chủ giả. [storedToken] != null → có phiên đã lưu.
Future<CustHarness> pumpCustomer(
  WidgetTester tester, {
  required Map<String, FakeHandler> routes,
  String? storedToken,
  Map<String, Object> prefs = const {},
  FakeBio? bio,
  Brightness brightness = Brightness.light,
}) async {
  final adapter = FakeAdapter(routes);
  final store = InMemoryTokenStore(storedToken);
  final opener = FakeCustOpener();
  final biometric = bio ?? FakeBio();
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://fake', envName: 'dev'),
        ),
        sharedPrefsProvider.overrideWithValue(sp),
        biometricProvider.overrideWithValue(biometric),
        custTokenStoreProvider.overrideWithValue(store),
        custAuthApiProvider.overrideWithValue(
          CustomerAuthApi(fakeDio(adapter), deviceName: 'test'),
        ),
        custRepositoryProvider.overrideWith((ref) {
          final dio = fakeDio(adapter);
          dio.interceptors.add(
            AuthInterceptor(ref.watch(custSessionProvider), dio),
          );
          return CustomerAppRepository(dio);
        }),
        custDocumentOpenerProvider.overrideWithValue(opener),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const CustomerApp();
        },
      ),
    ),
  );
  return CustHarness(adapter, store, opener, biometric, sp, container);
}
