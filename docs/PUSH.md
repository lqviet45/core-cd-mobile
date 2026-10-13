# Push thông báo (FCM) – cách bật

> **Trạng thái:** phần logic trong app đã xong và có test (đăng ký thiết bị, đăng ký lại khi token xoay vòng, huỷ đăng ký
> **trước** khi đăng xuất, chạm thông báo → mở đúng màn hình). **Nguồn token thật (Firebase) chưa được thêm** vì cần dự án
> Firebase + tệp cấu hình nền tảng mà môi trường dựng không có. Mặc định app dùng `NoopPushTokenSource` (không token,
> không gọi API). **Mọi thứ liên quan Firebase dưới đây chưa được chạy thử.**

## Đã có trong mã

| Thành phần | Vai trò |
|---|---|
| `lib/core/push/push_token_source.dart` | Giao diện `PushTokenSource` (token hiện tại, token xoay vòng, chạm thông báo, xoá token) + `NoopPushTokenSource` |
| `lib/core/push/push_registrar.dart` | `PushRegistrar` gọi `POST /api/devices` / `POST /api/devices/unregister`; `pushLifecycleProvider` nối với trạng thái đăng nhập |
| `lib/core/utils/deep_link.dart` | `routeForPush(data)` / `routeForLink(link)`: `data.link` (đường dẫn web) → route mobile; thiếu thì suy từ `data.type` |
| `lib/app.dart` | `watch(pushLifecycleProvider)`; khi `pushRouteProvider` có giá trị thì `router.go(...)` |

Hợp đồng với backend (`PushDispatcher`): `data = { notificationId, type, link? }`; `type` ∈ `NearMaturity`,
`TransactionFailed`, `LotNearlySoldOut`, `JobSummary`. Body đăng ký: `{ token, platform: "Android"|"iOS", appVersion, deviceName }`.

Quy tắc đã cài và có test:

- Lỗi đăng ký push **không** làm hỏng đăng nhập (chỉ là không nhận được push, thử lại ở lần sau).
- Đăng xuất: huỷ đăng ký **trước** `auth/logout` (còn token truy cập), rồi xoá token ở FCM; lỗi ở bước này bị nuốt.
- Chỉ điều hướng tới đích nằm trong danh sách cho phép của `routeForLink`; link lạ → hộp thông báo.
- Push chỉ là tín hiệu "có việc": **không** đặt số tiền/tên khách trong payload (backend đã tuân thủ), app tải chi tiết qua API.

## Bật Firebase (việc còn lại)

1. Tạo dự án Firebase, thêm app Android (`applicationId`) và iOS (bundle id). **Bundle id hiện là placeholder
   `vn.corecd.core_cd_mobile`** – chốt id thật trước khi tạo app Firebase.
2. Tải `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) vào đúng thư mục nền tảng. **Không commit**
   (đã nằm trong `.gitignore`/CLAUDE.md). iOS: bật Push Notifications + Background Modes, tải khoá APNs `.p8` lên Firebase.
3. Thêm gói: `flutter pub add firebase_core firebase_messaging`, rồi `flutterfire configure` (sinh `firebase_options.dart`,
   **không commit**).
4. Tạo `lib/core/push/firebase_push_token_source.dart` (phác thảo, chưa chạy thử):

```dart
class FirebasePushTokenSource implements PushTokenSource {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  @override
  Future<String?> currentToken() async {
    final s = await _fm.requestPermission();
    if (s.authorizationStatus == AuthorizationStatus.denied) return null;
    return _fm.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<Map<String, String>> get onNotificationTap async* {
    // App bị tắt hẳn rồi mở bằng cách chạm thông báo.
    final initial = await _fm.getInitialMessage();
    if (initial != null) yield _data(initial);
    // App đang ở nền.
    yield* FirebaseMessaging.onMessageOpenedApp.map(_data);
  }

  @override
  Future<void> deleteToken() => _fm.deleteToken();

  static Map<String, String> _data(RemoteMessage m) =>
      {for (final e in m.data.entries) e.key: '${e.value}'};
}
```

5. Trong `main()`: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` rồi thêm
   `pushTokenSourceProvider.overrideWithValue(FirebasePushTokenSource())` vào `ProviderScope.overrides`.
6. Thông báo khi app đang mở (foreground): FCM không tự hiện. Hộp thông báo trong app đã có chấm chưa đọc
   (`/api/notifications/unread-count`); nếu muốn banner hệ thống khi đang mở thì thêm `flutter_local_notifications`.

## Cần thử trên thiết bị thật trước khi coi là xong

- Token được cấp và `POST /api/devices` trả 2xx (xem bảng `DeviceToken` ở backend).
- Gửi một thông báo thử từ backend (job gần đáo hạn hoặc giao dịch lỗi) → máy nhận được khi app ở nền / bị tắt.
- Chạm thông báo mở đúng màn hình ở cả hai trạng thái trên.
- Đăng xuất → máy **không** nhận push của tài khoản đó nữa; đăng nhập tài khoản khác trên cùng máy → chỉ nhận push của tài khoản mới.
- Từ chối quyền thông báo → app vẫn chạy bình thường, không đăng ký.
