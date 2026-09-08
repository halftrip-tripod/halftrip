#!/bin/zsh
# 관리자 콘솔 웹 빌드 — 앱과 web/ 폴더를 공유하므로 빌드 뒤 파비콘·제목만 관리자용으로 바꾼다.
# 사용: tool/build_admin_web.sh [API_BASE_URL]   (기본 운영 서버)
set -e
cd "$(dirname "$0")/.."
API=${1:-https://halftrip-springboot.onrender.com/api}
flutter build web --target lib/main_admin.dart --release \
  --dart-define=API_BASE_URL="$API" --dart-define=USE_MOCK_API=false --dart-define=USE_MOCK_LOGIN=false \
  -o build/admin-web
cp web/favicon-admin.png build/admin-web/favicon.png
cp web/icons/Icon-admin-192.png build/admin-web/icons/Icon-192.png
cp web/icons/Icon-admin-512.png build/admin-web/icons/Icon-512.png
cp web/icons/Icon-admin-192.png build/admin-web/icons/Icon-maskable-192.png
cp web/icons/Icon-admin-512.png build/admin-web/icons/Icon-maskable-512.png
sed -i '' -e 's|<title>하프트립</title>|<title>하프트립 관리자</title>|' \
          -e 's|content="하프트립"|content="하프트립 관리자"|' build/admin-web/index.html
sed -i '' -e 's|"name": "[^"]*"|"name": "하프트립 관리자"|' -e 's|"short_name": "[^"]*"|"short_name": "하프트립 관리자"|' build/admin-web/manifest.json
echo "✓ build/admin-web ($API)"
