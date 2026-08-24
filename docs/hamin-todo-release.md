# 하민 할 일 — 출시 준비 (2026-08-11 규희 정리)

> 출시(공모전 제출 9/21 16:00)까지 하민이 처리할 것 모음. **키·계정·배포**가 하민 몫, 구현은 규희가 끝냄(키만 넣으면 되게).
> ⏰ **가장 급한 건 ①개발자 계정 — 이게 밀리면 비공개 테스트 14일 시계를 못 돌려 전체가 밀림.**

---

## 🚨 목요 회의까지 (최우선)

### 1. Google Play 개발자 계정 생성 ← #1 크리티컬
- **개인(Personal) 계정으로 생성** — 조직 계정은 D-U-N-S 번호에 30일+ 걸려 9/21 못 맞춤
- play.google.com/console → 계정 생성 → **$25 결제** → **정부 신분증 본인 인증 즉시 제출** (인증에 며칠 걸릴 수 있어 계정 만들자마자 걸 것)
- ⚠️ 개인 계정이라 **비공개 테스트 12명 × 14일** 필수 → 8/18쯤 테스트 시작해야 여유

### 2. 비공개 테스트 테스터 모집 (12명)
- **최소 12명, 여유 있게 13~15명** (중간 이탈 대비)
- 받을 것: 각자 **Google 계정 이메일(Gmail)** — 나중 Play Console 테스터 목록에 등록
- 각 테스터는 **폰에 실제 설치(opt-in)** 해야 카운트 (초대만 받고 안 깔면 0명 취급)
- 트리포드 4명 + 지인 8~11명이면 충분

---

## 🔑 키 발급 3종 

### 3. 카카오 로그인
- developers.kakao.com → 애플리케이션 추가 → **플랫폼 > Android 등록**
  - 패키지명: `com.tourism.travelmvp.travel_support_mvp`
  - **키 해시(SHA-1) 3개 등록** — 빌드 방식마다 서명 키가 달라서 다 등록해야 그 앱에서 로그인됨 (카카오는 여러 개 허용):
    - ① 디버그: `C6:56:7F:44:A3:83:6E:91:98:20:FE:23:A0:74:EC:8A:48:12:3B:10` ← `flutter run`/디버그 설치 테스트용
    - ② 릴리즈(업로드): `82:B8:DF:7B:9D:47:0A:03:66:DF:F8:08:57:78:10:A9:86:D1:1C:11` ← `flutter build apk --release` 테스트용 (규희 keystore)
    - ③ Play 앱 서명: **스토어 업로드 후 추가** — Play가 자체 키로 최종 서명하므로 실배포 앱 지문이 또 다름. Play Console → 앱 무결성/앱 서명 페이지의 SHA-1을 카카오에 하나 더 등록. (안 하면 스토어 배포 앱에서 카카오 로그인 실패)
    - (참고: 카카오 콘솔은 SHA-1을 Base64 키해시로 변환해 등록 — 콘솔 안내대로)
- **규희에게 전달**: 네이티브 앱 키 + JavaScript 키
- 도메인 등록 불필요(앱). 웹 데모용으로만 `halftrip.vercel.app` 등록(선택)

### 4. 네이버 로그인
- developers.naver.com → 애플리케이션 등록 (같은 패키지명 `com.tourism.travelmvp.travel_support_mvp`, 앱 이름 "하프트립")
- **규희에게 전달**: Client ID + Client Secret
- 도메인 불필요(앱)


### 5. Supabase Storage (증빙 파일 저장)
- supabase.com → New Project — **Region 반드시 `Northeast Asia (Seoul)`** (서울리전이어야 방침상 "국외이전" 아님)
- Storage → 버킷 `evidence` 생성, **Public OFF(비공개 필수)**
- **규희에게 전달**: Project URL + **service_role 키**
- 무료 플랜으로 충분 (심사 기간)

---

## 🌐 배포 (출시 전 필요)

### 7. Vercel 정책 페이지 라이브 확인
- `halftrip.vercel.app/privacy.html`·`/account-deletion.html`이 **실제로 열리는지 확인** (Play Console 필수 입력 URL)
- 안 열리면 최신 웹 빌드로 Vercel 재배포 (정책 HTML은 `flutter build web`에 자동 포함됨)

### 8. Render 운영 서버 확인
- Spring/FastAPI 살아있는지 + **콜드스타트 대응** (심사위원 타임아웃 방지 — 9월 초 Starter 유료 전환 or keep-alive 핑)
- DB 백업 여부 확인(❓) — 최소 출시 전 1회 덤프


---

## 📌 참고 값 (복붙용)
- 패키지명(applicationId): `com.tourism.travelmvp.travel_support_mvp`
- 릴리즈 서명 SHA-1: `82:B8:DF:7B:9D:47:0A:03:66:DF:F8:08:57:78:10:A9:86:D1:1C:11`
- Firebase 프로젝트: `halftrip-f4335`
- 웹/정책: `https://halftrip.vercel.app`
- 앱 API: `https://halftrip-springboot.onrender.com/api` / FastAPI: `https://halftrip-fastapi.onrender.com`

## 우선순위 한눈에
1. **개발자 계정(개인) 생성 + 신분증 인증** ← 목요, 제일 급함
2. **테스터 12명 모집** ← 목요
3. Vercel 정책 URL 라이브 확인
4. 키 2종(카카오·네이버) + Supabase — 계정 생기면 발급 (출시 후 업데이트 OK) · FCM은 규희 몫(이미 수령)
5. Render 콜드스타트·백업 / 백엔드 QA는 그 다음
