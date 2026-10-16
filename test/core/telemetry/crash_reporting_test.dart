import 'package:core_cd_mobile/core/telemetry/crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  const jwt =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJlX3NpZ25hdHVyZQ';

  test('scrubString xoá JWT, Bearer, email, số dài và giá trị mật khẩu', () {
    final out = scrubString(
      'lỗi $jwt; Authorization: Bearer abc.def; mail an@bank.vn; '
      'sdt 0912345678; password=Matkhau#1 token":"xyz"',
    );
    expect(out, isNot(contains('eyJ')));
    expect(out, isNot(contains('abc.def')));
    expect(out, isNot(contains('an@bank.vn')));
    expect(out, isNot(contains('0912345678')));
    expect(out, isNot(contains('Matkhau')));
    expect(out, isNot(contains('xyz')));
    expect(out, contains('lỗi'));
  });

  test('scrubEvent chỉ giữ allowlist: bỏ user/request/extra/hostname', () {
    final event = SentryEvent(
      release: 'customer@1.0.0',
      environment: 'prod',
      serverName: 'host-của-an',
      user: SentryUser(id: '1', email: 'an@bank.vn', ipAddress: '1.2.3.4'),
      request: SentryRequest(
        url: 'https://api/x?token=abc',
        headers: {'Authorization': 'Bearer $jwt'},
        data: {'password': 'x'},
      ),
      // ignore: deprecated_member_use
      extra: {'cif': '0912345678'},
      message: SentryMessage('login 0912345678 fail'),
      exceptions: [
        SentryException(type: 'StateError', value: 'token $jwt cho an@bank.vn'),
      ],
      contexts: Contexts(
        device: SentryDevice(name: 'iPhone của An', model: 'iPhone15,2'),
      ),
      breadcrumbs: [
        Breadcrumb(message: 'GET /api/customer/me', category: 'http'),
        Breadcrumb(message: 'mở màn 0912345678', category: 'ui'),
      ],
    );

    final out = scrubEvent(event);

    expect(out.user, isNull);
    expect(out.request, isNull);
    expect(out.serverName, isNull);
    // ignore: deprecated_member_use
    expect(out.extra, isNull);
    expect(out.release, 'customer@1.0.0');
    expect(out.environment, 'prod');
    expect(out.exceptions!.single.type, 'StateError');
    expect(out.exceptions!.single.value, isNot(contains('eyJ')));
    expect(out.exceptions!.single.value, isNot(contains('an@bank.vn')));
    expect(out.message!.formatted, isNot(contains('0912345678')));
    expect(out.contexts.device!.name, isNull);
    expect(out.contexts.device!.model, 'iPhone15,2');
    // breadcrumb http bị bỏ, breadcrumb khác được làm sạch
    expect(out.breadcrumbs!.length, 1);
    expect(out.breadcrumbs!.single.message, isNot(contains('0912345678')));
  });

  test('scrubBreadcrumb bỏ http/xhr và dữ liệu đính kèm', () {
    expect(scrubBreadcrumb(Breadcrumb(category: 'http')), isNull);
    expect(scrubBreadcrumb(Breadcrumb(category: 'xhr')), isNull);
    final kept = scrubBreadcrumb(
      Breadcrumb(message: 'x', category: 'ui', data: {'k': 'v'}),
    );
    expect(kept!.data, isNull);
  });
}
