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

/// Kiểm tra app khách hàng với backend THẬT (đăng nhập OTP → đọc dữ liệu → refresh → đăng xuất).
/// Không chạy mặc định. Cần backend dev với `Otp:Provider=Log`, khách đã được bật quyền app (xem
/// `tool/capture_customer_fixtures.mjs`) và mã OTP mới đọc từ log API:
///   CD_LIVE_API=http://localhost:5080 CD_LIVE_PHONE=0901234567 CD_LIVE_OTP=123456 \
///     flutter test test/live --tags live
void main() {
  final api = Platform.environment['CD_LIVE_API'];
  final phone = Platform.environment['CD_LIVE_PHONE'];
  final otp = Platform.environment['CD_LIVE_OTP'];
  final skip = (api == null || phone == null || otp == null)
      ? 'Đặt CD_LIVE_API, CD_LIVE_PHONE, CD_LIVE_OTP để chạy.'
      : null;

  test('OTP → đọc dữ liệu → refresh xoay vòng → đăng xuất', () async {
    final config = AppConfig(apiBaseUrl: api!, envName: 'dev');
    final authApi = CustomerAuthApi(createBareDio(config), deviceName: 'live');
    final store = InMemoryTokenStore();
    final session = SessionManager(store: store, api: authApi);
    addTearDown(session.dispose);

    // OTP sai bị từ chối nhưng không huỷ mã đúng (chỉ tính một lần sai).
    await expectLater(
      authApi.verifyOtp(phone!, otp! == '000000' ? '000001' : '000000'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );

    await session.signIn(await authApi.verifyOtp(phone, otp));
    final first = await store.readRefreshToken();
    expect(first, isNotNull);

    final dio = createAuthedDio(config, session);
    final repo = CustomerAppRepository(dio);

    final me = await repo.me();
    expect(me.phoneMasked, contains('•'));
    expect(me.identityNumberMasked, contains('•'));

    final summary = await repo.summary();
    final certs = await repo.certificates(scope: 'Holding');
    expect(certs.totalCount, summary.holdingCount);
    for (final c in certs.items) {
      expect((await repo.certificate(c.id)).id, c.id);
      final sched = await repo.interestSchedule(c.id);
      expect(sched.certificateId, c.id);
      expect(await repo.documents('certificates', c.id), isA<List<dynamic>>());
    }
    final trx = await repo.transactions();
    if (trx.items.isNotEmpty) {
      expect(
        (await repo.transaction(trx.items.first.id)).trxNo,
        trx.items.first.trxNo,
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
