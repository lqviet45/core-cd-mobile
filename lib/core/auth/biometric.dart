import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Xác thực người dùng bằng sinh trắc hoặc mã khoá của thiết bị.
abstract interface class BiometricAuthenticator {
  /// Thiết bị có khoá màn hình/sinh trắc để dùng không. `false` → không thể bắt buộc khoá nhanh.
  Future<bool> isAvailable();

  /// Hiển thị hộp thoại hệ thống; trả `true` khi xác thực thành công.
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (e) {
      debugPrint('Không kiểm tra được sinh trắc: ${e.runtimeType}');
      return false; // nền tảng không hỗ trợ (vd web) hoặc plugin lỗi
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometricOnly = false: cho phép PIN/hình mở khoá của thiết bị khi sinh trắc không dùng được.
      return await _auth.authenticate(localizedReason: reason);
    } on Object catch (e) {
      debugPrint('Xác thực thất bại: ${e.runtimeType}');
      return false;
    }
  }
}
