# 반값여행 레포 가이드

## 1. 레포 구성

| 레포 | 역할 | 먼저 볼 폴더 |
|---|---|---|
| `flutter_app` | 사용자 화면, 지도, 플래너, 업로드, 유튜브 코스 결과 표시 | `lib/screens`, `lib/core`, `lib/repositories`, `lib/widgets` |
| `backend-spring` | 메인 API, DB 저장, Redis, FCM, 플래너/정산/숙박확인서 관리 | `controller`, `service`, `client`, `repository`, `config`, `resources/db/migration` |
| `backend-fastapi` | OCR, 인증사진 판정, PDF 생성, 유튜브 분석, 유튜브 worker | `app/routers`, `app/services`, `app/workers`, `app/core`, `tests` |

## 2. flutter_app

### 핵심 폴더

| 폴더 | 용도 |
|---|---|
| `lib/core` | 앱 전역 상태, 환경변수, 의존성 주입 |
| `lib/repositories` | Spring/FastAPI 통신 |
| `lib/screens` | 실제 화면 |
| `lib/widgets` | 지도, PDF, 서명 등 공통 위젯 |

### 핵심 파일

| 파일 | 담당 |
|---|---|
| `lib/core/app_config.dart` | Flutter 환경변수 |
| `lib/core/app_controller.dart` | 로그인 상태, trip 목록, saved course, FCM |
| `lib/repositories/api_travel_repository.dart` | 서버 API 호출 구현 |
| `lib/screens/place_info_screen.dart` | 지정관광지/가맹점 지도 |
| `lib/screens/planner_screen.dart` | 현재 여행 플래너 |
| `lib/screens/saved_course_list_screen.dart` | 저장 코스 불러오기 |
| `lib/screens/youtube_course_analysis_screen.dart` | 유튜브 코스 생성 상태/결과 |
| `lib/screens/lodging_form_screen.dart` | 숙박확인서 작성 |
| `lib/screens/receipt_evidence_screen.dart` | 영수증 업로드/분석 |
| `lib/screens/auth_photo_upload_screen.dart` | 인증사진 업로드/판정 |
| `lib/widgets/place_map_view_web.dart` | Kakao Maps Web 구현 |

### 환경변수

- `API_BASE_URL`
- `FASTAPI_BASE_URL`
- `USE_MOCK_LOGIN`
- `USE_MOCK_API`
- `MAP_PROVIDER`
- `KAKAO_MAP_APP_KEY`

## 3. backend-spring

### 핵심 폴더

| 폴더 | 용도 |
|---|---|
| `controller` | 외부 공개 REST API |
| `service` | 핵심 비즈니스 로직 |
| `client` | FastAPI / Kakao 외부 호출 |
| `repository` | DB 접근 |
| `config` | Redis, Firebase, WebClient, CORS |
| `src/main/resources/db/migration` | Flyway 마이그레이션 |
| `src/main/resources/lodging-form-templates` | 숙박확인서 schema |
| `src/main/resources/templates/lodging_forms/provided_pdfs` | 숙박확인서 원본 PDF |

### 핵심 파일

| 파일 | 담당 |
|---|---|
| `controller/AuthController.java` | 로그인/회원가입 |
| `controller/UserController.java` | 프로필, 관심지역, 알림, FCM token |
| `controller/RegionController.java` | 지역/관광지/가맹점 지도 API |
| `controller/TripController.java` | 여행, 플래너, 업로드, OCR, 정산, PDF |
| `controller/YoutubeCourseJobController.java` | 유튜브 Job API |
| `service/TripService.java` | 여행 도메인 핵심 |
| `service/RegionService.java` | 지역 상세 |
| `service/RegionPlaceCacheService.java` | 지정관광지 Redis 캐시 |
| `service/MerchantMapService.java` | 가맹점 marker/detail |
| `service/YoutubeCourseJobService.java` | Job 생성/조회/완료 |
| `service/YoutubeCourseJobStreamService.java` | Redis Stream enqueue |
| `service/FcmNotificationService.java` | FCM 발송 |
| `client/FastApiClient.java` | FastAPI 호출 |
| `client/KakaoLocalClient.java` | Kakao Local API 호출 |
| `config/AppConfig.java` | Redis/Firebase 설정 |
| `config/AppProperties.java` | app 환경변수 매핑 |

### 환경변수

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `PORT`
- `FASTAPI_BASE_URL`
- `APP_ALLOWED_ORIGINS`
- `MOCK_EXTERNAL_DATA`
- `APP_STORAGE_ROOT`
- `SPRING_DATA_REDIS_HOST`
- `SPRING_DATA_REDIS_PORT`
- `SPRING_DATA_REDIS_USERNAME`
- `SPRING_DATA_REDIS_PASSWORD`
- `SPRING_DATA_REDIS_SSL_ENABLED`
- `APP_KAKAO_REST_API_KEY`
- `APP_KAKAO_TIMEOUT_SECONDS`
- `APP_FCM_SERVER_KEY`
- `APP_FCM_SERVICE_ACCOUNT_PATH`
- `APP_FCM_SERVICE_ACCOUNT_JSON`
- `APP_FIREBASE_PROJECT_ID`

## 4. backend-fastapi

### 핵심 폴더

| 폴더 | 용도 |
|---|---|
| `app/routers` | 외부 엔드포인트 |
| `app/services` | OCR/PDF/유튜브 분석 실제 로직 |
| `app/workers` | Redis Stream worker |
| `app/core` | 환경변수 로딩 |
| `tests` | 유닛 테스트 |

### 핵심 파일

| 파일 | 담당 |
|---|---|
| `app/routers/documents.py` | OCR/PDF/인증사진 API |
| `app/routers/videos.py` | direct 유튜브 분석 API |
| `app/services/mock_ocr.py` | 영수증/숙박 OCR |
| `app/services/auth_photo_review_service.py` | 인증사진 판정 |
| `app/services/pdf_service.py` | PDF 병합/생성 |
| `app/services/template_ai_service.py` | 템플릿 분석 |
| `app/services/youtube_course_service.py` | 자막/프레임/OpenAI/관광공사/Kakao 기반 장소 추출 |
| `app/services/spring_job_callback_service.py` | Spring callback |
| `app/workers/youtube_course_worker.py` | 유튜브 Job worker |
| `app/core/config.py` | FastAPI 환경변수 |
| `tests/test_youtube_course_service.py` | 유튜브 장소 매칭 테스트 |

### 환경변수

- `APP_ENV`
- `TEMP_UPLOAD_DIR`
- `COMMON_LODGING_TEMPLATE_PATH`
- `OPEN_AI_KEY`
- `OPEN_AI_MODEL`
- `YOUTUBE_API_KEY`
- `TOUR_API_SERVICE_KEY`
- `KAKAO_REST_API_KEY`
- `APP_ALLOWED_ORIGINS`
- `REDIS_URL`
- `SPRING_API_BASE_URL`
- `YOUTUBE_COURSE_STREAM_NAME`
- `YOUTUBE_COURSE_CONSUMER_GROUP`
- `YOUTUBE_COURSE_CONSUMER_NAME`
