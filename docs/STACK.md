# Tech stack (đã chốt)

Ngày chốt: 13/10/2026. Phiên bản **không** ghi ở đây – `flutter pub add` chọn bản tương thích mới nhất khi dựng và `pubspec.lock` là nguồn sự thật (commit file này).

## Nền tảng
- Flutter **stable** + Dart 3.x, Material 3. Android (minSdk 24 – Android 7.0) và iOS (15+).
- Cờ cấu hình: flavor gốc của Flutter (dev / staging / prod) + `--dart-define-from-file=env/<flavor>.json` (mẫu ở `env/*.example.json`; tệp thật không commit).

## Thư viện
| Mảng | Thư viện | Ghi chú |
|---|---|---|
| State | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | **Đã chốt Riverpod** (không dùng Bloc) |
| Điều hướng | `go_router` | guard: đăng nhập, khoá nhanh, vai trò; deep link từ push |
| Mạng | `dio` | interceptor: gắn token, làm mới single-flight, `Idempotency-Key`, ánh xạ ProblemDetails |
| Client API | `openapi_generator_cli` (generator `dart-dio`, `json_serializable`) | sinh từ `openapi/openapi.v1.json` vào `lib/generated/` (không commit) |
| Model | `freezed`, `json_serializable` | |
| Tiền | `decimal` | không dùng `double` |
| Địa phương hoá | `intl`, `flutter_localizations` (`.arb`) | vi-VN |
| Lưu token | `flutter_secure_storage` | Keychain / EncryptedSharedPreferences |
| Sinh trắc | `local_auth` | bắt buộc ngay trước thao tác tiền |
| Cache offline | `drift`, `sqlite3_flutter_libs` | **mã hoá bằng SQLCipher** (khoá trong secure storage) – làm theo hướng dẫn drift hiện hành khi dựng M1 |
| Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | kênh Android `cd_alerts` |
| PDF / tệp | `pdfx`, `share_plus`, `path_provider` | |
| Ảnh CCCD | `image_picker`, `flutter_image_compress` | upload thẳng lên link ngắn hạn của API |
| Mạng chập chờn | `connectivity_plus` | |
| Biểu đồ | `fl_chart` | |
| UI | `skeletonizer`, `lucide_icons_flutter`, font Inter đóng gói | không dùng `google_fonts` tải lúc chạy |
| Lỗi / log | `sentry_flutter`, `logger` | Sentry: **dự án riêng cho mobile** |
| Kiểm thử | `flutter_test`, `mocktail`, `integration_test`, `alchemist` (golden) | |
| Phân tích mã | `very_good_analysis`, `custom_lint`, `riverpod_lint`, `build_runner` | |

## Quyết định
1. **Riverpod**, không Bloc.
2. Cache offline **mã hoá SQLCipher**.
3. **Chống root/jailbreak và certificate pinning**: bật từ M0 (khung cấu hình, mặc định tắt ở flavor dev để debug được; bắt buộc bật ở staging/prod). Chọn thư viện cụ thể khi dựng M0 và ghi lại ở đây.
4. Sentry mobile **dự án riêng**.

## Chưa chọn (quyết khi tới mốc)
- Thư viện chống root/jailbreak và pinning (M0).
- Cách chặn chụp màn hình/ghi màn hình ở màn tiền (M2).
- Cách phát hành TestFlight / Play nội bộ (fastlane hay thủ công – dự án không dùng CI) (M4).
