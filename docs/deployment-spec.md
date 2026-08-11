# 배포·운영 스펙 (2026-08-05 초안 — ❓ = 하민 확인 필요)

> 출시(8/25) 전에 확정해야 하는 운영 구성 정리. 배포 담당 = 하민 (dev→main 머지·배포 실행).
> 지금까지 이 내용이 문서화된 곳이 없어 초안 작성 — **회의에서 ❓ 채우고 확정할 것.**

## 1. 운영 토폴로지 (현재 파악)

```
Play Store 앱 (Flutter Android)
   └─ https://halftrip-springboot.onrender.com/api   ← Spring Boot (Render, **심사 기간 유료 전환 확정 8/5**)
         ├─ MySQL      Render 위에서 운영(하민 확인 8/5) — 관리형이 아니라 컨테이너로 띄운 것으로 추정
         │             ❓❗ **Persistent Disk 붙어있는지 확인 1순위** — 디스크 없으면 재배포·재시작 시 DB 통째 소실
         │             ❓ 백업 여부(최소 주간 mysqldump) · 플랜/비용
         ├─ Redis      **Upstash** (노션 환경변수 페이지로 확인 8/5)
         ├─ 파일 저장  **Supabase Storage로 확정(8/5 규희)** — 인증샷·영수증·숙박확인서·서명·PDF (아래 3-1)
         ├─ FastAPI    **https://halftrip-fastapi.onrender.com** (Render) — ❓ 플랜만 확인
         └─ FCM        Firebase 프로젝트 `halftrip-f4335` 기존재 — 서비스 계정 JSON만 하민에게 수령하면 규희 구현 시작 가능
Flutter 웹: **https://halftrip.vercel.app** (Vercel) — 정책 페이지 호스팅 후보로 활용 가능
백엔드 배포: dev → main 머지(하민) → Render 자동 배포 ❓ (트리거 방식 확인)
※ 노션 "환경변수" 페이지(6/14)는 지도 항목이 카카오 기준으로 낡음 — 구글맵 전환 반영해 갱신 필요
```

## 2. 환경변수·시크릿 인벤토리 (콘솔에 넣을 것)

| 서비스 | 키 | 비고 |
| --- | --- | --- |
| Spring | SPRING_DATASOURCE_URL/USERNAME/PASSWORD | 운영 DB |
| Spring | SPRING_DATA_REDIS_* | 운영 Redis |
| Spring | FASTAPI_BASE_URL, APP_ALLOWED_ORIGINS, APP_STORAGE_ROOT | |
| Spring | APP_KAKAO_OAUTH_APP_ID, APP_GOOGLE_OAUTH_CLIENT_ID | 소셜 (규희 구현 후) |
| Spring | FCM 서비스 계정 JSON 경로 | 푸시 |
| FastAPI | OPEN_AI_KEY/MODEL, YOUTUBE_API_KEY, TOUR_API_SERVICE_KEY, KAKAO_REST_API_KEY | ⚠️ TourAPI 키는 공모전 제출 대상 — 운영 키 1개로 통일 |
| FastAPI | REDIS_URL, SPRING_API_BASE_URL, YOUTUBE_COURSE_STREAM_NAME | |
| 앱 빌드 | API_BASE_URL, FASTAPI_BASE_URL, MAP_PROVIDER=google, GOOGLE_MAP_API_KEY | --dart-define, 키는 커밋 금지 |
| 앱 빌드 | 카카오·네이버 SDK 키 | 소셜 (하민 계정 발급 대기) |

## 3. ⚠️ 출시 전 필수 해결 (인프라)

1. **업로드 파일 영속화 → Supabase Storage 확정 (8/5 규희)** — 현재 `./uploads` 로컬 디스크는 재배포 시 소실.
   - 방식: DB·서버는 Render 그대로, **사용자 업로드 파일만** Supabase 버킷으로. DB에는 지금처럼 경로(URL)만 저장
   - 작업: Spring `StorageService` 저장/조회를 Supabase Storage API로 교체 (반나절~1일) + 기존 운영 파일 1회 이관
   - 버킷은 비공개(private) + 서버 경유 서명 URL — 증빙 파일 공개 노출 금지
   - 프로젝트 생성·키 발급 = **하민, §5-1 가이드대로 (서울 리전 필수)** / StorageService 교체 담당은 회의 확정(정훈 소유 코드 — 정훈 or 규희)
2. **콜드스타트 대응** — Render 무료는 15분 유휴 시 슬립(첫 요청 ~30초+). 심사위원이 앱 열었다 타임아웃 나면 심사 제외 리스크.
   - 유지 기간: 출시 8/25 → 1차 심사 10월 중 → 최종 심사 10/28 = **약 2개월 상시 가동 필요**
   - 규정: 프리티어 "권장"(지원 없음)일 뿐 유료 금지 아님. Render Starter 서비스당 월 $7
   - **결정(8/5 규희): 심사 기간 Render 유료 전환 확정.** 전환 시점(9월 초 권장)·FastAPI 포함 여부만 회의에서 확정
3. **운영 DB 백업** — ❓ 현재 백업 여부. 최소 출시 전 1회 덤프 + 주간 자동 백업
4. **API 토큰 검증** — 보안 점검에서 나온 것 (정훈 진행 예정) — 공개 배포 전 필수

## 4. 앱 출시 체크리스트 

- [ ] 서명 키(keystore) 생성 — ⚠️ **분실하면 앱 업데이트 영구 불가. 팀 공유 금고(1Password류)에 백업 필수**
- [ ] `usesCleartextTraffic` 제거, 릴리즈 빌드 API_BASE_URL=운영 주소로
- [ ] appbundle 빌드 → Play Console 등록 → 비공개 트랙(8/18)
- [ ] 콘솔 필수 입력: 개인정보처리방침 URL·계정삭제 URL(웹 호스팅 필요), 데이터 보안 설문, 콘텐츠 등급
- [ ] 스토어 리스팅: [store-listing.md](store-listing.md) + store-assets 이미지
- [x] 정책 페이지 **별도 Vercel 프로젝트로 배포 완료** (8/12) — 앱 웹빌드와 분리한 정적 사이트 `halftrip-policy`(규희 Vercel). 원문 수정 시 `tool/gen_policy_html.py` 재실행 → 그 3장을 이 프로젝트에 재배포. Play Console 입력 URL:
  - 개인정보처리방침: `https://halftrip-policy.vercel.app/privacy.html`
  - 계정 삭제: `https://halftrip-policy.vercel.app/account-deletion.html`
  - 이용약관: `https://halftrip-policy.vercel.app/terms.html`

## 5. 🛠️ 하민 셋업 가이드

### 5-1. Supabase 프로젝트 생성 (파일 스토리지용)

1. supabase.com → New Project — **Region은 반드시 `Northeast Asia (Seoul)`** 선택
   - ⚠️ 서울 리전이어야 개인정보처리방침에 "국외 이전"이 아닌 "처리 위탁"으로 기재 가능 (법적 부담 큰 차이)
2. Storage → 버킷 생성: `evidence` — **Public 버킷 OFF (비공개 필수)**. 증빙 파일(인증샷·영수증)이 공개 URL로 노출되면 안 됨
3. 규희에게 전달할 것: **Project URL + service_role 키** (단톡 말고 개인 DM — service_role은 전체 접근 키)
4. 무료 플랜으로 충분 (Storage 1GB — 증빙 이미지 기준 수천 장)

### 5-2. Render 유료 전환 (심사 기간)

1. **9월 첫째 주에** Spring 서비스(halftrip-springboot) → **Starter 플랜($7/월)** 전환
2. FastAPI는 일단 무료 유지 + 필요 시 같이 전환 (인증샷·OCR 사용 빈도 보고 회의 결정)
3. **11월 초(최종 심사 10/28 이후)** 무료로 복귀 — 총 예상 비용 $14~28
4. 전환 전까지는 keep-alive 핑으로 버팀 (10분 간격 헬스체크 크론 — 누가 걸지 회의에서)

### 5-3. 키 발급 3종 

| 키 | 어디서 | 규희에게 전달할 것 |
| --- | --- | --- |
| 카카오 로그인 | developers.kakao.com 앱 생성 → 플랫폼에 Android 등록 (패키지명 `com.tourism.travelmvp.travel_support_mvp` + 키해시) | **네이티브 앱 키 + JavaScript 키** |
| 네이버 로그인 | developers.naver.com 앱 등록 (같은 패키지명) | **Client ID + Client Secret** |
| FCM | Firebase `halftrip-f4335` → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성 | **JSON 파일** (Render 환경변수에도 등록) |

- 키는 전부 커밋 금지 — 앱은 `android/local.properties`·`--dart-define`, 서버는 Render 환경변수로 주입 (사용법: flutter_app/dart_defines.example.txt)
- 카카오 웹(JS) 키에는 도메인 등록 필요: `halftrip.vercel.app` (웹 데모 소셜 로그인용)

## 6. 운영 절차 (확정 필요)

- 배포: dev → main 머지는 하민만, 배포 시점 팀 합의 (기존 규칙 유지)
- ❓ 롤백 절차 (Render 이전 배포로 롤백 방법 공유)
- ❓ 장애 시 연락 체계 / 로그 확인 방법 (Render 대시보드 권한 팀 공유 여부)
- ❓ DB 마이그레이션 배포 순서: Flyway는 서버 기동 시 자동 — 하위호환 원칙 재확인
