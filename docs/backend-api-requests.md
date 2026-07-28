# 백엔드 API 요청 정리 (2026-07-10 기준)

> 실제 백엔드 코드(springboot `a55d764` · fastapi `7a3bfea`)를 화면 계약과 필드 단위로 대조한 결과.
> 상세 명세는 `docs/backend-handoff.md` 참고 (⚠️ = 수정, ➕ = 신규).

## 🔴 구현됐지만 고쳐야 하는 것

| # | 항목 | 할 일 | 관련 화면 | 담당 |
|---|------|------|----------|------|
| 1 | 알림 딥링크 | `notifications`에 `ref_type`·`ref_id` 컬럼 + 응답 필드 추가 (`REGION`·`COURSE`·`POST`·`TRIP`·`MERCHANT` + 대상 PK) | 알림 센터 (탭 시 화면 이동) | 하민 |
| 2 | 인증샷 위치검증 배선 | `POST /trips/{tripId}/auth-photos/analyze`에 **placeId 추가** → Spring이 관광지 좌표·반경을 FastAPI로 전달 → `auth_photo_reviews`에 `place_id` 저장 (지금 `locationVerified` 항상 null) | 관광지 인증 | 정훈 |
| 3 | 인증 카운트 재집계 | `authCertifiedCount`를 사진 수 → **인증된 관광지 개소 수**(distinct place)로 변경 (2번 선행 필요) | 내 여행 카드 게이지 | 정훈 |
| 4 | 체크리스트 서버 저장 | 체크리스트 = **사용자 직접 체크 방식으로 확정**. 자동판정 로직 대신 저장 API 필요: `GET·PUT /trips/{tripId}/checklist` (항목별 체크 상태 저장, `checklistDoneCount`도 이 값으로 집계) | 내 여행 카드·여행 전 상세 | 정훈 |
| 5 | 알림 createdAt | KST offset(`+09:00`) 포함 직렬화 (minor) | 알림 센터 | 하민 |

## 🟡 신규 필요 (없음)

| # | 항목 | 엔드포인트 / 컬럼 | 관련 화면 | 담당 |
|---|------|------|----------|------|
| 6 | 지역 날짜·조건 필드 | `regions`에 `apply_deadline`·`open_date`·`refund_condition_text`·`refund_rate`·`payment_methods`·`local_currency_app_url` 등 → 3번의 `authRequiredCount`·`settlementDeadline`도 이걸로 풀림 | 홈 D-day 칩·지역 상세·온라인몰 | 하민 |
| 7 | 장소 상세 필드 | `places`에 `opening_hours`·`admission_fee`·`phone`·`payment_methods` | 장소 상세 | 하민 |
| 8 | 거주지 수정 | `PATCH /api/users/{userId}/residence` | 마이페이지 | 정훈 |
| 9 | 프로필 수정 | `PUT /api/users/{userId}/profile` (nickname·avatarPreset) | 프로필 편집 | 정훈 |
| 10 | AI 코스 생성 | `POST /api/courses/generate` (지역·일수·인원·테마) | 코스 만들기 | 협의 |
| 11 | 저장 코스함 | `saved_courses` 테이블 + CRUD | 코스함·홈 저장코스 | 협의 |
| 12 | 커뮤니티 전체 | 피드·상세·작성·댓글·좋아요·북마크·프로필 (Phase 3) | 커뮤니티 전체 | 협의 |
| 13 | ~~회원 탈퇴~~ ✅ 완료(07-28) — 클라 연결·E2E 검증 끝 | `DELETE /api/users/{userId}` soft delete | 설정 | 정훈 |
| 14 | 🐛 직접 장소 추가 불가 | `POST /trips/{id}/places`에 `referencePlaceId` 없이 보내면 DB 에러(컬럼 NOT NULL) — 코스 "직접 만들기"로 검색해 넣는 장소가 저장 안 됨. **nullable로 변경 필요** (2026-07-14 실서버 테스트로 발견) | 코스 직접 만들기 | 정훈 |
| 15 | 🐛 정산 응답 enum 위반 | `settlement-apply` 응답 `status`가 `"정산 신청 완료"` 한글 문자열 — 계약은 `SETTLEMENT_REQUESTED` enum | 정산 | 정훈 |
| 16 | 여행 삭제 | `DELETE /api/trips/{tripId}` 없음 — 잘못 만든 여행을 지울 방법이 없음 | 내 여행 | 정훈 |

## 우선순위

①②③ (킬러기능·알림이 반쪽) → ⑥⑧⑨ → ④⑦ → ⑩⑪ → ⑫⑬

## 참고 — 클라(규희) 후속 작업

- `getNotifications`에 `userId` 쿼리 추가 (백엔드 시그니처가 필수 쿼리 — 현재 클라 호출은 400)
- 정산 신청 시 실명·전화 입력 UI → `SettlementApplyRequest`로 전송
- E 신필드·`locationVerified` 파싱 추가 (완료) · 마케팅 알림 토글은 기획에서 제외 확정
