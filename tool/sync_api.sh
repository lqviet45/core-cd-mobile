#!/usr/bin/env bash
# Đồng bộ hợp đồng API từ repo backend (Core-CD-Management) sang repo này.
# Dùng: tool/sync_api.sh [đường-dẫn-repo-backend]   (mặc định ../Core-CD-Management)
set -euo pipefail
BACKEND="${1:-../Core-CD-Management}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$BACKEND/openapi/openapi.v1.json" ] || { echo "Không thấy $BACKEND/openapi/openapi.v1.json – truyền đường dẫn repo backend." >&2; exit 1; }
cp "$BACKEND/openapi/openapi.v1.json" "$ROOT/openapi/openapi.v1.json"
cp "$BACKEND/docs/MOBILE.md" "$ROOT/docs/BACKEND_CONTRACT.md"
echo "Đã đồng bộ openapi/openapi.v1.json và docs/BACKEND_CONTRACT.md từ $BACKEND"
git -C "$ROOT" --no-pager diff --stat -- openapi docs/BACKEND_CONTRACT.md || true
echo "Nếu hợp đồng đổi: cập nhật DTO ở lib/features/*/data, chạy tool/bootstrap.sh và tool/capture_fixtures.mjs (làm mới fixture test)."
