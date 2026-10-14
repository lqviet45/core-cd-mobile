# Core CD – Ứng dụng di động (Flutter)

> **Có hai app trong cùng repo mobile:** app **nhân viên** (Viewer/Operator/Admin, các mục 1–4) và app **khách hàng** (chỉ xem dữ liệu của chính mình, đăng nhập OTP — xem mục 5). Hai nhóm API tách hẳn: token khách không dùng được API nhân viên và ngược lại.

Mã Flutter nằm ở **repo riêng** (đề xuất `core-cd-mobile`, private). Tài liệu này là hợp đồng giữa hai repo: cấu trúc dự kiến, cách nói chuyện với API, và các quy tắc đã chốt trong `PLAN.md` (Đợt 2). Mã Flutter đã dựng ở repo `core-cd-mobile` (M0 + M1); các phần dưới đây là thiết kế ban đầu – chỗ nào khác thực tế thì **`docs/STACK.md` của repo mobile là nguồn đúng** (xem ghi chú sau mục 1).

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

**Thực tế khi dựng M0/M1 (13/10/2026), khác thiết kế trên:** không dùng client sinh từ OpenAPI (`gen_api.sh`, `lib/generated/` đã bỏ) mà viết DTO tay bằng `json_serializable` và kiểm bằng fixture lấy từ API thật; Riverpod viết tay (không generator), không `freezed`; chưa có `flavors/`, `push/`, `cache/` (đến M3); `domain/` chưa tách riêng. Chi tiết: `docs/STACK.md` ở repo mobile.

**Gợi ý thư viện ban đầu**: `flutter_riverpod` (+ generator), `go_router`, `dio`, `freezed`/`json_serializable`, `flutter_secure_storage`, `local_auth`, `firebase_core` + `firebase_messaging`, `drift`, `decimal`/`intl`.

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

## 5. App khách hàng (`/api/customer/*`)

**Phạm vi hiện tại: chỉ đọc.** Khách xem hồ sơ, tổng quan, CCTG đang giữ/đã đóng, lịch nhận lãi, lịch sử giao dịch, tải hợp đồng/chứng chỉ. Chưa có mua/bán/tất toán, thông báo và push cho khách (thông báo hiện là nội bộ cho nhân viên) — làm ở giai đoạn sau.

### Cấp quyền (nhân viên)
Khách chỉ đăng nhập được khi **nhân viên đã xác minh khách trực tiếp** rồi bật quyền:

| Việc | API (Operator/Admin) |
|---|---|
| Xem trạng thái | `GET /api/customers/{id}/app-access` → `{enabled, phoneMasked, lastLoginAt, enabledAt}` |
| Bật / cấp lại / đổi số | `PUT /api/customers/{id}/app-access` `{phone?}` (bỏ trống = số trong hồ sơ). Đổi số ⇒ mọi phiên cũ bị thu hồi. 409 nếu số đã thuộc khách khác; 422 nếu không phải số di động VN |
| Thu hồi | `DELETE /api/customers/{id}/app-access` ⇒ khoá ngay (access token còn hạn cũng vô hiệu vì mỗi request đọc lại DB) và thu hồi mọi refresh token |

### Đăng nhập OTP (ẩn danh, giới hạn 10 request/phút/IP)
| Bước | API |
|---|---|
| Xin mã | `POST /api/customer/auth/otp/request {phone}` → `{expiresInSeconds, resendAfterSeconds}`. **Luôn trả cùng kết quả** dù số có tài khoản hay không (không lộ ai là khách). Chỉ tài khoản đang bật mới được gửi SMS; ≥ 60 giây giữa hai mã, tối đa 5 mã/giờ/số; mã mới thay mã cũ. `phone` nhận `09…`, `+849…`, `849…` |
| Xác thực | `POST /api/customer/auth/otp/verify {phone, code, deviceName?}` → `{accessToken, accessTokenExpiresAt, refreshToken, refreshTokenExpiresAt, customer}`. Mã 6 số, hiệu lực 5 phút, dùng một lần, sai 5 lần thì huỷ mã. Mọi lỗi đều 401 "Mã OTP không đúng hoặc đã hết hạn." |
| Làm mới | `POST /api/customer/auth/refresh {refreshToken, deviceName?}` — xoay vòng, **single-flight** như app nhân viên; dùng lại token đã xoay ⇒ thu hồi mọi phiên. Refresh token sống 30 ngày |
| Đăng xuất | `POST /api/customer/auth/logout {refreshToken}` (204, idempotent) |

Token khách: role `Customer`, claim `acct` = id tài khoản; **không** dùng được ở `/api/*` của nhân viên (403) và `/api/auth/refresh` của nhân viên không nhận refresh token khách.

### Dữ liệu (Bearer token khách; mọi response `Cache-Control: no-store`)
| Việc | API |
|---|---|
| Hồ sơ | `GET /api/customer/me` (CCCD/MST và số điện thoại đã che) |
| Tổng quan | `GET /api/customer/summary` → số CCTG đang giữ, tổng gốc, lãi dự kiến, lãi đã nhận, kỳ đáo hạn gần nhất |
| CCTG | `GET /api/customer/certificates?scope=All\|Holding\|Closed&pageNumber&pageSize`, `GET /api/customer/certificates/{id}` |
| Lịch lãi | `GET /api/customer/certificates/{id}/interest-schedule` — trạng thái kỳ chỉ có `Paid · Upcoming · Due` |
| Giao dịch | `GET /api/customer/transactions?type&status&pageNumber&pageSize`, `GET /api/customer/transactions/{id}` (không có kênh, người thao tác, lỗi nội bộ) |
| Tài liệu | `GET /api/customer/certificates/{id}/documents`, `GET /api/customer/transactions/{id}/documents` (chỉ hợp đồng/chứng chỉ; KYC không bao giờ lộ), `POST /api/customer/documents/{id}/download-link` → URL 5 phút, mỗi lần cấp ghi nhật ký (`CreateMyDocumentDownloadLink`) |

**Cô lập dữ liệu:** khách luôn được xác định từ token; không có tham số `customerId`. Tài nguyên của người khác trả **404** như không tồn tại.

### Vận hành
- Kênh SMS chưa chọn nhà cung cấp. `Otp:Provider=Log` (chỉ Development) ghi mã vào log; mặc định `Disabled`: không gửi được, API ghi **lỗi** vào log/Sentry mỗi lần xin mã (phản hồi cho khách vẫn y hệt). Cắm nhà cung cấp thật bằng cách hiện thực `IOtpSender`.
- OTP băm HMAC-SHA256 gắn với số điện thoại (khoá dẫn xuất từ `Jwt:Key`); không lưu mã thô.
- Số điện thoại ngoài Việt Nam chưa hỗ trợ.
- **Giới hạn đã biết:** phản hồi xin OTP giống hệt nhau, nhưng thời gian phản hồi của số có tài khoản dài hơn (ghi DB + gọi kênh SMS) nên kẻ tấn công đo giờ có thể suy ra số nào là khách. Giảm nhẹ bằng giới hạn 10 request/phút/IP và 5 mã/giờ/số; muốn triệt để thì gửi SMS qua hàng đợi nền. Chưa có push/thông báo cho khách, chưa có khoá app (PIN/sinh trắc) ở app khách.
