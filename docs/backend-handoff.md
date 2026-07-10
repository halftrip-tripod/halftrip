# 🛠 하프트립 백엔드 작업 정리 (새 디자인 기준)

> 새로 만든 화면 디자인(halftrip-design)에 맞춰 백엔드를 수정·추가하는 작업 목록.
> **실제 백엔드(`halftrip-springboot`, 20테이블·18엔티티·Flyway V37)를 직접 대조**해서 정리함.
> 디자인 화면: https://illilili.github.io/halftrip-design/ · 표기: 🔧 수정(있는데 다름) · ➕ 추가(없음)

---

## 0. 설계 전 확인할 내용

1. **환급 완료는 추적하지 않는다.** 정산 신청·환급은 정부 외부 사이트에서 일어나 앱·서버 모두 자동으로 알 수 없음. 앱이 아는 마지막 상태 = **"정산 신청 완료"**(사용자가 직접 "신청 완료" 누름). 환급 완료/받은 금액 화면·필드 안 만듦.
2. **여행 단계는 백엔드가 KST 기준 계산해서 내려준다.** 프론트가 기기 시간으로 계산하면 타임존·시계 오차 → 백엔드가 `tripStatus` 계산.
3. **타임존 = KST(Asia/Seoul) 고정.** 여행 일정은 date-only, datetime은 KST offset(`+09:00`).
4. **개인정보 최소수집.** 계정 상시 보유 = **거주지(필수) + 커뮤니티 닉네임 + 로그인 식별자**뿐. **실명·전화번호는 정산 신청 시점에만 수집**해 그 정산 레코드에만 저장(평소 미보유), **email은 수집 안 함**. 화면 표시·인사말은 닉네임 사용(실명 노출 X).

---

## 1. 현재 백엔드 (이미 되어 있는 것 — 그대로 유지)

핵심 사용자 흐름은 대부분 구현돼 있음:
- **인증** `/api/auth/*`(로컬·소셜 mock), **지역** `/api/regions*`, **여행** `/api/trips*`(CRUD·코스·파일)
- **킬러기능 전부** — 인증샷 분석·영수증 OCR·숙박확인서(템플릿·PDF)·증빙 PDF 병합·정산 요약/신청 (FastAPI 연동)
- **유튜브 코스잡**(Redis Stream 비동기), **가맹점 지도**(Kakao), **찜**, **FCM 발송**, **알림설정**

→ **아래 2번 목록 외의 기존 엔드포인트·테이블은 그대로 둠.** 단, 응답 필드 모양은 **3번(응답 형식 주의)**과 맞는지 확인.

---

## 2. 해야 할 일

> **2026-07-10 재대조(필드 단위 화면 대조)**: A·B ✅정합 확인, K marketing_alert ✅, NAVER ✅. **E·F·G는 구현됐지만 화면 계약과 어긋남(⚠️ 각 항목 참고)**. 남은 것 = C·D·H·I·J·K잔여 + E/F/G 보강.

### ✅ A. 여행 상태(TripStatus) 재정의 — 완료 (V39)
- **어느 화면**: 내 여행 목록·상세 (여행 전/여행 중/정산 신청 칩 + 지난여행)
- **지금**: `trips.status` = `TRAVELING` / `SETTLEMENT_READY` / `SETTLEMENT_COMPLETED`
- **문제**: 디자인은 여행전·중을 구분하고, `SETTLEMENT_COMPLETED`(정산 완료)는 외부라 앱이 모름(제약 1).
- **할 것**: enum 재정의 → `BEFORE`·`ONGOING`·`ENDED`·`SETTLEMENT_REQUESTED`
  - 여행전/중/종료 = **백엔드가 KST 오늘 vs start/end 로 계산** (settlement_applied=true면 `SETTLEMENT_REQUESTED`)
  - `SETTLEMENT_COMPLETED`/`READY` 제거. 환급 완료 단계 없음.

### ✅ B. User 개인정보 (실명·전화번호·email 최소화) — 완료 (V40)
- **지금**: `users`에 `name`(NOT NULL)·`email`(**NOT NULL UNIQUE**)·`phone_number` 보유. mock-login이 email 받고, 가입 시 실명·전화번호 수집. 여행 생성 시 `trips.applicant_name`·`phone_number`로 따라감.
- **할 것**:
  - `email` → **nullable 또는 제거**(마이그레이션). 소셜 로그인이 email 강제 안 하게.
  - **실명·전화번호** → 계정에서 빼고(또는 nullable) **`POST /trips/{id}/settlement-apply` 요청에서 수집**(`{ "applicantName": "...", "phoneNumber": "..." }`) → 정산/여행 레코드에만 저장. (실명은 정산 본인확인용 외엔 안 쓰임 — 화면 표시는 닉네임)
  - 가입 수집 항목 = 로그인 식별자 + **거주지** + (커뮤니티) 닉네임.
  - 소셜이 주는 이름은 저장하지 말 것(필요 시 정산 때 직접 입력/확인).

### 🔧 C. Region 상세 — 날짜·조건 필드 추가
- **어느 화면**: 홈 지역카드("마감 D-2"·"6/16 오픈 D-3"·조건 문구), 지역 상세(접수기간·여행기간·정산기한·환급율·결제수단)
- **지금**: `regions`에 환급 **금액**·상태·지도좌표·디민증여부만. **날짜·문구·환급율 전무.**
- **할 것**: `regions` 컬럼 추가
  - `apply_deadline`(date) — 마감 D-day, `open_date`(date) — 오픈예정 D-day
  - `refund_condition_text`(string) — "관광지 2곳 인증 · 제로페이 결제"
  - (지역상세) `apply_start_date`·`travel_period_start`·`travel_period_end`·`settlement_deadline_days`·`refund_rate`·`max_refund_per_person`·`payment_methods`
  - `local_currency_app_url`(온라인몰 탭 지역화폐 앱 링크) — 온라인몰 URL은 기존 `online_malls`로 충족
- **응답 예** (`GET /api/regions`):
```jsonc
{ "name":"평창","province":"강원특별자치도","statusCode":"APPLYING","refundConditionAmount":200000, // 기존
  "applyDeadline":"2026-06-20","openDate":null,"refundConditionText":"관광지 2곳 인증 · 제로페이 결제" } // 추가
```

### 🔧 D. Place(관광지) 상세 필드 추가
- **어느 화면**: 장소 상세(place-detail) — 운영시간·이용료·연락처·결제수단·디민증 할인율
- **지금**: `places` = name·address·description·lat·lng·eligible 뿐.
- **할 것**: `opening_hours`·`admission_fee`·`phone`·`payment_methods`(+디민증 할인 정보) 추가. TourAPI 매칭으로 채워도 됨.

### ⚠️ E. 여행 진행 카운트 — 필드는 생겼는데 **의미가 화면과 다름**
- `authCertifiedCount` = **승인된 사진 수**로 집계 중(`countByTripIdAndApprovedTrue`). 화면은 "관광지 **N곳** 인증"(서로 다른 지정관광지 개소 수) — 같은 곳 2장 올리면 2/2로 오판. 리뷰에 place 참조가 없어 개소 집계 불가(→ F 배선과 같은 뿌리).
- `checklistDoneCount` — **사용자 직접 체크 방식으로 확정 (2026-07-10 규희)**. 현재 서버 자동판정 4항목(코스선택·인증샷·영수증·숙박서명)은 화면 의도(여행 전 출발 준비 체크)와 다름 → 자동판정 로직 대신 체크 상태 저장으로 교체:
  - `GET /trips/{tripId}/checklist` → `[{ "key":"currency_app","label":"지역화폐 앱 설치","checked":true }, ...]` (항목 정의는 서버 시드, 없으면 기본 목록 생성)
  - `PUT /trips/{tripId}/checklist` — req `{ "items": [{ "key":"currency_app","checked":true }, ...] }` (전체 교체)
  - 기본 4항목(현재 화면 확정 문구): `currency_app` 지역화폐 앱 설치 · `payment_method` 결제수단(인정 카드) 확인 · `auth_guide` 인증사진 가이드 확인 · `lodging` 숙소 예약 확인
  - `checklistDoneCount`/`checklistTotal`은 이 저장 값으로 집계. (현재 클라 로컬 저장 → API 생기면 교체, 기기 변경에도 유지됨)
- `authRequiredCount`·`settlementDeadline` = null (C의 Region 정책 필드 의존) — C 전까지 "1/2곳"·"정산 D-5" 게이지 서버 데이터로 못 그림.
- **어느 화면**: 내 여행 카드 게이지 — "관광지 인증 1/2곳", "출발 체크리스트 2/4", "정산 마감 D-5"
- **지금**: trips 응답에 없음(파일·영수증은 있지만 카운트 필드 X).
- **할 것**: `TripSummary`/`TripDetail` 응답에 추가:
  - `authCertifiedCount`/`authRequiredCount` (지정관광지 수 기준 인증 진행)
  - `checklistDoneCount`/`checklistTotal` (출발 준비 체크리스트 — 항목 정의 필요)
  - `settlementDeadline`(date)

### ⚠️ F. 인증샷 GPS EXIF 검증 — FastAPI는 완성, **Spring이 관광지 좌표를 안 넘겨서 위치검증 무동작**
- FastAPI `photos/auth-review`는 `target_lat/lng/radius_m` 받아 반경 검증하게 완성됨. 그런데 Spring `analyzeAuthPhoto()`가 **파일·인원·여행기간만 넘김** → `locationVerified` 항상 null = 위치 검증이 실제로는 안 돎.
- 근본 원인: **어느 지정관광지를 인증하는 사진인지가 계약에 없음.** `POST /trips/{tripId}/auth-photos/analyze/{uploadedFileId}`에 placeId 파라미터 X, `auth_photo_reviews` 테이블에도 place 참조 X.
- **할 것**: ① analyze 요청에 `placeId` 추가 ② Spring이 그 place 좌표+반경을 FastAPI에 전달 ③ 리뷰에 `place_id` 저장 → E의 authCertifiedCount를 distinct place 기준으로 재집계. (촬영시각 검증은 정상 배선 ✓)
- **어느 화면**: 관광지 인증(auth-photo) — "위치(GPS 지정관광지 반경)·촬영시각(여행기간 내)" 자동 판정
- **지금**: FastAPI `photos/auth-review`가 **인원·얼굴·배경만** 판정. 위치·시간 빠짐.
- **할 것**: 사진 **EXIF에서 GPS·촬영시각 추출·검증** 추가. 응답에 `locationVerified`·`withinTripPeriod`·`capturedAt` 추가.
  - (캡처·SNS 저장본은 EXIF 없어 `locationVerified=false` → 인증 불가 안내)

### ⚠️ G. 알림 목록 (저장 + 조회) — 저장·조회 완료(V41), 구멍 3개
- **refType/refId 누락**: `notifications` 테이블·엔티티에 없음 → 알림 탭해도 이동할 곳을 못 정함. 아래 ⭐딥링크 항목대로 추가 필요.
- **userId 시그니처**: `GET /api/notifications?userId=` 필수 쿼리 — 클라는 현재 쿼리 없이 호출(→400). 인증 컨텍스트 없으니 이 형태 유지하되 확정 공유 필요(클라도 userId 붙이게 수정 예정 — 규희).
- (minor) `createdAt`이 offset 없는 LocalDateTime으로 직렬화 — 계약은 KST `+09:00` 포함(3번 섹션).
- **어느 화면**: 알림 센터(notifications) — 오늘/지난 그룹, 유형 아이콘, 읽음, 모두 읽음
- **지금**: FCM **발송만**(유튜브 완료 1종). 저장 테이블·조회 API 없음.
- **할 것**:
  - 테이블 `notifications`(id, user_id, type, title, body, read, created_at, **ref_type, ref_id**) — FCM 발송 시 같이 저장
  - `GET /api/notifications` · `POST /api/notifications/read-all`
  - type enum: `REGION_OPEN`·`COURSE_DONE`·`COMMUNITY_LIKE`·`COMMUNITY_COMMENT`·`SETTLE_DEADLINE`·`BENEFIT`
  - **⭐딥링크용 타겟 참조 필수**: 알림 탭 → 관련 화면 이동에 필요. `refType`(`REGION`·`COURSE`·`POST`·`TRIP`·`MERCHANT`) + `refId`(대상 PK). 예) REGION_OPEN→`REGION`+regionId, COURSE_DONE→`COURSE`+courseId, COMMUNITY_LIKE/COMMENT→`POST`+postId, SETTLE_DEADLINE→`TRIP`+tripId. 없으면 프론트가 어디로 보낼지 못 정함. (클라 모델엔 이미 `refType`·`refId` optional로 준비돼 있음)
```jsonc
// GET /api/notifications → [{ "type":"REGION_OPEN","title":"강진 접수 시작 🎉","body":"...","createdAt":"2026-06-18T09:50:00+09:00","read":false, "refType":"REGION","refId":12 }]
```

### ➕ H. AI 코스 생성 (유튜브 말고)
- **어느 화면**: 코스 만들기 → AI 코스 생성(course-ai·course-sim)
- **지금**: 유튜브 링크 기반(`youtube-course-jobs`)만 있음. 순수 AI 생성 없음.
- **할 것**: `POST /api/courses/generate` — 지역·일수·인원·테마 우선순위 → 지정관광지 경유+동선 코스. (유튜브처럼 비동기 가능)
```jsonc
// 요청 { "regionId":12,"days":2,"travelerCount":2,"themePriority":["자연","맛집","문화","체험"] }
// 응답 { "title":"","refundConditionMet":true,"days":[{"day":1,"stops":[{"placeId":,"name":"","category":"","refundEligible":true}]}] }
```

### ➕ I. 저장 코스함 (서버 저장)
- **어느 화면**: 저장 코스함(course-saved)·홈 저장코스·내여행 보관함
- **지금**: 저장 코스 테이블 없음(클라 로컬만 → 기기 바꾸면 사라짐).
- **할 것**: `saved_courses`·`saved_course_stops` 테이블 + CRUD API.

### ➕ J. 커뮤니티 전체 — ⭐제일 큼 (Phase 3)
- **어느 화면**: community·community-detail·community-write·saved-posts·my-reviews + 홈 인기코스·지역상세 후기·지난여행 후기
- **지금**: 테이블·엔티티·API **0개. 완전 없음.**
- **할 것** (DB):
  - `community_posts`(id, user_id, type[REVIEW/COURSE/QUESTION/INFO], region_id, body, photos_json, attached_course_id, trip_id(인증배지 근거), visibility[PUBLIC/PRIVATE], like_count, comment_count, created_at)
  - `community_comments`(id, post_id, user_id, parent_id, mention_user_id, body, created_at)
  - `community_likes`(post_id, user_id) · `community_bookmarks`(post_id, user_id)
  - `community_profiles`(user_id, nickname, avatar_preset) — 닉네임 반익명·아바타 프리셋(계정 실명과 분리)
- **할 것** (API): 피드(정렬·필터 인기/최신/후기/코스/질문/정보)·상세·작성·댓글(대댓글·멘션)·좋아요·북마크·내가쓴글/저장글·영수증 카드 게시
- **인증 배지**: 글에 `trip_id`(다녀온 여행)·코스 첨부 시 ✓배지. 좋아요·댓글은 알림(G)+FCM 연계.

### ➕ K. 마이페이지 자잘한 것
- ~~`user_notification_settings`에 **`marketing_alert`(BIT) 컬럼 추가**~~ ✅ 완료 (V38)
- 작성/저장 글 수 = 커뮤니티(J)에서 `myPostCount`·`savedPostCount` 집계
- (여행 취향은 온보딩 제거 결정 → 마이페이지에서도 빼거나 "최근 코스 취향")
- **거주지 수정 API 없음** — 마이페이지 거주지 변경이 지금 클라 로컬 갱신뿐(재로그인하면 원복). 거주지는 지역 노출 필터 기준이라 서버 저장 필수.
  - `PATCH /api/users/{userId}/residence` — req `{ "residence": "서울특별시 강남구" }` → res `ApiResponse<UserProfileResponse>` (변경된 유저 전체)
- **프로필(닉네임·아바타) 수정 API 없음** — 프로필 편집 화면도 로컬 갱신뿐.
  - `PUT /api/users/{userId}/profile` — req `{ "nickname": "여행하는민트42", "avatarPreset": "2:1" }` → res `ApiResponse<UserProfileResponse>`
  - 저장소는 커뮤니티(J)의 `community_profiles`(user_id, nickname, avatar_preset) 그대로 써도 됨 — J보다 먼저 이 테이블+API만 선행 가능.
  - `avatarPreset` 와이어 포맷 = 클라 기존 규약 `"이모지인덱스:배경인덱스"` 문자열 (예 `"2:1"`, 기본 `"0:0"`).
- **회원 탈퇴**: `DELETE /api/users/{userId}` — soft delete(개인정보 파기 + 정산 증빙은 법정 보존기간 유지). 정책 확정 후 진행.
- 클라 훅 위치(참고): `app_controller.updateResidence()`·`updateProfile()`이 현재 로컬 갱신만 — API 생기면 repository 호출 한 줄씩 추가하면 끝나는 구조.

---

## 3. 응답 형식 주의 (틀리기 쉬운 것)
전체 필드 계약은 클라가 백엔드 보고 만들어져 **기존 응답 모양은 대체로 일치**. 아래만 어긋나면 파싱이 깨지니 주의(더 필요하면 규희에게):

- **공통 래퍼**: `{ "success": true, "data": <본문>, "message": "" }`
- **날짜/타임존**: 일정 = date-only `"2026-06-20"`, datetime = KST offset `"2026-06-20T09:00:00+09:00"`. (클라가 `DateTime.parse`)
- **enum 와이어 값**(정확한 철자·대문자):
  - `statusCode`(지역): `APPLYING`·`PREPARING`·`CLOSED`
  - `tripStatus`(여행): `BEFORE`·`ONGOING`·`ENDED`·`SETTLEMENT_REQUESTED` ← A항 재정의
  - `paymentType`: `CREDIT_CARD`·`CHECK_CARD`·`ONLINE_PAYMENT`·`BANK_TRANSFER`·`CASH_RECEIPT`·`SIMPLE_RECEIPT`·`UNKNOWN`
  - `usageScope`: `GENERAL`·`LODGING` / `reviewStatus`: `PENDING`·`APPROVED`·`REJECTED`
  - `fileCategory`: `AUTH_PHOTO`·`RECEIPT_IMAGE`·`LODGING_CONFIRMATION`·`SIGNATURE`·`GENERATED_PDF`
  - `placeType`: `HALF_PRICE`·`DIGITAL_TOUR_CARD`·`MERCHANT`
  - 알림 `type`: `REGION_OPEN`·`COURSE_DONE`·`COMMUNITY_LIKE`·`COMMUNITY_COMMENT`·`SETTLE_DEADLINE`·`BENEFIT`
  - 커뮤니티 글 `type`: `REVIEW`·`COURSE`·`QUESTION`·`INFO`
- ~~⚠️ **소셜 provider에 `NAVER` 추가 필요**~~ ✅ 완료 — `AuthProvider`에 NAVER 추가됨.
- **게스트 모드: 지금 없음(로그인 필수로 디자인).** `AuthProvider.GUEST` 당장 안 씀 — 게스트 흐름 새로 만들 필요 없음. (나중에 홈·지역·커뮤니티 읽기 전용 둘러보기 + 액션 시 로그인 유도로 검토)
