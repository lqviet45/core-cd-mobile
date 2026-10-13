# Core CD – Mobile (Flutter)

Ứng dụng di động iOS/Android cho hệ thống quản lý **Chứng chỉ tiền gửi (CCTG)**.

> **Đối tượng dùng: NHÂN VIÊN nghiệp vụ (vai trò Viewer / Operator / Admin), không phải khách hàng.** Màn hình bám các artboard `Mob*` của bản thiết kế (app companion của web back-office). **App dành cho khách hàng chưa làm:** cần định danh/đăng nhập khách hàng và phân quyền theo chủ sở hữu ở backend (hiện chỉ có người dùng nội bộ `AppUser`) cùng thiết kế UI riêng; sẽ chốt phạm vi ở giai đoạn sau. Backend và web ở repo [`Core-CD-Management`](https://github.com/lqviet45/Core-CD-Management); repo này **chỉ** chứa app Flutter.

> **Trạng thái:** M0–M2 (nền, chỉ đọc, thao tác ghi tiền) và **M3 (hoàn thiện app nhân viên)** đã có mã. M3: cache đọc offline mã hoá (AES-256-GCM) kèm dải "dữ liệu lưu lúc", tìm kiếm toàn cục (khách hàng · CCTG · giao dịch theo CIF), Cài đặt (giao diện, tự khoá, ẩn số tiền, bật/tắt từng loại thông báo, đổi mật khẩu), tài liệu (mở/chia sẻ PDF, tạo hợp đồng/chứng chỉ, chụp/tải ảnh CCCD–ĐKKD), đăng ký thiết bị push + điều hướng khi chạm thông báo. `flutter analyze` sạch, 135 test pass, `flutter build web` qua; tìm kiếm, cài đặt (ghi lên máy chủ), ẩn số tiền, giao diện tối và cache offline đã chạy với backend thật (bản web). **Chưa kiểm chứng:** Android/iOS thật (không có SDK/Xcode ở môi trường dựng), sinh trắc thật, **push** (chưa có dự án Firebase → đang dùng nguồn token rỗng, xem [`docs/PUSH.md`](docs/PUSH.md)), **camera/chia sẻ tệp/mở PDF** (plugin nền tảng), **tạo/tải tài liệu với kho tệp thật** (MinIO không chạy ở môi trường dựng; chỉ kiểm chứng đường lỗi 503 và danh sách rỗng, còn lại bằng test với máy chủ giả), xử lý giao dịch mua/bán đến trạng thái Thành công (cần Kafka). **Chưa cài:** chống root/jailbreak, certificate pinning.

## Bắt đầu
1. Cài Flutter **stable** (`flutter doctor` sạch cho Android/iOS).
2. `tool/bootstrap.sh` (pub get + sinh `*.g.dart`).
3. Cấu hình môi trường: `cp env/dev.example.json env/dev.json`, sửa `API_BASE_URL` (emulator Android → `http://10.0.2.2:5080`); chạy `flutter run --dart-define-from-file=env/dev.json`. Đăng nhập thử bằng tài khoản seed của backend.
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
