import 'package:core_cd_mobile/core/auth/auth_api.dart';
import 'package:core_cd_mobile/core/auth/session_manager.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/network/api_exception.dart';
import 'package:core_cd_mobile/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late Dio dio;
  late int refreshCalls;
  late String validToken;

  Map<String, dynamic> loginBody(String access, String refresh) => {
    ...fixtureMap('auth_login'),
    'accessToken': access,
    'refreshToken': refresh,
    'accessTokenExpiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  };

  Future<void> setUpWith(
    Map<String, FakeHandler> extra, {
    bool refreshOk = true,
  }) async {
    refreshCalls = 0;
    validToken = 'A2';
    final authAdapter = FakeAdapter({
      'POST /api/auth/login': (_) => ok(loginBody('A1', 'R1')),
      'POST /api/auth/refresh': (_) {
        refreshCalls++;
        return refreshOk
            ? ok(loginBody('A2', 'R2'))
            : failure(401, 'Phiên không hợp lệ');
      },
    });
    final session = SessionManager(
      store: InMemoryTokenStore(),
      api: AuthApi(fakeDio(authAdapter), deviceName: 't'),
    );
    await session.login('admin', 'pw');
    adapter = FakeAdapter(extra);
    dio = fakeDio(adapter);
    dio.interceptors.add(AuthInterceptor(session, dio));
  }

  FakeHandler guarded() =>
      (o) => o.headers['Authorization'] == 'Bearer $validToken'
      ? ok({'v': 1})
      : failure(401);

  test('gắn Bearer token vào request', () async {
    await setUpWith({
      'GET /ping': (_) => ok({'v': 1}),
    });
    await dio.get<dynamic>('/ping');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer A1');
  });

  test('401 → làm mới rồi thử lại đúng một lần', () async {
    await setUpWith({'GET /secure': guarded()});
    final res = await dio.get<Map<String, dynamic>>('/secure');
    expect(res.data!['v'], 1);
    expect(refreshCalls, 1);
    expect(adapter.count('GET /secure'), 2);
  });

  test('nhiều request cùng 401 chỉ làm mới một lần', () async {
    await setUpWith({'GET /secure': guarded()});
    final rs = await Future.wait([
      dio.get<dynamic>('/secure'),
      dio.get<dynamic>('/secure'),
      dio.get<dynamic>('/secure'),
    ]);
    expect(rs.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('vẫn 401 sau khi thử lại → trả lỗi, không lặp vô hạn', () async {
    await setUpWith({'GET /secure': (_) => failure(401)});
    await expectLater(
      dio.get<dynamic>('/secure'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.count('GET /secure'), 2);
    expect(refreshCalls, 1);
  });

  test('refresh bị từ chối → trả lỗi 401 gốc, không thử lại', () async {
    await setUpWith({'GET /secure': (_) => failure(401)}, refreshOk: false);
    DioException? err;
    try {
      await dio.get<dynamic>('/secure');
    } on DioException catch (e) {
      err = e;
    }
    expect(err?.response?.statusCode, 401);
    expect(adapter.count('GET /secure'), 1);
  });

  test('ApiException ánh xạ ProblemDetails và lỗi mạng', () async {
    await setUpWith({'GET /bad': (_) => failure(400, 'Dữ liệu không hợp lệ')});
    try {
      await dio.get<dynamic>('/bad');
      fail('phải ném lỗi');
    } on DioException catch (e) {
      final api = ApiException.fromDio(e);
      expect(api.status, 400);
      expect(api.message, 'Dữ liệu không hợp lệ');
    }
  });
}
