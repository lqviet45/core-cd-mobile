import 'package:core_cd_mobile/core/auth/auth_api.dart';
import 'package:core_cd_mobile/core/auth/session_manager.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';

Map<String, dynamic> tokens({
  required String access,
  required String refresh,
  required DateTime expires,
}) => {
  ...fixtureMap('auth_login'),
  'accessToken': access,
  'refreshToken': refresh,
  'accessTokenExpiresAt': expires.toUtc().toIso8601String(),
};

void main() {
  late InMemoryTokenStore store;
  late FakeAdapter adapter;
  late SessionManager session;
  late DateTime now;
  var seq = 0;

  void build(Map<String, FakeHandler> routes, {String? stored}) {
    store = InMemoryTokenStore(stored);
    adapter = FakeAdapter(routes);
    session = SessionManager(
      store: store,
      api: AuthApi(fakeDio(adapter), deviceName: 'test'),
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 8);
    seq = 0;
  });

  test('login lưu refresh token và giữ access token trong bộ nhớ', () async {
    build({
      'POST /api/auth/login': (_) => ok(
        tokens(
          access: 'A1',
          refresh: 'R1',
          expires: now.add(const Duration(minutes: 15)),
        ),
      ),
    });
    final user = await session.login(' admin ', 'pw');
    expect(user.username, 'admin');
    expect(session.accessToken, 'A1');
    expect(await store.readRefreshToken(), 'R1');
    expect(
      (adapter.requests.single.data as Map)['username'],
      'admin',
      reason: 'tên đăng nhập được cắt khoảng trắng',
    );
  });

  test('refresh đồng thời chỉ gọi máy chủ một lần (single-flight)', () async {
    build({
      'POST /api/auth/refresh': (_) => ok(
        tokens(
          access: 'A${++seq}',
          refresh: 'R${seq + 1}',
          expires: now.add(const Duration(minutes: 15)),
        ),
      ),
    }, stored: 'R1');
    final results = await Future.wait([
      session.refresh(),
      session.refresh(),
      session.refresh(),
    ]);
    expect(results, everyElement(RefreshResult.ok));
    expect(adapter.count('POST /api/auth/refresh'), 1);
    expect(await store.readRefreshToken(), 'R2', reason: 'lưu token mới');
  });

  test('refresh 401 → invalid, xoá phiên và phát SignedOut(expired)', () async {
    build({'POST /api/auth/refresh': (_) => failure(401)}, stored: 'R1');
    final events = <SessionEvent>[];
    session.events.listen(events.add);
    expect(await session.refresh(), RefreshResult.invalid);
    await Future<void>.delayed(Duration.zero);
    expect(await store.readRefreshToken(), isNull);
    expect(session.accessToken, isNull);
    expect(
      events.single,
      isA<SignedOut>().having((e) => e.expired, 'expired', true),
    );
  });

  test('refresh 503 → unavailable, GIỮ refresh token', () async {
    build({'POST /api/auth/refresh': (_) => failure(503)}, stored: 'R1');
    expect(await session.refresh(), RefreshResult.unavailable);
    expect(await store.readRefreshToken(), 'R1');
  });

  test(
    'restore: không có token → null; lỗi tạm thời → ném, vẫn giữ token',
    () async {
      build({});
      expect(await session.restore(), isNull);

      build({'POST /api/auth/refresh': (_) => failure(500)}, stored: 'R1');
      await expectLater(session.restore(), throwsA(anything));
      expect(await store.readRefreshToken(), 'R1');
    },
  );

  test(
    'ensureFresh: token còn hạn thì không refresh, sắp hết hạn thì refresh',
    () async {
      build({
        'POST /api/auth/login': (_) => ok(
          tokens(
            access: 'A1',
            refresh: 'R1',
            expires: now.add(const Duration(minutes: 15)),
          ),
        ),
        'POST /api/auth/refresh': (_) => ok(
          tokens(
            access: 'A2',
            refresh: 'R2',
            expires: now.add(const Duration(minutes: 30)),
          ),
        ),
      });
      await session.login('admin', 'pw');
      expect(await session.ensureFresh(), isTrue);
      expect(adapter.count('POST /api/auth/refresh'), 0);

      now = now.add(
        const Duration(minutes: 14, seconds: 45),
      ); // còn 15 s < 30 s
      expect(await session.ensureFresh(), isTrue);
      expect(adapter.count('POST /api/auth/refresh'), 1);
      expect(session.accessToken, 'A2');
    },
  );

  test('logout luôn xoá cục bộ dù máy chủ lỗi', () async {
    build({'POST /api/auth/logout': (_) => failure(500)}, stored: 'R1');
    await session.logout();
    expect(await store.readRefreshToken(), isNull);
  });
}
