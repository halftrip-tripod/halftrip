# 지역 데이터 명세서 — 홈·상세·증빙에 필요한 값 채우기 (2026-08-20 규희)

> 배경: 운영 지역 API 실측 결과, 앱(준서 #51)이 파싱하는 **일정·환급 필드가 서버 응답에 아예 없음**
> (`dataSourceNote: SAMPLE_SEED` — 전부 샘플 시드). 그래서 홈 카드가 "조건은 상세에서 미리 확인" 폴백으로만 뜸.
> 운영 실측(8/20): 16지역 · statusCode = APPLYING 1 / PREPARING 2 / CLOSED 13 · 날짜 필드 0/16.

## 1. 서버에 추가할 필드 (regions) — 앱 필드명과 정확히 일치해야 함

| 필드 (JSON 키) | 타입 | 표시 위치 | 없을 때 폴백 |
| --- | --- | --- | --- |
| `applyStartDate` | date | 홈 카드 "오픈 예정 · N.N 오픈", 상세 신청 일정 | "오픈 예정 · 조건은 상세에서" |
| `applyDeadline` | date | 홈 D-day("마감 D-5"), 상세 접수 기간 | D-day 미표시 |
| `openDate` | date | 오픈예정 지역의 오픈일 표기 | 〃 |
| `travelPeriodStart` / `travelPeriodEnd` | date | 상세 "여행 기간 N.N~N.N 중 1박2일" | 문구 생략 |
| `settlementDeadlineDays` | int | 상세 "정산 신청: 여행 종료 다음날부터 N일 이내" | 기본 문구 |
| `refundRate` | int(%) | 상세 환급 요약 "50%" (청년 70% 지역은 비고로) | 50 고정 표기 |
| `maxRefundPerPerson` | int(원) | 상세 "1인 최대 N만원" | 미표시 |
| `paymentMethods` | string[] | 상세 결제수단 · **영수증 증빙 인정 결제수단 안내** | "지역화폐·카드" 일반 문구 |
| `refundConditionText` | string | 상세 인증 조건 요약("지정관광지 2곳 + 영수증") | 일반 문구 |
| `authRequiredCount` | int | **인증샷 요구 관광지 개소** — 여행 상세 인증 게이지(N/M곳) 기준 (V68 컬럼 추가됨) | 2곳 고정 폴백 |
| (기존) `refundConditionAmount` | int | 최소 소비 금액 — **증빙 게이지 기준** | 이미 있음 ✅ |
| (기존) `statusCode` | enum | APPLYING/PREPARING/CLOSED — 지도·필터 | 이미 있음 ✅ |

- ~~작업: Flyway 컬럼 추가 + DTO 필드 추가~~ → **8/20 확인: 이미 dev에 다 있음.** V64가 위 컬럼 전부 추가했고 RegionDtos·TripMapper도 연결 완료. 다만 **값이 16개 지역 전부 NULL**이라 운영 응답에 안 실렸던 것 (+운영은 main 배포 전이라 컬럼 자체도 아직).
- 남은 작업: ①기본값 시드 — `V67__seed_region_refund_defaults.sql` 작성함(환급 50%·1인 10만 일괄, 규희) ②일정·결제수단 등 지역별 실값 — 하민 수집 후 별도 마이그레이션.
- 증빙 검증 관점: 최소소비(`refundConditionAmount`)·인정 결제수단(`paymentMethods`)·인증 요건 문구(`refundConditionText`)가 영수증/인증샷 화면 안내와 일치해야 함.

## 2. 데이터 수집 방침 (→ 하민)

- **하반기(2차) 지역 위주로 수집** — 상반기 16곳 대부분 CLOSED라 심사위원이 볼 건 2차 지역. 상반기 지역은 공식 안내 기본값(환급 50%·1인 10만 등)으로 일괄 채워도 충분.
- 출처: 지역별 공고문(신청 URL 페이지) 하나면 아래 항목 대부분이 나옴.

### 2-1. 지역당 수집 항목 (공고 뜨는 대로 1지역 1세트)

**서버 시드용 (§1 필드)**
| 항목 | 예시 |
| --- | --- |
| 접수 시작일 / 마감일 / 오픈일 | 9/1 ~ 9/19 |
| 여행 가능 기간 | 9/15 ~ 11/30 |
| 정산 신청 기한 (여행 종료 후 N일) | 7일 |
| 환급률 / 1인 최대 환급액 | 50% / 10만 원 (청년 70% 등 예외 비고) |
| 최소 소비 금액 | 개인 3만 / 팀 5만 |
| 인정 결제수단 목록 | 지역화폐, 카드, 제로페이 |
| 인증 조건 요약 문구 | 지정관광지 2곳 + 영수증 |
| **인증샷 요구 관광지 개소 (숫자)** | 2곳 / 3곳 — 공고마다 다름, 문구와 별도로 숫자로 |
| 신청 URL / 디지털관광카드 URL | — |
| 거주지 제한 (있으면) | 도내 제외 등 |

**하드코딩·자산 반영용 (규희·준서에게 전달)**
| 항목 | 들어가는 곳 |
| --- | --- |
| **지역화폐 브랜드명·앱 이름·앱 설치 URL** | 앱 지역상세 switch + FastAPI OCR 키워드 (⭐없으면 그 지역화폐 영수증이 인정 결제로 안 잡힘) |
| 군청 위경도 (지도 핀) | 앱 korea_map + 서버 좌표 |
| 인정 관광지 목록 (이름·주소·좌표) | 서버 places 시드 |
| 가맹점 목록 CSV (이름,주소,카테고리,경도,위도) | merchant-seeds + 로드 마이그레이션 |
| 숙박확인서 공식 양식 파일 (hwp/pdf) | 스프링·FastAPI 템플릿 (미제공이면 공통 폴백으로 두면 됨) |
| 제외 업종·유의사항 | 앱 region_guides 텍스트 |
| 지역 대표 이미지 소재 | 일러스트 (준서) |

## 3. 🚨 하반기(2차) 지역 대응 — 9월 시작 예정

- 정부가 하반기 확대 발표: **7월 공모 → 추가 지자체 선정 → 9월 2차 사업 시작** (기사 기준 4~14곳).
- **9월 2차 = 우리 심사 기간(10월)과 정확히 겹침** → 심사위원이 보는 "접수중" 지역이 2차 지역들. **최우선 데이터**.
- 모니터링: [visitkorea 반값여행](https://korean.visitkorea.or.kr/dgtourcard/tour50.do)·문체부 보도자료 주 1회 확인 (하민).

### 3-1. 새 지역 추가 체크리스트 (8/20 3레포 전수 조사 결과)

**스프링 — 신규 마이그레이션 V68+ (V67까지 사용됨, V번호 선점 공지 필수)**
- [ ] `regions` INSERT: 이름·도·좌표(mapTop/LeftPercent)·거주지제한토큰·`refundConditionAmount` + §1 일정·환급 필드 값까지 같이
- [ ] `places`(인정 관광지)·`digital_tour_card_places`·`online_malls` INSERT (기존 패턴: V19·V21 등 `refresh_*_designated_places`)
- [ ] 가맹점 CSV `merchant-seeds/17-지역명.csv` 추가 + **로드용 신규 마이그레이션** (V30 Java 마이그레이션은 이미 적용돼 수정 불가 — 로직 복제 필요, 형식: 이름,주소,카테고리,경도,위도)
- [ ] 숙박확인서: `lodging_form_templates` 행 INSERT + `resources/lodging-form-templates/*.json` + `provided_pdfs/*.pdf` (양식 미제공 지역은 공통 폴백으로 동작 — 영월·제천·고흥이 현재 그 상태)
- [ ] 디지털혜택 지역이면 `digital_benefit_available=1`

**FastAPI — 숙박확인서 양식 있는 지역만**
- [ ] `templates/lodging_forms/docx/` 등 자산 + `docx_lodging_service.py`의 `_REGION_STEMS`·`_TEMPLATE_LAYOUTS` + `pdf_service.py`의 `_TEMPLATE_INSET_PROFILES` 항목 추가
- [ ] 새 지역 지역화폐 브랜드명(예: "○○페이") → `mock_ocr.py` 결제수단 키워드에 추가 (안 하면 OCR이 인정 결제로 인식 못 함)

**앱 — 하드코딩 4곳 (안 고치면 폴백 문구·부정확 핀)**
- [ ] `lib/data/region_guides.dart` `_guides` 맵에 지역 정산규칙 블록 추가 (⭐없으면 "정산 규칙 미정리" 폴백 + 결제수단·최소소비 요약 부정확)
- [ ] `lib/screens/region_action_screen.dart:723~` 지역화폐 앱 이름·안내문·이모지 switch 3종
- [ ] `lib/widgets/korea_map.dart:28` `_regionLatLng`에 군청 위경도 추가 (이 하드코딩이 서버 percent보다 **우선**)
- [ ] 지역 히어로/일러스트 자산 `assets/region_hero/`·`assets/illust/region/` + pubspec (일러스트 = 준서)

**코드 무수정으로 되는 것** (서버 시드만으로 자동): 인정 관광지·가맹점·온라인몰 노출, 신청 URL, 환급 기준·결제수단 표시, 숙박확인서 폼 렌더(서버 템플릿 기반), OCR 금액 검증, 유튜브 코스(지역명 기반 완전 동적), 카카오·구글 장소 연동.

## 4. 발견된 앱 후속 버그
- ~~홈 지도 핀이 CLOSED(13개) 지역을 회색 처리하지 않음~~ → **8/20 픽스 완료** (`fix/home-closed-pin` — 접수중 p500/오픈예정 p300/마감 gray 3분기 + 위젯 테스트).

