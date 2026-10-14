import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_prefs.dart';
import 'pin_service.dart';
import 'providers.dart';

/// Khoá nhanh: sau khi app ở nền quá thời gian đặt trong Cài đặt, hoặc khi mở lại app với phiên đã lưu, phải xác thực
/// sinh trắc/mã thiết bị mới xem tiếp được dữ liệu. Nếu thiết bị không có khoá màn hình thì không thể
/// bắt buộc (và các thao tác tiền ở M2 sẽ từ chối).
class AppLockController extends Notifier<bool> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  /// Cho test chỉnh đồng hồ.
  DateTime Function() clock = DateTime.now;

  @override
  bool build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    // Phiên khôi phục từ lần mở trước → khoá ngay; đăng nhập mới → mở; đăng xuất → bỏ khoá.
    ref.listen(authControllerProvider, (prev, next) async {
      final enabled = ref.read(appPrefsProvider).lockEnabled;
      if (next is AuthSignedIn && next.restored && !enabled) {
        state = false;
      } else if (next is AuthSignedIn && next.restored) {
        state =
            true; // khoá ngay để không lộ dữ liệu trong lúc kiểm tra thiết bị
        if (!await _lockable()) state = false;
      } else if (next is AuthSignedIn) {
        state = false;
      } else if (next is! AuthRestoring) {
        state = false;
      }
    });
    return false;
  }

  /// Khoá được khi thiết bị có sinh trắc/khoá màn hình **hoặc** tài khoản đã đặt PIN của app.
  Future<bool> _lockable() async {
    if (await ref.read(biometricProvider).isAvailable()) return true;
    final auth = ref.read(authControllerProvider);
    return auth is AuthSignedIn &&
        await ref.read(pinServiceProvider).isSet(auth.user.id);
  }

  // `state` là thuộc tính của Notifier nên không đặt tên tham số theo chữ ký gốc.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      _pausedAt ??= clock();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      final prefs = ref.read(appPrefsProvider);
      if (prefs.lockEnabled &&
          since != null &&
          clock().difference(since) >= prefs.lockAfter) {
        unawaited(_lockIfSignedIn());
      }
    }
  }

  Future<void> _lockIfSignedIn() async {
    if (ref.read(authControllerProvider) is! AuthSignedIn) return;
    state = await _lockable();
  }

  /// Mở khoá bằng PIN của app. Sai quá số lần cho phép → PIN bị xoá và đăng xuất (phải nhập lại mật khẩu).
  Future<PinResult> unlockWithPin(String pin) async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return const PinLockedOut();
    final r = await ref.read(pinServiceProvider).verify(auth.user.id, pin);
    switch (r) {
      case PinOk():
        state = false;
      case PinLockedOut():
        await ref.read(authControllerProvider.notifier).logout();
      case PinWrong():
        break;
    }
    return r;
  }

  /// Hiển thị hộp thoại sinh trắc; thành công thì mở khoá.
  Future<bool> unlock() async {
    final ok = await ref
        .read(biometricProvider)
        .authenticate('Xác thực để mở Core CD');
    if (ok) state = false;
    return ok;
  }
}

/// `true` = đang khoá.
final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);
