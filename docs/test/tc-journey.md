# TC-JOURNEY — 핵심 여정 E2E

> 3개 레포가 다 붙어야 통과하는 시나리오. **하나라도 깨지면 그날 릴리스 없음.**
> 전제: Spring + FastAPI + Flutter 3개 다 기동, `USE_MOCK_API=false`

| ID | 케이스 | 걸치는 레포 |
| --- | --- | --- |
| TC-JOURNEY-001 | 가입 → 로그인 → 홈 | Flutter · Spring |
| TC-JOURNEY-002 | 여행 등록 | Flutter · Spring |
| TC-JOURNEY-003 | 관광지 인증샷 | Flutter · Spring · FastAPI |
| TC-JOURNEY-004 | 영수증 OCR | Flutter · Spring · FastAPI |
| TC-JOURNEY-005 | 숙박확인서 → PDF | Flutter · Spring · FastAPI |
| TC-JOURNEY-006 | 증빙 패키지 병합 | Flutter · Spring · FastAPI |
| TC-JOURNEY-007 | 정산 신청 | Flutter · Spring |
| TC-JOURNEY-008 | 유튜브 코스 (비동기) | Flutter · Spring · FastAPI · Redis |
| TC-JOURNEY-009 | 커뮤니티 글 + 인증 배지 | Flutter · Spring |
| TC-JOURNEY-010 | 여행 삭제 | Flutter · Spring |

---

### TC-JOURNEY-001 가입 → 로그인 → 홈
- **절차**: 앱 실행 → 회원가입(거주지 포함) → 로그인 → 홈 진입
- **기대**: 홈에 지역 카드가 **실서버 데이터**로 뜬다. 거주지 뱃지 반영. 재실행 시 로그인 유지
- **교차 확인**: `GET /api/regions` 응답 지역 수 == 홈 카드 수

### TC-JOURNEY-002 여행 등록
- **절차**: 내 여행 → 추가 → 접수중 지역 선택 → 날짜·인원 → 생성
- **기대**: 목록에 카드 생성. `tripStatus` 는 **서버가 KST로 계산한 값**
- **교차 확인**: 기기 날짜를 바꿔도 단계 칩이 안 변해야 한다(서버 기준). 바뀌면 클라가 로컬 계산 중

### TC-JOURNEY-003 관광지 인증샷 (FastAPI 판정)
- **절차**: 여행 상세 → 인증할 관광지 칩 선택 → **GPS EXIF 있는 실사진** 업로드
- **기대**: 판정 카드에 인원·얼굴·촬영시각·위치검증 표시. 인증 개소 카운트 +1
- **주의**: 스크린샷·SNS 저장본은 EXIF가 없어 `locationVerified=false` 가 **정상**. 폰 실기기로 찍은 사진으로 테스트
- **교차 확인**: FastAPI 로그에 `photos/auth-review` 요청이 찍힌다

### TC-JOURNEY-004 영수증 OCR
- **절차**: 영수증 사진 업로드 → 분석
- **기대**: 금액·날짜·업종 인식 → 인정 여부 판정 → **누적 소비 금액 증가**
- **교차 확인**: `GET /api/trips/{id}/settlement-summary` 의 합계가 화면과 일치

### TC-JOURNEY-005 숙박확인서 → PDF
- **절차**: 숙박확인서 작성 → 서명 → PDF 미리보기·다운로드
- **기대**: 지역별 양식이 맞게 뜨고, 입력값이 PDF의 올바른 칸에 들어간다
- **주의**: 지역마다 양식이 다르다. **최소 2개 지역**(완도·해남 등)으로 확인

### TC-JOURNEY-006 증빙 패키지 병합
- **절차**: 증빙 패키지 화면 → 파일 선택 → 병합 PDF 생성
- **기대**: 선택한 파일이 순서대로 한 PDF에. 페이지 수 == 선택 파일 수(멀티페이지 감안)

### TC-JOURNEY-007 정산 신청
- **절차**: 정산 화면 → 신청 → 실명·전화 입력 시트
- **기대**: 빈 값이면 차단. 신청 후 `tripStatus=SETTLEMENT_REQUESTED`, 지난 여행으로 이동
- **개인정보 확인**: 실명·전화는 **정산 레코드에만** 저장되고 계정에는 안 남아야 한다 (`GET /api/users/{id}` 응답에 노출 여부 확인)

### TC-JOURNEY-008 유튜브 코스 (비동기·Redis)
- **절차**: 코스 만들기 → 유튜브 링크 입력 → 진행 상태 확인
- **기대**: 잡 생성(PENDING) → **PROCESSING → COMPLETED** 로 바뀌고 장소 목록이 나온다
- **끝까지 안 가면**: FastAPI 워커가 Spring에 콜백하는 URL(포트!)과 Redis 스트림 이름을 확인 → TC-CONTRACT-004
- **주의**: OPENAI·YOUTUBE 키가 없는 환경에서는 PROCESSING에서 실패가 정상

### TC-JOURNEY-009 커뮤니티 글 + 인증 배지
- **절차**: 다녀온 여행을 근거로 후기 작성 → 피드 확인 → 코스 첨부
- **기대**: 인증 배지(✓) 표시. 좋아요·댓글 시 알림 생성
- **교차 확인**: 작성자가 **본인**으로 저장됐는지 (`authorId`) — 위장 여부는 TC-SEC-007

### TC-JOURNEY-010 여행 삭제
- **절차**: 일반 여행 삭제 / 정산 신청한 여행 삭제 시도
- **기대**: 일반 여행은 삭제되고 목록에서 사라진다. 정산 신청한 여행은 **400 + 안내 문구**
- **교차 확인**:
  - 스토리지에서 그 여행의 업로드 파일이 **실제로 사라졌는지**
  - 그 여행을 첨부한 커뮤니티 글은 **삭제되지 않고 남아 있는지**(배지만 사라짐)
  - 유튜브 잡 이력도 남아 있는지
