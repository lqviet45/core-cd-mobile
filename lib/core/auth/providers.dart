import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/search/presentation/search_providers.dart';
import '../cache/blob_store.dart';
import '../cache/encrypted_cache.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../push/push_registrar.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'biometric.dart';
import 'session_manager.dart';
import 'token_store.dart';

/// Ghi đè trong `main()`/test.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider chưa được ghi đè'),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final biometricProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometric(),
);

/// Tên thiết bị hiển thị trong danh sách phiên đăng nhập trên web/mobile khác.
final deviceNameProvider = Provider<String>((ref) {
  final os = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    _ => defaultTargetPlatform.name,
  };
  return 'Mobile · $os';
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(
    createBareDio(ref.watch(appConfigProvider)),
    deviceName: ref.watch(deviceNameProvider),
  ),
);

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(
    store: ref.watch(tokenStoreProvider),
    api: ref.watch(authApiProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Bộ nhớ đệm đọc mã hoá. Web không có thư mục riêng của app nên dùng bộ nhớ (mất khi tải lại trang).
final cacheProvider = Provider<EncryptedCache>(
  (ref) => EncryptedCache(
    kIsWeb ? MemoryBlobStore() : FileBlobStore(),
    SecureCacheKeyProvider(),
  ),
);

/// Thời điểm của dữ liệu đang được hiển thị từ bản đệm (null = dữ liệu trực tiếp).
class StaleSinceNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  // ignore: use_setters_to_change_properties
  void set(DateTime? v) => state = v;
}

final staleSinceProvider = NotifierProvider<StaleSinceNotifier, DateTime?>(
  StaleSinceNotifier.new,
);

/// Dio cho API nghiệp vụ.
final dioProvider = Provider<Dio>(
  (ref) => createAuthedDio(
    ref.watch(appConfigProvider),
    ref.watch(sessionManagerProvider),
    cache: ref.watch(cacheProvider),
    onServedFromCache: (t) => ref.read(staleSinceProvider.notifier).set(t),
    onLive: () {
      if (ref.read(staleSinceProvider) != null) {
        ref.read(staleSinceProvider.notifier).set(null);
      }
    },
  ),
);

/// Trạng thái đăng nhập của app.
sealed class AuthState {
  const AuthState();
}

class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.expired = false});

  /// Phiên bị máy chủ từ chối → hiển thị thông báo "đã hết hạn".
  final bool expired;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user, {this.restored = false});
  final AuthUser user;

  /// true = khôi phục từ lần mở app trước (cần khoá nhanh); false = vừa nhập mật khẩu.
  final bool restored;
}

/// Không thể xác định được phiên vì mất mạng khi mở app (refresh token vẫn được giữ).
class AuthOffline extends AuthState {
  const AuthOffline();
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<SessionEvent>? _sub;

  @override
  AuthState build() {
    final session = ref.watch(sessionManagerProvider);
    _sub = session.events.listen((e) {
      if (e is SignedOut) {
        // Đăng xuất/hết phiên: xoá dữ liệu đã đệm và huỷ khoá để không để lại dữ liệu của người dùng cũ.
        // Lỗi xoá bản đệm không được làm hỏng đăng xuất (khoá bị huỷ ngay cả khi xoá tệp lỗi nên dữ liệu vẫn không đọc được).
        unawaited(ref.read(cacheProvider).clear().catchError((Object _) {}));
        ref.read(staleSinceProvider.notifier).set(null);
        unawaited(ref.read(searchHistoryProvider.notifier).clear());
      }
      state = switch (e) {
        SignedIn(:final user) => AuthSignedIn(user),
        SignedOut(:final expired) => AuthSignedOut(expired: expired),
      };
    });
    ref.onDispose(() => _sub?.cancel());
    unawaited(_restore(session));
    return const AuthRestoring();
  }

  Future<void> _restore(SessionManager session) async {
    try {
      final user = await session.restore();
      if (state is AuthRestoring || state is AuthOffline) {
        state = user == null
            ? const AuthSignedOut()
            : AuthSignedIn(user, restored: true);
      }
    } on Object {
      state = const AuthOffline();
    }
  }

  Future<void> retryRestore() async {
    state = const AuthRestoring();
    await _restore(ref.read(sessionManagerProvider));
  }

  Future<void> login(String username, String password) =>
      ref.read(sessionManagerProvider).login(username, password);

  /// Huỷ đăng ký push TRƯỚC (cần token truy cập), rồi mới thu hồi phiên.
  Future<void> logout() async {
    await ref.read(pushRegistrarProvider).unregister();
    await ref.read(sessionManagerProvider).logout();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Người dùng hiện tại (chỉ dùng ở màn đã qua guard đăng nhập). Khi vừa đăng xuất, giữ người dùng cuối cùng cho tới
/// khi router gỡ màn hình, thay vì ném lỗi giữa lúc chuyển cảnh.
class CurrentUserNotifier extends Notifier<AuthUser> {
  AuthUser? _last;

  @override
  AuthUser build() {
    final s = ref.watch(authControllerProvider);
    if (s is AuthSignedIn) return _last = s.user;
    final last = _last;
    if (last != null) return last;
    throw StateError('Chưa đăng nhập');
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, AuthUser>(
  CurrentUserNotifier.new,
);
