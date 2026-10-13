import 'dart:async';

/// Nguồn token đẩy (FCM/APNs) và sự kiện chạm vào thông báo. Tách khỏi Firebase để logic đăng ký/huỷ/điều hướng
/// kiểm thử được mà không cần thiết bị. Bản thật dùng `firebase_messaging` (xem `docs/PUSH.md`).
abstract interface class PushTokenSource {
  /// Token hiện tại; `null` nếu chưa cấp quyền/chưa cấu hình push.
  Future<String?> currentToken();

  /// Token đổi (FCM xoay vòng): phải đăng ký lại với máy chủ.
  Stream<String> get onTokenRefresh;

  /// Người dùng chạm vào một thông báo đẩy (dữ liệu `data` của FCM).
  Stream<Map<String, String>> get onNotificationTap;

  /// Xoá token ở phía nhà cung cấp (khi đăng xuất) để thiết bị thôi nhận push của tài khoản này.
  Future<void> deleteToken();
}

/// Chưa cấu hình push (chưa có dự án Firebase): không token, không sự kiện.
class NoopPushTokenSource implements PushTokenSource {
  const NoopPushTokenSource();

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<Map<String, String>> get onNotificationTap => const Stream.empty();

  @override
  Future<void> deleteToken() async {}
}
