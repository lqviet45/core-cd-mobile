# Core CD – Ứng dụng di động (Flutter)

Mã Flutter nằm ở **repo riêng** (đề xuất `core-cd-mobile`, private). Tài liệu này là hợp đồng giữa hai repo: cấu trúc dự kiến, cách nói chuyện với API, và các quy tắc đã chốt trong `PLAN.md` (Đợt 2). Chưa có mã Flutter nào được dựng hay chạy thử ở đây (môi trường làm việc không có Flutter SDK).

## 1. Cấu trúc thư mục (feature-first, tách lớp theo từng tính năng)

```
core-cd-mobile/
├── pubspec.yaml · analysis_options.yaml · README.md
├── openapi/openapi.v1.json            # bản sao hợp đồng từ repo backend (đồng bộ bằng tool/sync_api.sh)
├── tool/
│   ├── sync_api.sh                    # lấy openapi.v1.json từ repo backend
│   └── gen_api.sh                     # sinh client Dart từ OpenAPI (dart-dio) vào lib/generated/
├── lib/
│   ├── main.dart · app.dart           # MaterialApp.router, theme sáng/tối, locale vi-VN
│   ├── flavors/                       # dev · staging · prod (địa chỉ API, tên app, bật/tắt log)
│   ├── generated/                     # client + model sinh từ OpenAPI (KHÔNG sửa tay, không commit nếu sinh được trong build)
│   ├── core/
│   │   ├── network/                   # Dio, interceptor xác thực (single-flight refresh), ánh xạ ProblemDetails → lỗi miền, Idempotency-Key
│   │   ├── auth/                      # SessionManager, TokenStore (flutter_secure_storage), BiometricGate (local_auth)
│   │   ├── push/                      # firebase_messaging, PushRegistrar (đăng ký/huỷ token), điều hướng từ thông báo
│   │   ├── cache/                     # bộ nhớ đệm chỉ-đọc cho chế độ offline (drift/sqlite)
│   │   ├── router/                    # go_router + guard (đăng nhập, khoá nhanh, vai trò)
│   │   ├── ui/                        # design tokens, MoneyText, StatusBadge, EmptyState, Skeleton, ErrorState
│   │   └── utils/                     # định dạng tiền/ngày vi-VN, che CCCD/MST, Decimal
│   └── features/
│       ├── auth/ dashboard/ certificates/ customers/ lots/ reports/      # M0–M1 (chỉ đọc)
│       ├── trading/ settlement/ interest/                                  # M2 (ghi, bắt buộc sinh trắc)
│       └── notifications/ settings/ search/                                # M3
│           └── mỗi feature:  data/ (repository, mapper) · domain/ (entity, use case) · presentation/ (screen, controller, widget)
├── test/                              # unit + widget + golden
└── integration_test/                  # luồng chính trên emulator, trỏ vào API staging
```

**Gợi ý thư viện** (chốt khi dựng M0): `flutter_riverpod` (+ generator), `go_router`, `dio`, `freezed`/`json_serializable`, `flutter_secure_storage`, `local_auth`, `firebase_core` + `firebase_messaging`, `drift`, `decimal`/`intl`.

## 2. Hợp đồng API cho mobile (đã có ở backend)

| Việc | Cách làm |
|---|---|
| Đăng nhập | `POST /api/auth/login` **không** gửi `X-Auth-Mode: cookie` → refresh token trả trong body. Lưu refresh token ở secure storage, access token chỉ giữ trong bộ nhớ. Gửi `deviceName` (vd "Pixel 8 · Android 15") để hiện trong danh sách phiên |
| Làm mới phiên | `POST /api/auth/refresh` `{refreshToken, deviceName}`. Token **xoay vòng**, mỗi token dùng một lần ⇒ chỉ cho **một** lời gọi refresh chạy tại một thời điểm (single-flight), các request chờ kết quả đó. Dùng lại token đã xoay bị coi là bị đánh cắp và đăng xuất mọi thiết bị |
| Đăng xuất | **Trước**: `POST /api/devices/unregister {token}` (thôi nhận push của tài khoản này), **sau đó** `POST /api/auth/logout {refreshToken}` |
| Phiên đăng nhập | `GET /api/auth/sessions` (không đánh dấu "phiên này" ở chế độ body), `DELETE /api/auth/sessions/{id}`, `POST /api/auth/sessions/revoke-others {refreshToken}` |
| Push | Sau đăng nhập và mỗi lần FCM đổi token: `POST /api/devices {token, platform: "Android"\|"iOS", appVersion, deviceName}` (idempotent). Một token chỉ thuộc một người dùng – đăng nhập tài khoản khác trên cùng máy sẽ chuyển token sang người đó |
| Nội dung push | `notification{title, body}` + `data{notificationId, type, link}`. `type` ∈ `NearMaturity · TransactionFailed · LotNearlySoldOut · JobSummary`; `link` là đường dẫn web (vd `/transactions/{id}`, `/lots/{id}`) – mobile ánh xạ theo `type` + id sang màn hình tương ứng. Không có dữ liệu cá nhân của khách hàng trong push. Kênh Android: `cd_alerts` (app phải tạo kênh này) |
| Danh sách thông báo | `GET /api/notifications`, `GET /api/notifications/unread-count`, `POST /api/notifications/mark-read`, `GET/PUT /api/notifications/preferences` |
| Lỗi | RFC 7807 `ProblemDetails` (`title`, `errors` theo field, `traceId`). 401 → refresh một lần rồi thử lại; 403 → thiếu quyền; 409 → dữ liệu vừa đổi, tải lại; 429 → chờ |
| Ghi tiền | Gửi header `Idempotency-Key` (UUID sinh **một lần** khi mở form, giữ nguyên khi thử lại). Xem trước (`preview`) trước khi gửi và gửi kèm tổng kỳ vọng ở thao tác hàng loạt |

## 3. Quy tắc đã chốt

1. **Thao tác tiền luôn yêu cầu sinh trắc** ngay trước khi gửi (`local_auth`); không lưu kết quả xác thực để dùng lại.
2. **Offline chỉ đọc**: dữ liệu đọc được lưu đệm; nút ghi bị khoá và có dải "đang offline". Không xếp hàng lệnh ghi để gửi sau.
3. **Tiền không dùng `double`**: VND là số nguyên – parse JSON sang `Decimal`/`BigInt`, định dạng `1.234.567 ₫`.
4. **Số CCCD/MST luôn che** (API đã trả bản che); xem đầy đủ là hành động có ghi nhật ký (`reveal-identity`).
5. Mọi chuỗi hiển thị bằng tiếng Việt; lỗi hiển thị `title` của ProblemDetails + `traceId` để hỗ trợ.
6. Không đưa token (refresh, FCM), mật khẩu, PII vào log/crash report.

## 4. Lộ trình (theo PLAN)

| Mốc | Phạm vi | Màn |
|---|---|---|
| **M0** | Nền: flavors, theme, client sinh từ OpenAPI, auth + secure storage, sinh trắc, khoá nhanh | M01–M02 |
| **M1** | Chỉ đọc | M03 Tổng quan, M05–M06 CCTG, M10–M11 Khách hàng, M19–M21 Lô & lịch, M22 Báo cáo, M26 Trạng thái |
| **M2** | Ghi + sinh trắc | M13–M16 Mua, M17–M18 Lịch sử & bán, M07–M08 Tất toán sớm, M09 Chi lãi, M12 Thêm khách |
| **M3** | Thông báo & hoàn thiện | M04 Thông báo + push, M23–M25, M27 Tìm kiếm, PDF hợp đồng, chụp CCCD, offline đọc |
