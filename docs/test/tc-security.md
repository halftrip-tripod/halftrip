# TC-SEC — 인증·권한·개인정보

> 전제: Spring이 `app.auth.token-enforced=true` 로 떠 있어야 한다. **false면 대부분 무의미하게 통과한다.**
> 계정 2개(`qaA`, `qaB`)가 필요하다. 아래에서 A·B는 각각의 userId·토큰을 뜻한다.

| ID | 케이스 | 자동 |
| --- | --- | --- |
| TC-SEC-001 | 로그인 응답이 JWT를 준다 | ✅ |
| TC-SEC-002 | 토큰 없이 보호 API 호출 차단 | ✅ |
| TC-SEC-003 | 위조 토큰 차단 | ✅ |
| TC-SEC-004 | 남의 `?userId=` 차단 | ✅ |
| TC-SEC-005 | 남의 `/users/{id}` 차단 | ✅ |
| TC-SEC-006 | 남의 `/trips/{id}` 차단 | ✅ |
| TC-SEC-007 | **요청 body의 userId 위장 차단** | ✅ |
| TC-SEC-008 | 공개 경로는 토큰 없이 통과 | ✅ |
| TC-SEC-009 | 탈퇴 계정 토큰 무효화 | ✅ |
| TC-SEC-010 | 비밀번호 BCrypt 저장·검증 | ✅ |
| TC-SEC-011 | 기존 SHA-256 계정 자동 전환 | — |
| TC-SEC-012 | 탈퇴 시 업로드 파일 파기 | — |
| TC-SEC-013 | 정산 신청 이력 있으면 탈퇴 거부 | — |

---

### TC-SEC-001 로그인 응답이 JWT를 준다
- **전제**: `qaA` 계정 존재
- **절차**: `POST /api/auth/login {"loginId":"qaA","password":"1234"}`
- **기대**: 200. `data.token` 이 점(`.`) 2개인 JWT. `data.mockToken` 은 같은 값(하위호환). 값이 `local-token-1` 처럼 **추측 가능한 형태면 실패**

### TC-SEC-002 토큰 없이 보호 API 호출 차단
- **전제**: enforce=true
- **절차**: `GET /api/trips?userId=1` (Authorization 헤더 없이)
- **기대**: **401**
- ⚠️ enforce=false(운영 기본값)에서는 **200이 정상**이다. 이 케이스는 enforce를 켜야만 의미가 있다

### TC-SEC-003 위조 토큰 차단
- **절차**: `Authorization: Bearer aaa.bbb.ccc` 로 `GET /api/users/{A}`
- **기대**: 401. 다른 시크릿으로 서명한 토큰도 401

### TC-SEC-004 남의 `?userId=` 차단
- **절차**: A 토큰으로 `GET /api/trips?userId={B}`
- **기대**: **403** + 메시지 "다른 사용자의 정보에는 접근할 수 없습니다."
- **함께 확인**: `GET /api/notifications?userId={B}` 도 403

### TC-SEC-005 남의 `/users/{id}` 차단
- **절차**: A 토큰으로 `GET /api/users/{B}`
- **기대**: 403. 자기 것(`/api/users/{A}`)은 200
- **함께 확인**: `/api/community/users/{B}/posts`, `/api/community/users/{B}/bookmarks` 도 403

### TC-SEC-006 남의 `/trips/{id}` 차단
- **전제**: B 소유 여행 1건
- **절차**: A 토큰으로 `GET /api/trips/{B의tripId}` · `PUT` · `DELETE` · `/settlement-summary`
- **기대**: 전부 403
- **참고**: 존재하지 않는 tripId도 403이 나온다(존재 여부를 흘리지 않으려는 동작). 클라가 "없는 여행"과 "권한 없음"을 구분해야 한다면 별도 협의 필요

### TC-SEC-007 요청 body의 userId 위장 차단 🔴
> **경로·쿼리만 막고 body를 안 막으면 남의 이름으로 글이 써진다.** 회귀가 가장 잘 나는 자리.
- **절차**: A 토큰으로 아래를 각각 호출하고 **body의 userId에 B**를 넣는다
  - `POST /api/community/posts` `{"userId":B, "type":"REVIEW", ...}`
  - `POST /api/community/posts/{id}/comments` `{"userId":B, ...}`
  - `POST /api/community/reports` `{"userId":B, ...}`
  - `POST /api/trips` `{"userId":B, ...}`
- **기대**: 전부 **403**
- **검증 보강**: 200이 났다면 `GET /api/community/users/{B}/posts` 로 **B 이름으로 글이 실제로 생겼는지** 확인한다. `authorId`가 B면 위장 성공 = 실패 케이스

### TC-SEC-008 공개 경로는 토큰 없이 통과
- **절차**: 토큰 없이 `GET /api/regions`, `POST /api/auth/login`, `PATCH /api/youtube-course-jobs/{jobId}/processing`, `GET /api/trips/settlement-reminder-targets?date=...`
- **기대**: 401이 아니어야 한다(404·400은 무방). **FastAPI 콜백과 스케줄러가 여기서 막히면 유튜브 분석·리마인더가 통째로 죽는다**

### TC-SEC-009 탈퇴 계정 토큰 무효화
- **전제**: 일회용 계정으로 로그인해 토큰 확보
- **절차**: `DELETE /api/users/{id}` 로 탈퇴 → **같은 토큰으로** `GET /api/users/{id}`
- **기대**: 401 (만료 전이라도 계정 상태로 막혀야 한다)

### TC-SEC-010 비밀번호 BCrypt 저장·검증
- **절차**: 신규 가입 → 로그인 성공 / 틀린 비밀번호 로그인
- **기대**: 맞으면 200, 틀리면 400. DB `users.password_hash` 가 **`$2` 로 시작**
- **확인법**: `SELECT login_id, LEFT(password_hash,4) FROM users;` — `$2a$`·`$2b$` 여야 하고, 64자 16진수면 아직 SHA-256

### TC-SEC-011 기존 SHA-256 계정 자동 전환
- **전제**: 마이그레이션 전에 만들어진 계정(예: `sample`)
- **절차**: 비밀번호 재설정 없이 로그인 1회 → DB 해시 재확인
- **기대**: 로그인 200, 그 직후 해시가 `$2` 로 바뀐다. **재설정을 요구하면 실패**

### TC-SEC-012 탈퇴 시 업로드 파일 파기 🔴
- **전제**: 일회용 계정으로 여행 생성 → 인증사진·영수증 업로드
- **절차**: 저장 위치를 먼저 확인(`APP_STORAGE_ROOT` 하위 `trip-{id}/` 또는 Supabase 버킷) → 탈퇴 → 같은 위치 재확인
- **기대**: 개인정보 필드 null, 닉네임 "탈퇴한 사용자", **업로드 파일이 실제로 사라짐**. DB 행만 지우고 파일이 남으면 실패

### TC-SEC-013 정산 신청 이력 있으면 탈퇴 거부
- **전제**: 정산 신청까지 끝낸 계정
- **절차**: `DELETE /api/users/{id}`
- **기대**: 400 + "정산 심사가 진행 중인 여행이 있어 탈퇴할 수 없습니다." 개인정보도 그대로 남아 있어야 한다
