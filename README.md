# Core CD – Mobile (Flutter)

Ứng dụng di động iOS/Android cho hệ thống quản lý **Chứng chỉ tiền gửi (CCTG)**. Backend và web ở repo [`Core-CD-Management`](https://github.com/lqviet45/Core-CD-Management); repo này **chỉ** chứa app Flutter.

> **Trạng thái:** M0 (nền, đăng nhập, khoá nhanh) và M1 (màn chỉ đọc: Tổng quan, CCTG, Giao dịch, Khách hàng, Đợt phát hành, Lịch đáo hạn, Báo cáo, Thông báo, Trạng thái, Tài khoản & phiên) đã có mã. `flutter analyze` sạch, 45 test pass, `flutter build web` qua, bản web đã chạy với backend thật. **Chưa kiểm chứng:** build/chạy trên Android/iOS thật (môi trường dựng không có Android SDK/Xcode), sinh trắc thật, push. Chưa có thao tác ghi (M2).

## Bắt đầu
1. Cài Flutter **stable** (`flutter doctor` sạch cho Android/iOS).
2. `tool/bootstrap.sh` (pub get + sinh `*.g.dart`).
3. Cấu hình môi trường: `cp env/dev.example.json env/dev.json`, sửa `API_BASE_URL` (emulator Android → `http://10.0.2.2:5080`); chạy `flutter run --dart-define-from-file=env/dev.json`. Đăng nhập thử bằng tài khoản seed của backend.
4. Đồng bộ hợp đồng API khi backend đổi: `tool/sync_api.sh ../Core-CD-Management`, rồi cập nhật DTO và fixture (`API=http://localhost:5080 PASS=... node tool/capture_fixtures.mjs`).
5. Firebase (push, M3): thêm `google-services.json` / `GoogleService-Info.plist` – **không commit**.
6. Trước khi đẩy mã: `tool/check.sh`. Dự án **không dùng CI**.

## Tài liệu
| Tệp | Nội dung |
|---|---|
| [`docs/STACK.md`](docs/STACK.md) | Tech stack và các quyết định đã chốt |
| [`docs/BACKEND_CONTRACT.md`](docs/BACKEND_CONTRACT.md) | Cách gọi API (đăng nhập, phiên, push, lỗi, ghi tiền), quy tắc, lộ trình M0–M3. **Bản gốc ở repo backend** (`docs/MOBILE.md`) – đồng bộ bằng `tool/sync_api.sh`, đừng sửa ở đây |
| [`openapi/openapi.v1.json`](openapi/openapi.v1.json) | Hợp đồng API (bản sao từ backend) |
| `.cursor/rules/mobile.mdc`, `CLAUDE.md` | Quy ước cho người/AI cùng làm |

## Quy tắc then chốt
- Thao tác tiền **luôn** cần sinh trắc ngay trước khi gửi; `Idempotency-Key` sinh một lần khi mở form.
- Offline **chỉ đọc**; nút ghi bị khoá khi mất mạng.
- Tiền dùng `Decimal`, không dùng `double`. Không đưa token/PII vào log hay báo cáo lỗi.
- Không commit bí mật (Firebase, khoá ký, `env/*.json`).

## Lộ trình
M0 nền → M1 chỉ đọc → M2 ghi + sinh trắc → M3 thông báo & hoàn thiện (chi tiết ở `docs/BACKEND_CONTRACT.md` §4 và `PLAN.md` của backend).
