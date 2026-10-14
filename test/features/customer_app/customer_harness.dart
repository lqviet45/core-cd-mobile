import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/auth_interceptor.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_app_repository.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_auth_api.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_app.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_documents.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';

class FakeCustOpener implements CustDocumentOpener {
  final opened = <String>[];
  bool canOpen = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return canOpen;
  }
}

/// Phản hồi đăng nhập/làm mới OTP dựa trên payload thật (`test/fixtures/customer/auth_verify.json`).
Map<String, dynamic> custAuthPayload() => {
  ...fixtureMap('customer/auth_verify'),
  'accessTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};

/// Route nền cho phiên khách đã đăng nhập; test ghi đè/bổ sung theo nhu cầu.
Map<String, FakeHandler> custRoutes() => {
  'POST /api/customer/auth/otp/request': (_) =>
      ok({'expiresInSeconds': 300, 'resendAfterSeconds': 60}),
  'POST /api/customer/auth/otp/verify': (_) => ok(custAuthPayload()),
  'POST /api/customer/auth/refresh': (_) => ok(custAuthPayload()),
  'POST /api/customer/auth/logout': (_) => (status: 204, body: null),
  'GET /api/customer/me': (_) => ok(fixture('customer/me')),
  'GET /api/customer/summary': (_) => ok(fixture('customer/summary')),
  'GET /api/customer/certificates': (_) =>
      ok(fixture('customer/certificates_page')),
  'GET /api/customer/transactions': (_) =>
      ok(fixture('customer/transactions_page')),
};

class CustHarness {
  CustHarness(this.adapter, this.store, this.opener, this.container);
  final FakeAdapter adapter;
  final InMemoryTokenStore store;
  final FakeCustOpener opener;
  final ProviderContainer container;
}

/// Dựng app khách hàng với máy chủ giả. [storedToken] != null → khôi phục phiên đã lưu.
Future<CustHarness> pumpCustomer(
  WidgetTester tester, {
  required Map<String, FakeHandler> routes,
  String? storedToken,
}) async {
  final adapter = FakeAdapter(routes);
  final store = InMemoryTokenStore(storedToken);
  final opener = FakeCustOpener();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://fake', envName: 'dev'),
        ),
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
  return CustHarness(adapter, store, opener, container);
}

// Hàm tiện ích lấy dữ liệu từ fixture thật.
String fixtureCertId() =>
    fixtureMap('customer/certificate_detail')['id'] as String;
Map<String, dynamic> fixtureDetail() =>
    fixtureMap('customer/certificate_detail');
Map<String, dynamic> fixtureSchedule() =>
    fixtureMap('customer/interest_schedule_monthly');
