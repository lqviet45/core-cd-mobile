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

**Phạm vi hiện tại: chỉ đọc.** Khách xem hồ sơ, tổng quan, CCTG đang gửi/đã tất toán, lịch nhận tiền, lịch sử giao dịch, tải hợp đồng/chứng chỉ. Chưa có mua/tất toán từ app (màn K10–K15 của thiết kế), thông báo + push cho khách (thông báo hiện là nội bộ cho nhân viên) — làm ở giai đoạn sau.

### Cấp quyền và mật khẩu (nhân viên)
Khách chỉ đăng nhập được khi **nhân viên đã xác minh khách trực tiếp** rồi bật quyền và **đưa mật khẩu tạm** (chưa có kênh SMS):

| Việc | API (Operator/Admin) |
|---|---|
| Xem trạng thái | `GET /api/customers/{id}/app-access` → `{enabled, phoneMasked, lastLoginAt, enabledAt, hasPassword}` |
| Bật / cấp lại quyền / đổi số | `PUT /api/customers/{id}/app-access` `{phone?}` (bỏ trống = số trong hồ sơ). Lần đầu trả `temporaryPassword` **một lần duy nhất** (không lấy lại được; phản hồi `no-store`). Đổi số ⇒ mọi phiên cũ bị thu hồi, mật khẩu giữ nguyên. 409 nếu số đã thuộc khách khác; 422 nếu không phải số di động VN |
| Cấp lại mật khẩu (khách quên) | `POST /api/customers/{id}/app-access/reset-password` → `temporaryPassword` mới; mọi phiên bị thu hồi; 422 nếu chưa bật quyền |
| Thu hồi | `DELETE /api/customers/{id}/app-access` ⇒ khoá ngay (access token còn hạn cũng vô hiệu vì mỗi request đọc lại DB) và thu hồi mọi refresh token |

### Đăng nhập (ẩn danh, giới hạn 10 request/phút/IP)
| Bước | API |
|---|---|
| Đăng nhập | `POST /api/customer/auth/login {identifier, password, deviceName?}` — `identifier` là **số điện thoại** (`09…`, `+849…`, `849…`) **hoặc mã khách hàng (CIF)**, không phân biệt hoa thường. Trả `{accessToken, accessTokenExpiresAt, refreshToken, refreshTokenExpiresAt, mustChangePassword, customer}`. Mọi lỗi đều 401 cùng một thông điệp; 5 lần sai khoá 15 phút |
| Đổi mật khẩu | `POST /api/customer/auth/change-password {currentPassword, newPassword, deviceName?}` (Bearer khách). **Bắt buộc ở lần đầu**: khi `mustChangePassword = true` mọi API khác trả **403** cho tới khi đổi. Mật khẩu mới ≥ 10 ký tự, có hoa/thường/số, khác mật khẩu cũ. Thu hồi mọi phiên cũ và trả **phiên mới** (cùng dạng kết quả đăng nhập) |
| Làm mới | `POST /api/customer/auth/refresh {refreshToken, deviceName?}` — xoay vòng, **single-flight** như app nhân viên; dùng lại token đã xoay ⇒ thu hồi mọi phiên. Refresh token sống 30 ngày |
| Đăng xuất | `POST /api/customer/auth/logout {refreshToken}` (204, idempotent) |

Token khách: role `Customer`, claim `acct` = id tài khoản; **không** dùng được ở `/api/*` của nhân viên (403) và `/api/auth/refresh` của nhân viên không nhận refresh token khách. Sinh trắc/PIN mở app là việc phía thiết bị (không có API).

### Dữ liệu (Bearer token khách; mọi response `Cache-Control: no-store`)
| Việc | API |
|---|---|
| Hồ sơ | `GET /api/customer/me` (CCCD/MST, số điện thoại, email đều đã che) |
| Tổng quan | `GET /api/customer/summary` → `holdingCount, closedCount, totalPrincipal, estimatedInterestTotal, interestReceivedTotal, nextMaturity*` |
| CCTG | `GET /api/customer/certificates?scope=All\|Holding\|Closed\|Active\|NearMaturity&pageNumber&pageSize` (`NearMaturity` gồm cả đã đến hạn chưa tất toán), `GET /api/customer/certificates/{id}` |
| Lịch lãi | `GET /api/customer/certificates/{id}/interest-schedule` — trạng thái kỳ chỉ có `Paid · Upcoming · Due` |
| **Lịch nhận tiền** | `GET /api/customer/upcoming?days=30` (1–366) → `{days, totalAmount, items[{date, kind: Interest\|Maturity, certificateId, certificateNumber, termName, amount, periodIndex, periodTotal, isDue}]}` sắp theo ngày. Kỳ lãi chưa chi; khoản đáo hạn = gốc + lãi hợp đồng nếu trả lãi cuối kỳ, chỉ gốc nếu trả lãi định kỳ. `isDue`: đã đến/quá ngày mà ngân hàng chưa ghi nhận chi |
| Giao dịch | `GET /api/customer/transactions?direction=In\|Out&type&status&pageNumber&pageSize` (`Out` = mua, `In` = tất toán/nhận lãi; không có kênh, người thao tác, lỗi nội bộ), `GET /api/customer/transactions/{id}` |
| Tài liệu | `GET /api/customer/certificates/{id}/documents`, `GET /api/customer/transactions/{id}/documents` (chỉ hợp đồng/chứng chỉ; KYC không bao giờ lộ), `POST /api/customer/documents/{id}/download-link` → URL 5 phút, mỗi lần cấp ghi nhật ký (`CreateMyDocumentDownloadLink`) |

**Cô lập dữ liệu:** khách luôn được xác định từ token; không có tham số `customerId`. Tài nguyên của người khác trả **404** như không tồn tại.

### Vận hành và giới hạn
- **Chưa có kênh SMS/OTP** nên quên mật khẩu = đến quầy để nhân viên cấp lại (`reset-password`). Màn quản lý khách của nhân viên (web/mobile) **chưa có nút** bật quyền/cấp mật khẩu: hiện gọi trực tiếp API.
- Mật khẩu tạm chỉ hiện một lần trong phản hồi; hệ thống chỉ lưu băm PBKDF2. Mọi lần cấp/đổi mật khẩu đều có nhật ký (tham số mật khẩu bị che).
- Chưa có push/thông báo cho khách, chưa mua/tất toán từ app khách, số điện thoại ngoài Việt Nam chưa hỗ trợ.
