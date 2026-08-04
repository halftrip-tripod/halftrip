# TourAPI 활용 확대 설계 (2026-08-04 · 회의 안건)

> 목표: 남은 개발(직접 코스 장소검색·AI 코스·장소 상세)과 공모전 필수 요건(공사 OpenAPI **실시간** 활용, 호출 이력, 기능설명서 활용 내역)을 **한 설계로 동시 해결**.
> 현재 TourAPI 사용처는 유튜브 장소 정규화 1곳(fastapi `_search_tour_api_place` → `searchKeyword2`)뿐 — 보강 필요.
> 담당: 서버·워커 = **하민** / 클라 = 규희(코스·장소·축제) + 준서(온라인몰 쇼핑 섹션)

---

## 0. 쓰는 TourAPI 엔드포인트 (KorService2)

| 엔드포인트 | 용도 | 핵심 파라미터 |
| --- | --- | --- |
| `areaBasedList2` | 지역별 장소 목록 (타입별) | `areaCode`·`sigunguCode`·`contentTypeId`·`arrange` |
| `searchKeyword2` | 키워드 장소 검색 *(이미 사용 중)* | `keyword`·`areaCode` |
| `locationBasedList2` | 좌표 반경 주변 검색 | `mapX`·`mapY`·`radius`·`contentTypeId` |
| `detailCommon2` | 공통 상세 (개요·주소·좌표·대표이미지·전화) | `contentId` |
| `detailIntro2` | 타입별 상세 (운영시간·쉬는날·이용료·주차·대표메뉴 등) | `contentId`·`contentTypeId` |
| `detailImage2` | 추가 이미지 | `contentId` |
| `searchFestival2` | 축제·행사 (기간 조회) | `eventStartDate`·`areaCode` |

contentTypeId: **12** 관광지 · **14** 문화시설 · **15** 축제 · **28** 레포츠 · **32** 숙박 · **38** 쇼핑(전통시장·특산품) · **39** 음식점

**선행 작업**: 우리 16개 지역 → TourAPI `areaCode`/`sigunguCode` 매핑. `regions` 테이블에 두 컬럼 추가(Flyway 신규 번호 선점 공지 필요), 값은 `areaCode2` 엔드포인트로 조회해 시드.

---

## 1. 기능별 설계

### A. 직접 코스 만들기 — 장소 검색 실데이터화
지금 강진 5곳 하드코딩인 장소 검색을 TourAPI 실시간 검색으로.

- **Spring 프록시** `GET /api/regions/{regionId}/tour-places?type={12|39|32|38}&keyword=&page=`
  → `areaBasedList2`(키워드 없을 때) / `searchKeyword2`(있을 때) 실시간 호출
  → 응답(공통 래퍼): `{contentId, contentTypeId, name, address, lat, lng, imageUrl, tel}`
- 프록시로 두는 이유: **서비스키 비노출** + 호출 이력·실패 폴백을 한 곳에서 관리.
- 클라(course-search 화면): 카테고리 칩 매핑 — 전체/관광지(12)/맛집(39)/숙소(32)/시장·쇼핑(38). 선택한 장소는 기존 `SavedCourseStop` 형태로 코스에 담김 (placeId 없는 TourAPI 장소는 `sourceType: "TOUR_API"` + contentId 보존).
- **환급 인정 여부 구분 필수**: 지정 관광지(우리 DB)만 환급 인정 — TourAPI 장소에는 인정 뱃지를 붙이지 않는다.

### B. AI 코스 생성 (백엔드 H — 신규)
유튜브 코스와 같은 잡 패턴 재사용: Spring 잡 생성 → Redis Stream → FastAPI 워커 → 콜백.

1. 입력: 지역·일수·인원·테마(기존 UI 그대로)
2. 워커: `areaBasedList2`로 후보 풀 수집 — 관광지(12)+음식점(39)+숙박(32) 각 상위 N개(arrange=인기순)
3. LLM이 동선 구성. **제약 프롬프트**: ①우리 지정 관광지 ≥2곳 포함(환급 조건 충족) ②일수별 동선 거리 최소화 ③끼니 시간대에 음식점 배치
4. 결과는 유튜브 코스와 동일 스키마로 콜백 → 기존 클라 코스 화면 재사용
- 공모전 스토리: "공사 OpenAPI 데이터 기반 AI 코스 생성" = 기능설명서 핵심 기능 + 데이터 활용성 입증. 호출량도 가장 많이 쌓이는 지점.

### C. 장소 상세 보강 (백엔드 ⑦ 대체)
`places`에 컬럼 추가하는 대신 TourAPI 실시간 조회로.

- 지정 관광지 ↔ TourAPI `contentId` 매칭: 최초 1회 `searchKeyword2`(이름+좌표 근접)로 매칭해 **contentId만 저장**(상세 데이터는 저장하지 않음 — 실시간 권고 준수)
- `GET /api/places/{placeId}/tour-detail` → `detailCommon2` + `detailIntro2` + `detailImage2` 조합:
  개요·운영시간(usetime)·쉬는날(restdate)·이용료(usefee)·주차(parking)·전화 + 실사진(이모지 플레이스홀더 대체)
- 클라 장소 상세 화면(현재 가우도 고정 하드코딩)을 이 응답으로 바인딩.

### D. 지역 축제·행사 카드 (신규 · 가점성)
- `GET /api/regions/{regionId}/festivals?from=&to=` → `searchFestival2(eventStartDate, areaCode)` → 기간 겹침 필터는 서버에서
- 노출: ①지역 상세 "이 기간 축제" 섹션 ②여행 상세 — 내 여행 날짜와 겹치는 축제 카드
- 반값여행 컨셉과 궁합: "환급 여행 가는 김에 축제도" — 기능설명서 차별성 소재.

### E. 지역화폐 사용처 — 전통시장·특산품 (온라인몰 탭)
- `areaBasedList2(contentTypeId=38)` → 전통시장·특산품 매장 목록을 온라인몰 탭 "오프라인 사용처" 섹션 카드 + 가맹점 지도 핀으로
- ⚠️ TourAPI는 **지역화폐 사용 가능 여부를 주지 않음** — "전통시장·특산품 매장"으로만 표기하고, 우리 가맹점 DB와 이름 매칭되는 곳에만 "지역화폐" 뱃지. 지자체 온라인몰 링크는 지금처럼 수동 유지.

---

## 2. 공통 원칙

- **실시간 호출** (공모전 6-1): DB에 원데이터 저장 금지. 부하 방지용 Redis 캐시는 TTL 5~10분 이내로만 — 애매하면 사무국(tourapi@knto.or.kr)에 캐시 범위 문의.
- **출처 표기** (6-2): 텍스트 `출처: ⓒ한국관광공사`만 허용(로고 금지). 공통 위젯 `TourApiAttribution` 준비됨 — `label` 옵션으로 "장소 정보 출처: …"처럼 무엇의 출처인지 문맥화 가능. 이용약관 제10조(콘텐츠 출처 고지)에 전역 고지 완료. **화면별 부착 위치는 코스 기능 완성 후 일괄 결정** (A~E 구현 시 각 화면에 위젯만 얹으면 됨).
- **키 관리**: 서비스키는 서버 env로만 (클라 직호출 금지). 운영은 팀 대표 키 1개로 통일해 호출 이력을 몰아주고, 제출 시 팀에서 쓴 키 일체 제출.
- **폴백**: TourAPI 5xx/타임아웃 시 빈 섹션 숨김 + 기존 데이터 유지 (Render 콜드스타트 대비 타임아웃 짧게).
- 개발 기간 내 호출 이력이 심사 자료 — **8월 초부터 dev에서 실호출 쌓기 시작**.

## 3. 우선순위 제안 (회의에서 확정)

| 순서 | 항목 | 크기 | 비고 |
| --- | --- | --- | --- |
| 1 | 지역코드 매핑 + A 장소검색 프록시 | 서버 1일 + 클라 0.5일 | 기존 searchKeyword2 코드 재활용 |
| 2 | C 장소 상세 | 서버 1일 + 클라 0.5일 | ⑦ 요청 대체 |
| 3 | B AI 코스 | 서버 2~3일 | H 요청 대체, 유튜브 잡 패턴 재사용 |
| 4 | D 축제 | 서버 0.5일 + 클라 0.5일 | 가점·차별성 |
| 5 | E 전통시장 | 서버 0.5일 + 클라(준서) 0.5일 | 온라인몰 보강 |
