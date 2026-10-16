import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

/// Báo lỗi Sentry. Quy tắc: **không bao giờ gửi dữ liệu khách hàng hay bí mật**.
/// Tắt hẳn (không khởi tạo SDK) khi `SENTRY_DSN` rỗng.
///
/// Sentry chỉ nhận: loại lỗi + stack trace + thiết bị/phiên bản. Không PII, không ảnh chụp màn hình,
/// không view hierarchy, không request/response, không breadcrumb mạng.
Future<void> runWithCrashReporting(
  AppConfig config, {
  required String appName,
  required FutureOr<void> Function() run,
}) async {
  if (config.sentryDsn.isEmpty) {
    await run();
    return;
  }
  await SentryFlutter.init((o) {
    o
      ..dsn = config.sentryDsn
      ..environment = config.envName
      ..release = config.appVersion.isEmpty
          ? appName
          : '$appName@${config.appVersion}'
      ..sendDefaultPii = false
      ..attachScreenshot = false
      // ignore: experimental_member_use
      ..attachViewHierarchy = false
      ..tracesSampleRate = 0
      ..maxRequestBodySize = MaxRequestBodySize.never
      ..beforeSend = ((event, hint) => scrubEvent(event))
      ..beforeBreadcrumb = ((crumb, hint) => scrubBreadcrumb(crumb));
  }, appRunner: run);
}

final _jwt = RegExp(r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*');
final _bearer = RegExp(r'Bearer\s+\S+', caseSensitive: false);
final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _digits = RegExp(r'\d{6,}');
final _secretKv = RegExp(
  r'''(password|passwd|pwd|token|secret|otp|authorization)(["']?\s*[:=]\s*["']?)[^\s,"'&}]+''',
  caseSensitive: false,
);

/// Xoá token/JWT/email/dãy số dài (SĐT, số tài khoản, mã KH…)/giá trị mật khẩu khỏi một chuỗi.
@visibleForTesting
String scrubString(String input) => input
    .replaceAll(_jwt, '[jwt]')
    .replaceAll(_bearer, 'Bearer [token]')
    .replaceAllMapped(_secretKv, (m) => '${m[1]}${m[2]}[redacted]')
    .replaceAll(_email, '[email]')
    .replaceAll(_digits, '[num]');

/// Dựng lại sự kiện từ danh sách **cho phép** (allowlist) thay vì xoá từng trường nguy hiểm:
/// trường mới do SDK thêm sau này sẽ không tự lọt ra ngoài. (`copyWith(null)` của Sentry giữ giá trị cũ
/// nên không dùng để xoá được.)
SentryEvent scrubEvent(SentryEvent e) => SentryEvent(
  eventId: e.eventId,
  timestamp: e.timestamp,
  platform: e.platform,
  release: e.release,
  dist: e.dist,
  environment: e.environment,
  level: e.level,
  sdk: e.sdk,
  debugMeta: e.debugMeta,
  transaction: e.transaction == null ? null : scrubString(e.transaction!),
  fingerprint: e.fingerprint,
  threads: e.threads,
  throwable: e.throwable,
  exceptions: e.exceptions
      ?.map((x) => x.copyWith(value: scrubString(x.value ?? '')))
      .toList(),
  message: e.message == null
      ? null
      : SentryMessage(scrubString(e.message!.formatted)),
  contexts: _safeContexts(e.contexts),
  breadcrumbs: e.breadcrumbs
      ?.map(scrubBreadcrumb)
      .whereType<Breadcrumb>()
      .toList(),
  tags: e.tags == null
      ? null
      : {for (final t in e.tags!.entries) t.key: scrubString(t.value)},
  // Cố ý bỏ: user, request, serverName (hostname), extra, modules, culprit, logger.
);

Contexts _safeContexts(Contexts c) {
  final d = c.device;
  return Contexts(
    operatingSystem: c.operatingSystem,
    runtimes: c.runtimes,
    app: c.app,
    // Bỏ `name` (thường là tên máy của chủ máy, vd "iPhone của An").
    device: d == null
        ? null
        : SentryDevice(
            model: d.model,
            family: d.family,
            brand: d.brand,
            manufacturer: d.manufacturer,
            arch: d.arch,
            simulator: d.simulator,
          ),
  );
}

/// Bỏ breadcrumb mạng (URL có thể chứa id), làm sạch phần còn lại.
Breadcrumb? scrubBreadcrumb(Breadcrumb? b) {
  if (b == null) return null;
  if (b.category == 'http' || b.type == 'http' || b.category == 'xhr') {
    return null;
  }
  return Breadcrumb(
    message: b.message == null ? null : scrubString(b.message!),
    category: b.category,
    level: b.level,
    type: b.type,
    timestamp: b.timestamp,
  );
}
