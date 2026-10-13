# Tech stack

> App này là **app nhân viên** (Viewer/Operator/Admin). App khách hàng là giai đoạn sau, chưa có thiết kế/backend.

Cập nhật 13/10/2026 theo mã thực tế (M0 + M1 + M2). Phiên bản: `pubspec.yaml` / `pubspec.lock` là nguồn sự thật. Flutter stable 3.47 (Dart 3.13), Material 3, Android minSdk theo mặc định Flutter, iOS 15+.

Cấu hình môi trường: `--dart-define-from-file=env/<flavor>.json` (mẫu `env/*.example.json`; tệp thật không commit). Prod bắt buộc `API_BASE_URL` dùng https (`AppConfig.validate`).

## Đã dùng (có trong pubspec)
| Mảng | Thư viện | Ghi chú |
|---|---|---|
| State | `flutter_riverpod` 3 | Provider/Notifier **viết tay**, không dùng generator (`riverpod_generator`/`riverpod_lint` bị loại: kéo theo xung đột phiên bản và `custom_lint` không tương thích Dart 3.13) |
| Điều hướng | `go_router` 18 | `StatefulShellRoute.indexedStack` (5 tab); guard là hàm thuần `redirectFor` (có test) |
| Mạng | `dio` | `AuthInterceptor`: gắn Bearer, làm mới trước hạn 30 s, 401 → refresh **single-flight** → thử lại đúng 1 lần; ánh xạ ProblemDetails → `ApiException` |
| Model | `json_annotation` + `json_serializable` | DTO viết tay (lớp tự viết, `fromJson` được sinh; `freezed` chưa dùng) ở `features/*/data`, file `*.g.dart` **được commit** (không dùng CI nên máy khác khỏi phải chạy build_runner). Không dùng client sinh từ OpenAPI |
| Tiền | `decimal` | `Decimal` end-to-end; `decimalFromJson` không qua `double` |
| Định dạng | `intl` + `flutter_localizations` | vi-VN; ngày kinh doanh hiển thị theo thành phần UTC (khớp web) |
| Lưu token | `flutter_secure_storage` | refresh token (xoay vòng, lưu token **mới** trước khi bỏ token cũ); access token chỉ ở bộ nhớ |
| Sinh trắc | `local_auth` | khoá nhanh (mở app/60 s ở nền); thiết bị không có khoá màn hình → tắt khoá nhanh và hiện cảnh báo ở Tài khoản |
| Mạng chập chờn | `connectivity_plus` | dải "đang offline" |
| Biểu đồ | `fl_chart` | donut danh mục; cột thanh khoản |
| UI | `skeletonizer`, `lucide_icons_flutter` | token màu/khoảng cách ở `core/ui/theme.dart` (từ `mob.css` của bản thiết kế), sáng + tối |
| Kiểm thử | `flutter_test`, `mocktail`, `build_runner` | fixture = **payload thật** lấy từ backend (`tool/capture_fixtures.mjs`) |
| Phân tích | `very_good_analysis` | một số lint tắt có chủ đích, xem `analysis_options.yaml` |

Font: Roboto mặc định của Material (chưa đóng gói font riêng).

## Thao tác ghi tiền (M2) – không thêm thư viện mới
- **`MoneyGate`** (`core/money`): `authorize()` kiểm tra online → vai trò ≥ Operator → thiết bị có khoá màn hình → xác thực. Mỗi thao tác phải gọi lại, không lưu kết quả. Thiết bị không có khoá màn hình thì **từ chối** (không cho qua).
- **`runMoneyAction`**: cổng → gọi API → báo lỗi thống nhất (409, lỗi theo trường, `traceId`). Lỗi mạng ở lệnh có `Idempotency-Key` được báo là "chưa rõ đã gửi", cho thử lại với **cùng khoá**.
- **`Idempotency-Key`**: sinh một lần khi mở form (mua: trong nháp; bán: gắn với bộ tham số, đổi tham số thì sinh khoá mới).
- Số tiền gửi lên là số JSON (`jsonNum`: số nguyên nếu không có phần lẻ), không qua `double` trong logic.
- Màn có chiều rộng nút: theme đặt `FilledButton` rộng tối đa; trong `Row`/`Wrap` phải đặt `minimumSize: Size(0, 48)`.

## Chưa thêm (làm ở mốc sau)
| Mốc | Mảng | Dự kiến |
|---|---|---|
| M3 | Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications`; `POST /api/devices` |
| M3 | Cache offline mã hoá | `drift` + SQLCipher (khoá trong secure storage) |
| M3 | PDF / tệp, ảnh CCCD | `pdfx`, `share_plus`, `image_picker`, `flutter_image_compress` |
| M3 | Lỗi/log | `sentry_flutter` (dự án Sentry riêng cho mobile), lọc PII/token |
| M0 (còn nợ) | Chống root/jailbreak, certificate pinning | đã chốt làm từ M0 nhưng **chưa cài**: cần chọn thư viện và thử trên thiết bị thật; bắt buộc bật ở staging/prod trước khi phát hành |
| M2 | Chặn chụp/ghi màn hình ở màn tiền | chưa chọn |
| M4 | TestFlight / Play nội bộ | chưa chọn (fastlane hay thủ công) |

## Quyết định đã chốt
1. Riverpod, không Bloc.
2. Cache offline mã hoá SQLCipher (khi làm M3).
3. Chống root/jailbreak + certificate pinning từ M0 (xem "còn nợ" ở trên).
4. Sentry mobile dùng dự án riêng.
