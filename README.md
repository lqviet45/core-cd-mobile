# Core CD – Mobile (Flutter)

Ứng dụng di động iOS/Android cho hệ thống quản lý **Chứng chỉ tiền gửi (CCTG)**.

> **Hai app trong cùng repo.** (1) **App nhân viên** (Viewer / Operator / Admin; điểm vào `lib/main.dart`) bám các artboard `Mob*` của thiết kế. (2) **App khách hàng** (chỉ xem dữ liệu của chính mình; điểm vào `lib/main_customer.dart`, mã ở `lib/features/customer_app`): đăng nhập bằng SĐT + OTP, tổng quan, CCTG đang giữ/đã đóng, lịch nhận lãi, giao dịch, tải hợp đồng/chứng chỉ. Khách chỉ đăng nhập được sau khi nhân viên bật quyền (`PUT /api/customers/{id}/app-access`). Backend và web ở repo [`Core-CD-Management`](https://github.com/lqviet45/Core-CD-Management); repo này **chỉ** chứa app Flutter.

> **App khách hàng – trạng thái:** có mã, `flutter analyze` sạch, 198 test pass (19 mới: DTO theo payload thật, đăng nhập OTP, tài liệu, đăng xuất). Phần đọc/đăng nhập/refresh/đăng xuất đã chạy với **backend thật** qua `test/live/customer_live_test.dart` (xem file để chạy lại). **Chưa làm:** mua/bán/tất toán (app khách chỉ xem), thông báo + push cho khách (thông báo hiện là nội bộ), khoá app bằng PIN/sinh trắc, thiết kế UI riêng (đang dùng lại theme/thành phần của app nhân viên), **flavor Android/iOS với applicationId/bundle riêng** (hiện hai app dùng chung ID; chạy bằng `flutter run -t lib/main_customer.dart`), kênh SMS thật phía backend. **Chưa kiểm chứng:** thiết bị Android/iOS thật, mở PDF bằng plugin nền tảng, tải tài liệu với kho tệp thật.

> **Trạng thái:** M0–M2 (nền, chỉ đọc, thao tác ghi tiền), **M3 (hoàn thiện app nhân viên)** và phần bổ sung **Admin + mã PIN** đã có mã. M3: cache đọc offline mã hoá (AES-256-GCM) kèm dải "dữ liệu lưu lúc", tìm kiếm toàn cục (khách hàng · CCTG · giao dịch theo CIF), Cài đặt (giao diện, tự khoá, ẩn số tiền, bật/tắt từng loại thông báo, đổi mật khẩu), tài liệu (mở/chia sẻ PDF, tạo hợp đồng/chứng chỉ, chụp/tải ảnh CCCD–ĐKKD), đăng ký thiết bị push + điều hướng khi chạm thông báo. `flutter analyze` sạch, 179 test pass, `flutter build web` qua; tìm kiếm, cài đặt (ghi lên máy chủ), ẩn số tiền, giao diện tối và cache offline đã chạy với backend thật (bản web). **Chưa kiểm chứng:** Android/iOS thật (không có SDK/Xcode ở môi trường dựng), sinh trắc thật, **push** (chưa có dự án Firebase → đang dùng nguồn token rỗng, xem [`docs/PUSH.md`](docs/PUSH.md)), **camera/chia sẻ tệp/mở PDF** (plugin nền tảng), **tạo/tải tài liệu với kho tệp thật** (MinIO không chạy ở môi trường dựng; chỉ kiểm chứng đường lỗi 503 và danh sách rỗng, còn lại bằng test với máy chủ giả), xử lý giao dịch mua/bán đến trạng thái Thành công (cần Kafka). Bổ sung sau M3: **Chính sách lãi suất** (mọi vai trò xem, Admin thêm/sửa/ngừng), **Người dùng** và **Nhật ký thao tác** (chỉ Admin), **mã PIN 6 số** mở app (xem `docs/STACK.md`); đã chạy với backend thật trên web (tạo/sửa/đặt lại mật khẩu/vô hiệu hoá người dùng, tạo chính sách lãi suất, đặt PIN và mở khoá bằng PIN). **Chưa cài:** chống root/jailbreak, certificate pinning.

## Bắt đầu
1. Cài Flutter **stable** (`flutter doctor` sạch cho Android/iOS).
2. `tool/bootstrap.sh` (pub get + sinh `*.g.dart`).
3. Cấu hình môi trường (app khách hàng: thêm `-t lib/main_customer.dart`; backend dev cần `Otp:Provider=Log` để đọc mã OTP trong log API; dựng dữ liệu thử + fixture: `tool/capture_customer_fixtures.mjs`): `cp env/dev.example.json env/dev.json`, sửa `API_BASE_URL` (emulator Android → `http://10.0.2.2:5080`); chạy `flutter run --dart-define-from-file=env/dev.json`. Đăng nhập thử bằng tài khoản seed của backend.
4. Đồng bộ hợp đồng API khi backend đổi: `tool/sync_api.sh ../Core-CD-Management`, rồi cập nhật DTO và fixture (`API=http://localhost:5080 PASS=... node tool/capture_fixtures.mjs`).
5. Firebase (push): chưa bật – làm theo [`docs/PUSH.md`](docs/PUSH.md); tệp `google-services.json` / `GoogleService-Info.plist` **không commit**.
6. Trước khi đẩy mã: `tool/check.sh`. Dự án **không dùng CI**.
7. Duyệt các luồng ghi trên web với backend thật: `flutter build web --target=tool/verify/verify_web_main.dart --dart-define=API_BASE_URL=http://localhost:5080` (bản này thay sinh trắc bằng bản luôn đồng ý vì `local_auth` không chạy trên web; **chỉ để kiểm thử, không phát hành**). Làm mới fixture của luồng ghi: `WRITES=1 API=... PASS=... node tool/capture_fixtures.mjs` (làm thay đổi dữ liệu thử nghiệm!).

## Tài liệu
| Tệp | Nội dung |
|---|---|
| [`docs/STACK.md`](docs/STACK.md) | Tech stack và các quyết định đã chốt |
| [`docs/PUSH.md`](docs/PUSH.md) | Push: phần đã có, cách bật Firebase, việc cần thử trên thiết bị thật |
| [`docs/BACKEND_CONTRACT.md`](docs/BACKEND_CONTRACT.md) | Cách gọi API (đăng nhập, phiên, push, lỗi, ghi tiền), quy tắc, lộ trình M0–M3. **Bản gốc ở repo backend** (`docs/MOBILE.md`) – đồng bộ bằng `tool/sync_api.sh`, đừng sửa ở đây |
| [`openapi/openapi.v1.json`](openapi/openapi.v1.json) | Hợp đồng API (bản sao từ backend) |
| `.cursor/rules/mobile.mdc`, `CLAUDE.md` | Quy ước cho người/AI cùng làm |

## Quy tắc then chốt
- Thao tác tiền **luôn** cần sinh trắc ngay trước khi gửi; `Idempotency-Key` sinh một lần khi mở form.
- Offline **chỉ đọc**; nút ghi bị khoá khi mất mạng.
- Tiền dùng `Decimal`, không dùng `double`. Không đưa token/PII vào log hay báo cáo lỗi.
- Không commit bí mật (Firebase, khoá ký, `env/*.json`).

## Lộ trình
M0 nền → M1 chỉ đọc → M2 ghi + sinh trắc → M3 hoàn thiện (offline, tìm kiếm, cài đặt, tài liệu, push) → M4 phát hành nội bộ (chi tiết ở `docs/BACKEND_CONTRACT.md` §4 và `PLAN.md` của backend).
