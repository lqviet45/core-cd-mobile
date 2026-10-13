# Core CD – Mobile (Flutter)

Ứng dụng di động iOS/Android cho hệ thống quản lý **Chứng chỉ tiền gửi (CCTG)**. Backend và web ở repo [`Core-CD-Management`](https://github.com/lqviet45/Core-CD-Management); repo này **chỉ** chứa app Flutter.

> **Trạng thái:** M0 (nền, đăng nhập, khoá nhanh), M1 (màn chỉ đọc) và **M2 (thao tác ghi tiền)** đã có mã: mua CCTG 3 bước + theo dõi giao dịch, bán/tất toán có xem trước, tất toán sớm/đúng hạn, chi lãi (từng CCTG và hàng loạt), thêm khách hàng. Mọi thao tác tiền đi qua `MoneyGate` (online → đủ quyền Operator → sinh trắc/mã thiết bị **ngay trước khi gửi**) và dùng `Idempotency-Key`. `flutter analyze` sạch, 79 test pass, `flutter build web` qua; các luồng ghi đã chạy với backend thật (bản web, sinh trắc giả) và đối chiếu số liệu trên API. **Chưa kiểm chứng:** Android/iOS thật (không có SDK/Xcode ở môi trường dựng), sinh trắc thật, push (M3), xử lý giao dịch mua/bán đến trạng thái Thành công (cần Kafka).

## Bắt đầu
1. Cài Flutter **stable** (`flutter doctor` sạch cho Android/iOS).
2. `tool/bootstrap.sh` (pub get + sinh `*.g.dart`).
3. Cấu hình môi trường: `cp env/dev.example.json env/dev.json`, sửa `API_BASE_URL` (emulator Android → `http://10.0.2.2:5080`); chạy `flutter run --dart-define-from-file=env/dev.json`. Đăng nhập thử bằng tài khoản seed của backend.
4. Đồng bộ hợp đồng API khi backend đổi: `tool/sync_api.sh ../Core-CD-Management`, rồi cập nhật DTO và fixture (`API=http://localhost:5080 PASS=... node tool/capture_fixtures.mjs`).
5. Firebase (push, M3): thêm `google-services.json` / `GoogleService-Info.plist` – **không commit**.
6. Trước khi đẩy mã: `tool/check.sh`. Dự án **không dùng CI**.
7. Duyệt các luồng ghi trên web với backend thật: `flutter build web --target=tool/verify/verify_web_main.dart --dart-define=API_BASE_URL=http://localhost:5080` (bản này thay sinh trắc bằng bản luôn đồng ý vì `local_auth` không chạy trên web; **chỉ để kiểm thử, không phát hành**). Làm mới fixture của luồng ghi: `WRITES=1 API=... PASS=... node tool/capture_fixtures.mjs` (làm thay đổi dữ liệu thử nghiệm!).

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
