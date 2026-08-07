# TC-CONTRACT — 레포 간 계약

> 화면이 멀쩡해 보여도 여기가 어긋나면 **다른 레포에서 조용히 깨진다.** 배포 전 반드시 돈다.
> 근거 문서: [백엔드 작업 정리 §3 응답 형식](../backend-handoff.md) · CLAUDE.md 인터페이스 규칙

| ID | 케이스 | 자동 |
| --- | --- | --- |
| TC-CONTRACT-001 | 공통 응답 래퍼 | ✅ |
| TC-CONTRACT-002 | datetime KST offset | ✅ |
| TC-CONTRACT-003 | enum 와이어값 | — |
| TC-CONTRACT-004 | 포트 정합성 (Spring ↔ FastAPI ↔ Flutter) | — |
| TC-CONTRACT-005 | 로컬 시드가 스키마와 맞는지 | — |
| TC-CONTRACT-006 | FastAPI 콜백 경로 존재 | ✅ |
| TC-CONTRACT-007 | Spring → FastAPI 호출 경로 존재 | — |
| TC-CONTRACT-008 | 환경변수 예시 파일이 실제 설정과 일치 | — |

---

### TC-CONTRACT-001 공통 응답 래퍼
- **절차**: 아무 API나 성공·실패로 각각 호출
- **기대**: 항상 `{"success":boolean,"data":...,"message":...}`. 클라는 `data` 만 파싱하므로 **래퍼가 빠지면 전 화면이 깨진다**
- **주의**: 파일 다운로드(`/binary`, `/pdf`)는 래퍼 없이 바이너리가 정상

### TC-CONTRACT-002 datetime KST offset
- **절차**: `createdAt` 이 들어가는 응답을 모아 본다 — 알림(`GET /api/notifications`), 커뮤니티 글(`GET /api/community/posts`), 여행 상세
- **기대**: `"2026-08-08T00:38:16+09:00"` 처럼 **offset 포함**. 일정(date-only)은 `"2026-09-01"`
- **실패 예**: `"2026-08-08T00:38:16.570546"` — offset이 없으면 Flutter `DateTime.parse` 가 **기기 로컬 시간으로 해석**해 "몇 분 전" 표시와 정렬이 어긋난다

### TC-CONTRACT-003 enum 와이어값
- **절차**: 각 응답의 enum 문자열을 아래와 대조
- **기대**
  - `statusCode`(지역): `APPLYING`·`PREPARING`·`CLOSED`
  - `tripStatus`: `BEFORE`·`ONGOING`·`ENDED`·`SETTLEMENT_REQUESTED`
  - `paymentType`: `CREDIT_CARD`·`CHECK_CARD`·`ONLINE_PAYMENT`·`BANK_TRANSFER`·`CASH_RECEIPT`·`SIMPLE_RECEIPT`·`UNKNOWN`
  - `usageScope`: `GENERAL`·`LODGING` / `reviewStatus`: `PENDING`·`APPROVED`·`REJECTED`
  - `fileCategory`: `AUTH_PHOTO`·`RECEIPT_IMAGE`·`LODGING_CONFIRMATION`·`SIGNATURE`·`GENERATED_PDF`
  - 알림 `type`: `REGION_OPEN`·`COURSE_DONE`·`COMMUNITY_LIKE`·`COMMUNITY_COMMENT`·`SETTLE_DEADLINE`·`BENEFIT`
  - 커뮤니티 글 `type`: `REVIEW`·`COURSE`·`QUESTION`·`INFO`
  - 소셜 provider: `KAKAO`·`NAVER`·`GOOGLE`·`LOCAL`·`GUEST`
- **철자·대문자가 하나라도 다르면 클라 파싱 예외.** enum 값을 바꾸는 PR은 양쪽 레포 동시 반영이 원칙

### TC-CONTRACT-004 포트 정합성 🔴
- **절차**: 아래 4곳이 같은 포트를 가리키는지 확인
  | 위치 | 값 |
  | --- | --- |
  | `halftrip-springboot/application.yml` | `server.port: ${PORT:10000}` |
  | `halftrip-fastapi/app/core/config.py` | `spring_api_base_url` 기본값 |
  | `halftrip-fastapi/.env.example` | `SPRING_API_BASE_URL` |
  | `docs/qa-handoff.md`, Flutter 실행 예시 | `API_BASE_URL` |
- **기대**: 전부 일치. 어긋나면 **FastAPI가 유튜브 분석 결과를 Spring에 콜백하지 못해 잡이 영원히 PENDING** 으로 남는다
- **검증법**: FastAPI를 띄운 상태에서 유튜브 잡을 만들고, Spring 로그에 콜백(`/processing`·`/complete`)이 찍히는지 본다

### TC-CONTRACT-005 로컬 시드가 스키마와 맞는지 🔴
- **절차**: `spring.sql.init.mode` 를 **주지 않고**(기본 always) local 프로필로 기동
- **기대**: 정상 기동
- **실패 시**: `NULL not allowed for column "..."` — 마이그레이션으로 NOT NULL 컬럼이 추가됐는데 `data-local.sql` INSERT가 안 따라간 것. **컬럼 하나 고치면 다음 컬럼에서 또 터지므로 전수로 맞춰야 한다**
- **회귀 방지**: 새 NOT NULL 컬럼을 추가하는 마이그레이션 PR은 `data-local.sql` 도 같이 고친다

### TC-CONTRACT-006 FastAPI 콜백 경로 존재
- **절차**: 토큰 없이 아래를 호출
  - `PATCH /api/youtube-course-jobs/{jobId}/processing`
  - `PATCH /api/youtube-course-jobs/{jobId}/complete`
  - `PATCH /api/youtube-course-jobs/{jobId}/fail`
- **기대**: **401이 아니어야 한다**(404·400은 무방). 401이면 인증 화이트리스트에서 빠진 것 → 유튜브 기능 전면 중단

### TC-CONTRACT-007 Spring → FastAPI 호출 경로 존재
- **절차**: `FastApiClient` 가 부르는 경로를 FastAPI 라우터와 대조 (OCR·인증사진 판정·숙박확인서·PDF 병합)
- **기대**: 경로·메서드·필드명 일치. FastAPI는 **필드 추가만 허용, 삭제·이름변경 금지**(하위호환 원칙)
- **검증법**: FastAPI를 띄우고 영수증 OCR·인증사진 판정을 앱에서 한 번씩 태워 본다

### TC-CONTRACT-008 환경변수 예시가 실제 설정과 일치
- **절차**: `application.yml` 의 `${APP_*}` 목록과 `.env.example` 키 목록을 대조. FastAPI도 `config.py` ↔ `.env.example` 대조
- **기대**: 코드가 읽는 키가 예시 파일에 전부 있다. 빠져 있으면 **팀원이 받아서 띄우면 조용히 기본값으로 동작**한다
- **특히**: `APP_JWT_SECRET` 이 비면 재기동마다 전 사용자 로그아웃 → 예시 파일과 배포 환경 양쪽에 있어야 한다
