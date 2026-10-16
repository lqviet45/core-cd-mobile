# Phát hành app (nhân viên + khách hàng)

Một codebase, hai app. Mỗi app có **flavor** riêng trên Android/iOS:

| | Nhân viên (`staff`) | Khách hàng (`customer`) |
|---|---|---|
| Điểm vào | `lib/main.dart` | `lib/main_customer.dart` |
| Android `applicationId` | `vn.corecd.core_cd_mobile` (giữ nguyên) | `vn.corecd.customer` |
| iOS bundle id | `vn.corecd.coreCdMobile` (giữ nguyên) | `vn.corecd.customer` |
| Tên hiển thị | CCTG Nhân viên | CCTG |
| Icon | mặc định Flutter (chờ icon thương hiệu) | `tool/gen_customer_icon.py` (tạm; thay bằng icon thật) |
| Khoá ký Android | `android/key.staff.properties` | `android/key.customer.properties` |

Khi có icon/tên thương hiệu thật: sửa `manifestPlaceholders["appName"]` trong `android/app/build.gradle.kts`, `APP_DISPLAY_NAME` trong `tool/setup_ios_flavors.rb` (chạy lại, idempotent) và thay file icon cùng tên.

## 1. Cấu hình môi trường (`env/*.json`, không commit)

```bash
cp env/prod.example.json env/prod.json   # rồi sửa
```

| Khoá | Ý nghĩa |
|---|---|
| `API_BASE_URL` | Gốc API. **prod bắt buộc `https`** (app từ chối khởi động nếu không) |
| `ENV_NAME` | `dev` / `staging` / `prod` |
| `SENTRY_DSN` | DSN dự án Sentry **riêng cho từng app** (rỗng = tắt báo lỗi). Dữ liệu được lọc cứng trong `lib/core/telemetry/crash_reporting.dart` (không PII, không ảnh chụp, không request, bỏ token/email/số dài) |
| `SUPPORT_PHONE` | Hotline hỗ trợ khách (vd `1900 1234`). Rỗng = app KH chỉ hiện hướng dẫn "đến chi nhánh/liên hệ chuyên viên", **không có nút gọi**. Số này phải do nghiệp vụ cung cấp, không tự đặt |
| `APP_VERSION` | Gắn vào báo lỗi (`customer@<APP_VERSION>`); nên trùng `--build-name+--build-number` |

## 2. Chạy khi phát triển

```bash
# App khách hàng
flutter run --flavor customer -t lib/main_customer.dart --dart-define-from-file=env/dev.json
# App nhân viên (từ nay phải có --flavor staff)
flutter run --flavor staff -t lib/main.dart --dart-define-from-file=env/dev.json
```

Emulator Android trỏ máy chủ host bằng `http://10.0.2.2:5080` (HTTP rõ ràng chỉ chấp nhận ở `dev`/`staging`).

## 3. Android

### Khoá ký (làm một lần, mỗi app một khoá)

```bash
keytool -genkeypair -v -keystore ~/keys/cctg-customer.jks -alias cctg-customer \
  -keyalg RSA -keysize 2048 -validity 10000
```

Tạo `android/key.customer.properties` (đã `.gitignore`; tương tự `key.staff.properties`):

```properties
storeFile=/đường/dẫn/tuyệt/đối/cctg-customer.jks
storePassword=…
keyAlias=cctg-customer
keyPassword=…
```

**Sao lưu file `.jks` + mật khẩu ở nơi an toàn (két mật khẩu).** Mất khoá = không cập nhật được app đã phát hành. Nếu dùng Play App Signing thì khoá này là *upload key* (có thể đặt lại qua Play Console), nên bật Play App Signing.

### Build

```bash
flutter build appbundle --release --flavor customer -t lib/main_customer.dart \
  --dart-define-from-file=env/prod.json --build-name=1.0.0 --build-number=1
# → build/app/outputs/bundle/customerRelease/app-customer-release.aab  (tải lên Play Console)
flutter build apk --release --flavor customer -t lib/main_customer.dart --dart-define-from-file=env/prod.json
```

Không có `android/key.<flavor>.properties` thì build `release` **dừng với thông báo rõ** (cố ý, tránh phát hành nhầm bản ký bằng khoá debug). Thử `--release` trên máy dev: `ALLOW_DEBUG_SIGNING=1 flutter build apk --release …` (bản đó **không được phát hành**).

Số phiên bản: `--build-name` / `--build-number` (hoặc `version:` trong `pubspec.yaml`); `build-number` phải tăng mỗi lần tải lên Play.

## 4. iOS (chỉ chạy được trên macOS + Xcode)

Cấu hình flavor đã được tạo bằng `tool/setup_ios_flavors.rb`: cấu hình `Debug|Release|Profile-<flavor>`, scheme `staff` và `customer`, bundle id, tên, bộ icon `AppIcon-customer`. **Chưa được mở/build bằng Xcode** (môi trường soạn thảo là Linux) — lần đầu trên Mac cần kiểm tra:

1. `open ios/Runner.xcworkspace`, chọn scheme `customer` → tab *Signing & Capabilities* của target Runner: chọn Team, để Xcode tạo provisioning cho `vn.corecd.customer` (làm cho cả cấu hình `Release-customer`).
2. Tạo App ID + app trong App Store Connect cho `vn.corecd.customer`.
3. Build: `flutter build ipa --release --flavor customer -t lib/main_customer.dart --dart-define-from-file=env/prod.json --build-name=1.0.0 --build-number=1`, rồi tải lên bằng Transporter/Xcode Organizer.
4. Face ID: `NSFaceIDUsageDescription` đã có trong `Info.plist`; thử trên máy thật.

Yêu cầu tối thiểu Android 8.0 (API 26, do `sentry_flutter` 10); đã `assembleCustomerDebug/Release` và `assembleStaffDebug` thành công trong môi trường dựng (APK khách ký bằng khoá thử: `apksigner verify` đạt, `aapt` xác nhận id `vn.corecd.customer`, nhãn `CCTG`, quyền INTERNET/USE_BIOMETRIC).

## 5. Kiểm tra trước khi phát hành

- `tool/check.sh` (analyze + test) phải sạch.
- Bản web chạy với backend thật: `tool/verify/customer_web_e2e.mjs` (hướng dẫn ở đầu file) — đăng nhập sai/đúng, các tab, chi tiết CCTG, lịch, giao dịch, hotline.
- Với bản `staging`/`prod`: đăng nhập bằng khách thật/thử → đổi mật khẩu lần đầu → xem Trang chủ, CCTG, Lịch, Giao dịch → bật sinh trắc → khoá/mở lại → đăng xuất.
- Thử gọi hotline (`SUPPORT_PHONE`) trên máy có SIM; mở hợp đồng PDF; xoay/dark mode; bàn phím không che ô nhập.
- Cố ý gây một lỗi thử khi có `SENTRY_DSN` và xác nhận sự kiện lên Sentry **không** chứa thông tin khách.

## 6. Việc còn nợ (không nằm trong bản này)

Chống root/jailbreak, certificate pinning, chặn chụp màn hình ở màn tiền, khoá lại khi quay về từ nền (hiện chỉ khoá lúc mở app); icon/tên thương hiệu chính thức; thông báo/push cho khách; mua/tất toán từ app khách.
