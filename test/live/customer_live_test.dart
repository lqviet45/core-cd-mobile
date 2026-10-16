@Tags(['live'])
library;

import 'dart:io';

import 'package:core_cd_mobile/core/auth/session_manager.dart';
import 'package:core_cd_mobile/core/auth/token_store.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/api_client.dart';
import 'package:core_cd_mobile/core/network/api_exception.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_app_repository.dart';
import 'package:core_cd_mobile/features/customer_app/data/customer_auth_api.dart';
import 'package:dio/dio.dart' show Options;
import 'package:flutter_test/flutter_test.dart';

/// Kiểm tra app khách hàng với backend THẬT: đăng nhập SĐT/CIF + mật khẩu → đọc dữ liệu → refresh xoay vòng → đăng xuất.
/// Không chạy mặc định. Cần backend dev đã có khách được bật quyền app và đã đổi mật khẩu tạm
/// (xem `tool/capture_customer_fixtures.mjs`, mật khẩu mặc định `Matkhau#Demo2026`):
///   CD_LIVE_API=http://localhost:5080 CD_LIVE_ID=0901234567 CD_LIVE_PASSWORD='Matkhau#Demo2026' \
///     flutter test test/live --tags live
void main() {
  final api = Platform.environment['CD_LIVE_API'];
  final id = Platform.environment['CD_LIVE_ID'];
  final password = Platform.environment['CD_LIVE_PASSWORD'];
  final skip = (api == null || id == null || password == null)
      ? 'Đặt CD_LIVE_API, CD_LIVE_ID, CD_LIVE_PASSWORD để chạy.'
      : null;

  test('đăng nhập → đọc dữ liệu → refresh xoay vòng → đăng xuất', () async {
    final config = AppConfig(apiBaseUrl: api!, envName: 'dev');
    final authApi = CustomerAuthApi(createBareDio(config), deviceName: 'live');
    final store = InMemoryTokenStore();
    final session = SessionManager(store: store, api: authApi);
    addTearDown(session.dispose);

    // Sai mật khẩu bị từ chối bằng 401 (không phân biệt tài khoản có tồn tại hay không).
    await expectLater(
      authApi.login(id!, '${password!}-sai'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );

    await session.login(id, password);
    expect(authApi.mustChangePassword, isFalse, reason: 'đã đổi mật khẩu tạm');
    final first = await store.readRefreshToken();
    expect(first, isNotNull);

    final dio = createAuthedDio(config, session);
    final repo = CustomerAppRepository(dio);

    final me = await repo.me();
    expect(me.phoneMasked, contains('•'));
    expect(me.identityNumberMasked, contains('•'));
    expect(me.emailMasked, contains('•'));

    final summary = await repo.summary();
    final holding = await repo.certificates(scope: 'Holding');
    expect(holding.totalCount, summary.holdingCount);
    final closed = await repo.certificates(scope: 'Closed');
    expect(closed.totalCount, summary.closedCount);
    for (final c in holding.items) {
      expect((await repo.certificate(c.id)).id, c.id);
      expect((await repo.interestSchedule(c.id)).certificateId, c.id);
      expect(await repo.documents('certificates', c.id), isA<List<dynamic>>());
    }

    final upcoming = await repo.upcoming();
    expect(
      upcoming.items.length,
      greaterThanOrEqualTo(holding.items.isNotEmpty ? 1 : 0),
    );
    final dates = upcoming.items.map((i) => i.date).toList();
    expect(dates, orderedEquals([...dates]..sort()));

    final out = await repo.transactions(direction: 'Out');
    final inn = await repo.transactions(direction: 'In');
    final all = await repo.transactions();
    expect(out.totalCount + inn.totalCount, all.totalCount);
    if (all.items.isNotEmpty) {
      expect(
        (await repo.transaction(all.items.first.id)).trxNo,
        all.items.first.trxNo,
      );
    }

    // Tài nguyên không tồn tại/của người khác → 404, không phải 403/500.
    await expectLater(
      repo.certificate('00000000-0000-0000-0000-000000000001'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );

    // Token khách không mở được API nhân viên (403), dù chữ ký hợp lệ.
    for (final path in [
      '/api/customers',
      '/api/auth/me',
      '/api/dashboard/summary',
    ]) {
      final r = await dio.get<dynamic>(
        path,
        options: Options(validateStatus: (_) => true),
      );
      expect(r.statusCode, 403, reason: path);
    }

    // Refresh xoay vòng: token mới khác token cũ; token cũ dùng lại bị từ chối.
    expect(await session.refresh(), RefreshResult.ok);
    final second = await store.readRefreshToken();
    expect(second, isNot(first));
    await expectLater(
      authApi.refresh(first!),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
  }, skip: skip);
}
