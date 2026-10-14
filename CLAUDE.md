# Core CD Mobile – hướng dẫn cho Claude

- Đây là repo **Flutter** của hệ thống CCTG (app nhân viên `lib/main.dart` + app khách hàng chỉ-xem `lib/main_customer.dart`); backend/web ở repo `Core-CD-Management`. Đọc `docs/STACK.md` (thư viện đã chốt) và `docs/BACKEND_CONTRACT.md` (hợp đồng API + quy tắc) trước khi làm.
- `openapi/openapi.v1.json` và `docs/BACKEND_CONTRACT.md` là **bản sao** từ backend: không sửa tay, dùng `tool/sync_api.sh`. Cần API mới/đổi → làm ở repo backend trước.
- Môi trường soạn thảo của Claude thường **không có Flutter SDK**: không tuyên bố "đã chạy/đã test" mã Flutter nếu chưa chạy được; ghi rõ phần nào chưa kiểm chứng.
- Không dùng CI. Kiểm tra cục bộ bằng `tool/check.sh`.
- Không commit bí mật: `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, `env/*.json` (chỉ `*.example.json`), khoá ký, `*.p8/*.p12`.
- Commit kết thúc bằng các dòng Co-Authored-By / Claude-Session theo hướng dẫn của phiên.
- Quy ước chi tiết: `.cursor/rules/mobile.mdc`.
