#!/usr/bin/env bash
# CHƯA CHẠY THỬ (viết khi chưa có Flutter SDK trong môi trường). Chạy MỘT LẦN trên máy đã cài Flutter để dựng dự án.
# Dùng: tool/bootstrap.sh <org-ngược-miền>        vd: tool/bootstrap.sh vn.com.tencongty
#   <org> quyết định applicationId/bundle id (vd vn.com.tencongty.core_cd_mobile) – khó đổi sau khi lên store, chọn cẩn thận.
set -euo pipefail
ORG="${1:?Thiếu <org-ngược-miền>, vd: vn.com.tencongty}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v flutter >/dev/null || { echo "Chưa cài Flutter SDK (stable)." >&2; exit 1; }
flutter --version

# Dựng khung Flutter tại chỗ (không ghi đè README/docs/tool đã có)
flutter create --org "$ORG" --project-name core_cd_mobile --platforms android,ios .

# Thư viện chạy (flutter pub add tự chọn phiên bản tương thích mới nhất; chốt phiên bản vào pubspec.lock và commit)
flutter pub add \
  flutter_riverpod riverpod_annotation \
  go_router dio \
  freezed_annotation json_annotation \
  decimal intl \
  flutter_secure_storage local_auth \
  drift sqlite3_flutter_libs path_provider path \
  firebase_core firebase_messaging flutter_local_notifications \
  pdfx share_plus image_picker flutter_image_compress \
  connectivity_plus fl_chart skeletonizer lucide_icons_flutter \
  sentry_flutter logger
# Package đi kèm SDK
flutter pub add 'flutter_localizations:{"sdk":"flutter"}'

# Thư viện phát triển
flutter pub add --dev \
  build_runner riverpod_generator freezed json_serializable drift_dev \
  custom_lint riverpod_lint very_good_analysis \
  mocktail alchemist
flutter pub add 'dev:integration_test:{"sdk":"flutter"}'

cat > analysis_options.yaml <<'YAML'
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
  exclude:
    - lib/generated/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"
linter:
  rules:
    public_member_api_docs: false
YAML

echo
echo "Xong. Việc tiếp theo:"
echo "  1) tool/gen_api.sh                       # sinh client từ OpenAPI"
echo "  2) Tạo dự án Firebase, thêm google-services.json / GoogleService-Info.plist (KHÔNG commit)"
echo "  3) flutter run --dart-define-from-file=env/dev.json   (sao chép từ env/dev.example.json)"
