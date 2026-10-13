# Tech stack

> App này là **app nhân viên** (Viewer/Operator/Admin). App khách hàng là giai đoạn sau, chưa có thiết kế/backend.

Cập nhật 13/10/2026 theo mã thực tế (M0–M3). Phiên bản: `pubspec.yaml` / `pubspec.lock` là nguồn sự thật. Flutter stable 3.47 (Dart 3.13), Material 3, Android minSdk theo mặc định Flutter, iOS 15+.

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
| Cache offline | `cryptography` | AES-256-GCM thuần Dart; xem mục M3 bên dưới |
| Tuỳ chọn | `shared_preferences` | chỉ tuỳ chọn không nhạy cảm (giao diện, tự khoá, ẩn số tiền, lịch sử tìm kiếm) |
| Tệp | `url_launcher`, `share_plus`, `image_picker` | mở PDF bằng ứng dụng hệ thống, chia sẻ, chụp/chọn ảnh giấy tờ |
| Kiểm thử | `flutter_test`, `mocktail`, `build_runner` | fixture = **payload thật** lấy từ backend (`tool/capture_fixtures.mjs`) |
| Phân tích | `very_good_analysis` | một số lint tắt có chủ đích, xem `analysis_options.yaml` |

Font: Roboto mặc định của Material (chưa đóng gói font riêng).

## Thao tác ghi tiền (M2) – không thêm thư viện mới
- **`MoneyGate`** (`core/money`): `authorize()` kiểm tra online → vai trò ≥ Operator → thiết bị có khoá màn hình → xác thực. Mỗi thao tác phải gọi lại, không lưu kết quả. Thiết bị không có khoá màn hình thì **từ chối** (không cho qua).
- **`runMoneyAction`**: cổng → gọi API → báo lỗi thống nhất (409, lỗi theo trường, `traceId`). Lỗi mạng ở lệnh có `Idempotency-Key` được báo là "chưa rõ đã gửi", cho thử lại với **cùng khoá**.
- **`Idempotency-Key`**: sinh một lần khi mở form (mua: trong nháp; bán: gắn với bộ tham số, đổi tham số thì sinh khoá mới).
- Số tiền gửi lên là số JSON (`jsonNum`: số nguyên nếu không có phần lẻ), không qua `double` trong logic.
- Màn có chiều rộng nút: theme đặt `FilledButton` rộng tối đa; trong `Row`/`Wrap` phải đặt `minimumSize: Size(0, 48)`.

## M3 – cache offline, tìm kiếm, cài đặt, tài liệu, push
- **Cache offline** (`core/cache`): `CacheInterceptor` của dio chỉ lưu phản hồi **GET 200** (JSON) và chỉ phát lại khi **lỗi mạng/timeout** (không phát lại 4xx/5xx). Khoá logic = `userId|uri`; mỗi mục mã hoá **AES-256-GCM** (nonce ngẫu nhiên, AAD = khoá logic nên hoán đổi tệp bị từ chối), tên tệp là SHA-256 của khoá logic (không lộ URL/CIF), khoá AES ở `flutter_secure_storage`. Tối đa 7 ngày. Đăng xuất/hết phiên: xoá toàn bộ bản đệm **và huỷ khoá**. Trên web/test dùng bộ nhớ (`MemoryBlobStore`), trên thiết bị dùng tệp (`FileBlobStore`). Lỗi giải mã/hết hạn → coi như không có bản đệm.
  - **Lệch so với quyết định ban đầu** (drift + SQLCipher): chọn tệp mã hoá thuần Dart vì kiểm thử được hoàn toàn ở máy không có SDK/thiết bị, không kéo thêm thư viện native, và đúng nhu cầu "đọc lại màn đã xem" (không truy vấn quan hệ). Đổi lại, không có truy vấn trên dữ liệu đệm và chưa dọn theo dung lượng (chỉ theo hạn 7 ngày + khi đăng xuất).
- **Tìm kiếm** (M27): backend chưa có API tìm toàn cục nên app gọi song song `GET /api/customers?searchTerm`, `GET /api/certificates?searchTerm` và (nếu từ khoá giống CIF) `GET /api/transactions?cif`. Một nhóm lỗi không làm mất nhóm khác. Lịch sử từ khoá lưu cục bộ (tối đa 8), xoá khi đăng xuất.
- **Cài đặt** (M24): tuỳ chọn thiết bị ở `shared_preferences`; bật/tắt loại thông báo ở **máy chủ** (`GET/PUT /api/notifications/preferences`). Tắt khoá nhanh phải xác thực sinh trắc; thao tác tiền luôn cần xác thực riêng bất kể cài đặt.
- **Tài liệu**: `DocumentsSection` (chỉ Operator+) trên chi tiết giao dịch/CCTG/khách hàng. Mở/chia sẻ dùng URL ngắn hạn từ `POST /api/documents/{id}/download-link`; tải lên: `POST /api/documents/uploads` → `PUT` thẳng lên kho bằng **Dio trần** (không gắn token) → `POST .../confirm`. Tệp tạm khi chia sẻ bị xoá ngay.
- **Push**: xem [`PUSH.md`](PUSH.md). `PushRegistrar` không phụ thuộc trạng thái đăng nhập (tránh vòng phụ thuộc với `AuthController.logout`); `pushLifecycleProvider` nối với đăng nhập.
- **Không tự thử lại**: Riverpod 3 mặc định thử lại provider lỗi 10 lần; app tắt hẳn (`retry: noAutoRetry` ở `ProviderScope`) để lỗi hiện ngay và không gọi dồn máy chủ.
- **Điều hướng từ route ngoài shell** (`/search`, `/notifications`): dùng `context.go`, không `push`, vì push một route của shell sẽ trùng khoá trang với shell đang có (assert ở debug).

## Chưa thêm (làm ở mốc sau)
| Mốc | Mảng | Dự kiến |
|---|---|---|
| M3 (còn lại) | Push thật | `firebase_core`, `firebase_messaging` (+ `flutter_local_notifications` nếu cần banner khi đang mở); logic app đã xong, xem `PUSH.md` |
| M3 (còn lại) | Xem PDF ngay trong app | hiện mở bằng ứng dụng hệ thống; `pdfx` nếu muốn xem trong app |
| M3 | Lỗi/log | `sentry_flutter` (dự án Sentry riêng cho mobile), lọc PII/token |
| M0 (còn nợ) | Chống root/jailbreak, certificate pinning | đã chốt làm từ M0 nhưng **chưa cài**: cần chọn thư viện và thử trên thiết bị thật; bắt buộc bật ở staging/prod trước khi phát hành |
| M2 | Chặn chụp/ghi màn hình ở màn tiền | chưa chọn |
| M4 | TestFlight / Play nội bộ | chưa chọn (fastlane hay thủ công) |

## Quyết định đã chốt
1. Riverpod, không Bloc.
2. Cache offline mã hoá (đã làm bằng AES-GCM thuần Dart thay vì SQLCipher, xem mục M3).
3. Chống root/jailbreak + certificate pinning từ M0 (xem "còn nợ" ở trên).
4. Sentry mobile dùng dự án riêng.
