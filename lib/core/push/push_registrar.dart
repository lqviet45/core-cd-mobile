import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers.dart';
import '../network/api_call.dart';
import '../network/api_exception.dart';
import '../utils/deep_link.dart';
import 'push_token_source.dart';

/// Nguồn token thật: ghi đè trong `main()` khi đã cấu hình Firebase.
final pushTokenSourceProvider = Provider<PushTokenSource>(
  (ref) => const NoopPushTokenSource(),
);

/// Phiên bản app gửi kèm khi đăng ký thiết bị.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Điều hướng được yêu cầu từ một push (UI lắng nghe và `router.go`).
class PushRouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? v) => state = v;
}

final pushRouteProvider = NotifierProvider<PushRouteNotifier, String?>(
  PushRouteNotifier.new,
);

/// Đăng ký thiết bị nhận push sau khi đăng nhập và mỗi khi token đổi; huỷ đăng ký **trước** khi đăng xuất.
/// Mọi lỗi đăng ký chỉ là "không nhận được push", không được làm hỏng đăng nhập.
class PushRegistrar {
  PushRegistrar(this._ref);
  final Ref _ref;
  String? _registered;

  PushTokenSource get _source => _ref.read(pushTokenSourceProvider);

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    _ => 'Android',
  };

  /// Token đang đăng ký (để test/hiển thị trạng thái).
  String? get registeredToken => _registered;

  Future<void> register([String? token]) async {
    try {
      final t = token ?? await _source.currentToken();
      if (t == null || t.isEmpty || t == _registered) return;
      await apiCall(
        () => _ref
            .read(dioProvider)
            .post<void>(
              '/api/devices',
              data: {
                'token': t,
                'platform': _platform,
                'appVersion': appVersion,
                'deviceName': _ref.read(deviceNameProvider),
              },
            ),
      );
      _registered = t;
    } on ApiException {
      // Thử lại ở lần đăng nhập/đổi token tiếp theo.
    } on Object {
      // Lỗi từ nhà cung cấp push: bỏ qua.
    }
  }

  /// Gọi TRƯỚC `auth/logout` (khi còn token truy cập). Lỗi bị nuốt: đăng xuất phải luôn thành công.
  Future<void> unregister() async {
    final t = _registered;
    _registered = null;
    try {
      if (t != null) {
        await apiCall(
          () => _ref
              .read(dioProvider)
              .post<void>('/api/devices/unregister', data: {'token': t}),
        );
      }
      await _source.deleteToken();
    } on Object {
      // Bỏ qua: token sẽ tự hết hiệu lực / bị dọn khi gửi lỗi.
    }
  }
}

/// Bộ đăng ký/huỷ đăng ký. Cố ý KHÔNG phụ thuộc vào trạng thái đăng nhập: `AuthController.logout` đọc nó, nên nếu nó
/// lắng nghe `authControllerProvider` sẽ thành vòng phụ thuộc. Việc theo dõi đăng nhập nằm ở [pushLifecycleProvider].
final pushRegistrarProvider = Provider<PushRegistrar>(PushRegistrar.new);

/// Nối bộ đăng ký với vòng đời đăng nhập và các sự kiện từ nguồn push. Phải được `watch` một lần ở gốc app.
final pushLifecycleProvider = Provider<void>((ref) {
  final registrar = ref.watch(pushRegistrarProvider);
  final source = ref.watch(pushTokenSourceProvider);
  final subs = <StreamSubscription<Object?>>[
    source.onTokenRefresh.listen((t) {
      if (ref.read(authControllerProvider) is AuthSignedIn) {
        unawaited(registrar.register(t));
      }
    }),
    source.onNotificationTap.listen((data) {
      final route = routeForPush(data);
      if (route != null) ref.read(pushRouteProvider.notifier).set(route);
    }),
  ];
  ref
    ..listen(authControllerProvider, (prev, next) {
      if (next is AuthSignedIn) unawaited(registrar.register());
    }, fireImmediately: true)
    ..onDispose(() {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    });
});
