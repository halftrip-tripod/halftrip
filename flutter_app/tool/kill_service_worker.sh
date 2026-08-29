#!/bin/bash
# 웹 빌드 후처리 — 서비스워커 캐시 무력화.
#
# Flutter 3.41은 --pwa-strategy=none 을 줘도 flutter_bootstrap.js 가 서비스워커를
# 등록한다. 그 결과 옛 번들이 브라우저 캐시에 붙잡혀, 새로 빌드해도 예전 화면이
# 계속 보인다(로컬 QA에서 "빌드했는데 왜 그대로?" 의 범인).
#
# flutter_service_worker.js 를 "스스로 등록 해제하고 캐시를 비우는" 스크립트로
# 바꿔치기해, 이미 SW 가 깔린 브라우저도 다음 방문에 자동으로 최신 번들을 받게 한다.
set -e
for dir in "$@"; do
  [ -d "$dir" ] || continue
  cat > "$dir/flutter_service_worker.js" <<'SW'
// 캐시 킬 스위치 — 예전에 등록된 서비스워커를 스스로 해제하고 캐시를 비운다.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      await caches.delete(key);
    }
    await self.registration.unregister();
    for (const client of await self.clients.matchAll({ type: 'window' })) {
      client.navigate(client.url);
    }
  })());
});
self.addEventListener('fetch', () => {}); // 네트워크 그대로 통과
SW
  echo "SW killed: $dir"
done
