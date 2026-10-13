#!/usr/bin/env bash
# Kiểm tra cục bộ trước khi đẩy mã (dự án không dùng CI): định dạng, phân tích tĩnh, test.
set -euo pipefail
cd "$(dirname "$0")/.."
dart format --output=none --set-exit-if-changed lib test
flutter analyze
dart run custom_lint
flutter test
echo "OK"
