#!/usr/bin/env bash
# CHƯA CHẠY THỬ (viết khi chưa có Flutter/Java trong môi trường) – chỉnh lại khi dựng M0 nếu cần.
# Sinh client Dart (dart-dio + json_serializable) từ openapi/openapi.v1.json vào lib/generated/.
# Cần: Node (npx), Java 11+ (openapi-generator-cli chạy trên JVM), đã chạy `flutter pub get`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf lib/generated
npx --yes @openapitools/openapi-generator-cli generate \
  -i openapi/openapi.v1.json \
  -g dart-dio \
  -o lib/generated \
  --additional-properties=pubName=core_cd_api,serializationLibrary=json_serializable
# Sinh code cho json_serializable/freezed trong package được sinh
(cd lib/generated && dart pub get && dart run build_runner build --delete-conflicting-outputs)
echo "Đã sinh client vào lib/generated/ (không commit – xem .gitignore)."
