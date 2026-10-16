#!/usr/bin/env bash
# Chuẩn bị máy dev sau khi clone: tải thư viện và sinh mã json_serializable (*.g.dart).
# Cần Flutter stable (Dart >= 3.13). Chạy lại bất cứ lúc nào sau khi đổi DTO.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "Chưa cài Flutter SDK (stable)." >&2; exit 1; }
flutter pub get
dart run build_runner build --delete-conflicting-outputs
echo
echo "Xong. Chạy thử (backend ở máy host, emulator Android dùng 10.0.2.2):"
echo "  cp env/dev.example.json env/dev.json   # sửa API_BASE_URL nếu cần"
echo "  flutter run --flavor staff -t lib/main.dart --dart-define-from-file=env/dev.json"
echo "  flutter run --flavor customer -t lib/main_customer.dart --dart-define-from-file=env/dev.json"
