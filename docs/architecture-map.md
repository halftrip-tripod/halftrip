# 하프트립 아키텍처 맵 — 뭐가 어디서 도는가 (2026-08-13 규희)

> "지금 보는 화면이 목업인지 실데이터인지" 헷갈릴 때 보는 문서.
> 운영 상세는 [deployment-spec.md](deployment-spec.md), 진행률은 [progress-status.md](progress-status.md).

---

## 1. 한 장 요약

```
halftrip-design/          HTML 시각 프로토타입(32장) — 실앱 아님, 디자인 참고용(낡음)

halftrip-app (Flutter)    ★ 실제 앱 ★
 ├ lib/mock_ui/           이름과 달리 "라이브 UI 셸" — 스플래시·온보딩·4탭(홈/내여행/온라인몰/커뮤)
 ├ lib/screens/           기능 화면 — 숙박확인서·인증샷·영수증·정산·코스·설정…(셸에서 push)
 ├ lib/widgets/           디자인 시스템(규희 소유)
 └ lib/repositories/      데이터층 — 인터페이스 하나, 구현 둘
      ├ MockTravelRepository   시드 데이터 1,685줄 (서버 없이 동작)
      └ ApiTravelRepository    실서버 HTTP

halftrip-springboot       메인 API — 인증·여행·지역·정산·FCM   @ Render
halftrip-fastapi          AI·문서 — OCR·PDF·유튜브·AI코스      @ Render
```

## 2. 데이터는 어디에 있나 — "DB 3벌"

| 구분 | DB | 언제 쓰나 |
| --- | --- | --- |
| **mock** | 없음 — 앱 안의 시드(`mock_travel_repository.dart`) + 브라우저/기기 로컬저장 | 서버 없이 화면·UX 확인 (`USE_MOCK_API=true` 빌드) |
| **로컬 풀스택** | Docker MySQL·Redis (내 맥) | 백엔드까지 물려 개발할 때 (스프링·FastAPI 로컬 기동) |
| **운영** | Render 컨테이너 MySQL + Upstash Redis | 폰 APK 기본값·심사·팀원 테스트 |

- 앱이 어디 붙을지는 **빌드 플래그**가 결정: `USE_MOCK_API`(mock/실서버) · `API_BASE_URL`(기본=운영 onrender) · `MAP_PROVIDER`(google/kakao/mock).
- **운영 DB는 폰 APK가 기본으로 붙는 곳.** 웹 mock 빌드는 운영에 아무 영향 없음.

## 3. 실행 모드 매트릭스

| 모드 | 명령/방법 | 데이터 | 지도 | 용도 |
| --- | --- | --- | --- | --- |
| 웹 mock | `flutter build web --dart-define=USE_MOCK_API=true --dart-define=USE_MOCK_LOGIN=true --dart-define=MAP_PROVIDER=google --dart-define=GOOGLE_MAP_API_KEY=(local.properties 값)` → `serve_nocache.py`(포트 8643) | mock 시드 | 구글(키 주입 시) | 화면·UX 빠른 확인 ← **지금 8643에 떠 있는 것** |
| 로컬 풀스택 | Docker(MySQL·Redis) + 스프링(Java17) + FastAPI(py3.12) + 앱 `API_BASE_URL=로컬` | 로컬 MySQL | 구글 | E2E 개발·PDF 등 |
| 운영 | APK 기본 빌드 (dart-define 기본값 = onrender) | 운영 MySQL | 구글 | 심사·실사용 |

- mock 로그인: **sample / 1234** (`USE_MOCK_LOGIN=true`일 때).
- ⚠️ Flutter 웹은 **서비스 워커 캐시**가 세서 새 빌드가 바로 안 보일 수 있음 → 새로고침 2번 또는 시크릿창.

## 4. 화면별 데이터 소스 현황 (2026-08-13)

| 영역 | UI | 데이터 |
| --- | --- | --- |
| 핵심 여정(가입→여행→인증샷→OCR→숙박확인서→증빙→정산) | ✅ | ✅ 실서버 E2E 통과 |
| 지도 | ✅ | ✅ 구글맵 (키 주입 필요) |
| 코스—유튜브 | ✅ | ✅ 실서버 (Redis Stream→FastAPI 워커) |
| 코스—AI 추천 | ✅ | ✅ 실서버 (FastAPI `/api/v1/courses/ai-generate`, LLM+폴백) — 하민 8/12 |
| 코스—직접 만들기 | ✅ | 🟡 빈 코스 생성만 (장소검색 빌더 미연결) — 하민 영역 |
| 커뮤니티 | ✅ | 🟡 **이중 구조**: mock 모드=앱 내 로컬퍼스트(AppState+기기저장) / 실서버 모드=서버 API로 전환(`attachCommunityServer`) |
| 홈·지역상세·온라인몰 | ✅ | 🟡 실서버 연결돼 있으나 지역 시드 데이터 보강 필요 |
| 소셜 로그인 | ✅ | ⏸️ 키 대기 (하민 발급 후 즉시) |
| FCM 푸시 | ✅ | ⏸️ Render env 등록 대기 |

> mock 시드가 얇은 곳: **강진 지정관광지 1곳뿐** → AI 코스가 1곳짜리로 나옴 (버그 아님, 시드 문제).
> 커뮤니티 코스 태그 글은 **영월**에만 있음 (강진은 후기+첨부코스).

## 5. 헷갈림 방지 메모

- `lib/mock_ui/` = **실제 라이브 UI**. "mock"은 목업 HTML을 1:1 리스킨했다는 뜻이지 가짜 화면이 아님.
- `halftrip-design/`의 HTML은 **현재 앱보다 낡음** — 스토어 캡처·구현 참고로 쓰지 말 것 (8/13 스크린샷 사고).
- 커뮤니티 "지역 전체"는 탭 직접 진입 시 기본값. 지역 프리셋은 여행 상세 "인기 코스 보러 가기" 경로만.
- 지도 문구 "지도 미리보기를 준비 중" = 키 미주입 빌드라는 뜻.
