# Core CD – Mobile (Flutter)

Ứng dụng di động iOS/Android cho hệ thống quản lý **Chứng chỉ tiền gửi (CCTG)**. Backend và web ở repo [`Core-CD-Management`](https://github.com/lqviet45/Core-CD-Management); repo này **chỉ** chứa app Flutter.

> **Trạng thái:** mới có khung tài liệu, hợp đồng API và script dựng dự án. **Chưa có mã Flutter** – dự án được dựng bằng `tool/bootstrap.sh` trên máy có Flutter SDK (môi trường soạn khung này không có SDK nên các script chưa chạy thử).

## Bắt đầu
1. Cài Flutter **stable** (`flutter doctor` sạch cho Android/iOS).
2. Dựng dự án một lần: `tool/bootstrap.sh <org-ngược-miền>` (vd `vn.com.tencongty` – quyết định bundle id, khó đổi sau này).
3. Đồng bộ hợp đồng API (khi backend đổi): `tool/sync_api.sh ../Core-CD-Management`, rồi `tool/gen_api.sh` để sinh client.
4. Cấu hình môi trường: `cp env/dev.example.json env/dev.json` và sửa `API_BASE_URL`; chạy `flutter run --dart-define-from-file=env/dev.json`.
5. Firebase (push): tạo dự án, thêm `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) – **không commit** (đã nằm trong `.gitignore`).
6. Trước khi đẩy mã: `tool/check.sh` (format, analyze, test). Dự án **không dùng CI**.

## Tài liệu
| Tệp | Nội dung |
|---|---|
| [`docs/STACK.md`](docs/STACK.md) | Tech stack và các quyết định đã chốt |
| [`docs/BACKEND_CONTRACT.md`](docs/BACKEND_CONTRACT.md) | Cấu trúc thư mục dự kiến, cách gọi API (đăng nhập, phiên, push, lỗi, ghi tiền), quy tắc, lộ trình M0–M3. **Bản gốc ở repo backend** (`docs/MOBILE.md`) – đồng bộ bằng `tool/sync_api.sh`, đừng sửa ở đây |
| [`openapi/openapi.v1.json`](openapi/openapi.v1.json) | Hợp đồng API (bản sao từ backend) |
| `.cursor/rules/mobile.mdc`, `CLAUDE.md` | Quy ước cho người/AI cùng làm |

## Quy tắc then chốt
- Thao tác tiền **luôn** cần sinh trắc ngay trước khi gửi; `Idempotency-Key` sinh một lần khi mở form.
- Offline **chỉ đọc**; nút ghi bị khoá khi mất mạng.
- Tiền dùng `Decimal`, không dùng `double`. Không đưa token/PII vào log hay báo cáo lỗi.
- Không commit bí mật (Firebase, khoá ký, `env/*.json`).

## Lộ trình
M0 nền → M1 chỉ đọc → M2 ghi + sinh trắc → M3 thông báo & hoàn thiện (chi tiết ở `docs/BACKEND_CONTRACT.md` §4 và `PLAN.md` của backend).
