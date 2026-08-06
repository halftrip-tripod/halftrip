# 반값여행 앱 API / DB 명세서

## 1. API 명세서

### 1-1. 인증 / 사용자

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 1 | auth | POST | `/api/auth/mock-login` | `{ "provider": "KAKAO", "email": "sample@travel-mvp.local", "name": "샘플 사용자" }` | `{ "success": true, "data": { "userId": 1, "name": "샘플 사용자", "email": "sample@travel-mvp.local", "provider": "KAKAO", "mockToken": "mock-token-1" }, "message": null }` | mock 로그인 |
| 2 | auth | POST | `/api/auth/signup` | `{ "name": "홍길동", "loginId": "hong", "password": "1234", "phoneNumber": "010-0000-0000", "residence": "서울특별시 종로구" }` | `{ "success": true, "data": { "userId": 10, "name": "홍길동", "email": "hong@local.travel", "provider": "LOCAL", "mockToken": "local-token-10" }, "message": null }` | 로컬 회원가입 |
| 3 | auth | POST | `/api/auth/login` | `{ "loginId": "hong", "password": "1234" }` | `{ "success": true, "data": { "userId": 10, "name": "홍길동", "email": "hong@local.travel", "provider": "LOCAL", "mockToken": "local-token-10" }, "message": null }` | 로컬 로그인 |
| 4 | user | GET | `/api/users/{userId}` | 없음 | `{ "success": true, "data": { "id": 1, "name": "샘플 사용자", "email": "sample@travel-mvp.local", "phoneNumber": "010-0000-0000", "residence": "서울특별시 종로구", "authProvider": "GUEST", "notificationSettings": { "favoriteRegionPreopenAlert": true, "tripEndSettlementAlert": true }, "favoriteRegions": [] }, "message": null }` | 사용자 프로필 조회 |
| 5 | user | PUT | `/api/users/{userId}/notification-settings` | `{ "favoriteRegionPreopenAlert": true, "tripEndSettlementAlert": false }` | `{ "success": true, "data": { "favoriteRegionPreopenAlert": true, "tripEndSettlementAlert": false }, "message": null }` | 알림 설정 수정 |
| 6 | user | POST | `/api/users/{userId}/favorite-regions` | `{ "regionId": 1 }` | `{ "success": true, "data": [ { "id": 1, "name": "완도", "province": "전라남도", "refundConditionAmount": 200000, "mockBudgetRemaining": 11, "halfPriceApplyUrl": "...", "digitalTourCardApplyUrl": "...", "dataSourceNote": "SAMPLE_SEED", "statusCode": "APPLYING", "digitalBenefitAvailable": true, "displayOrder": 1, "mapTopPercent": 92, "mapLeftPercent": 55, "residenceRestrictionNote": "...", "matchedByResidence": true } ], "message": null }` | 관심 지역 추가 |
| 7 | user | DELETE | `/api/users/{userId}/favorite-regions/{regionId}` | 없음 | `{ "success": true, "data": [], "message": null }` | 관심 지역 삭제 |
| 8 | user | GET | `/api/users/{userId}/favorite-regions` | 없음 | `{ "success": true, "data": [ { "id": 1, "name": "완도", "...": "..." } ], "message": null }` | 관심 지역 목록 조회 |
| 9 | user | POST | `/api/users/{userId}/fcm-tokens` | `{ "fcmToken": "token-value", "platform": "android" }` | `{ "success": true, "data": null, "message": null }` | FCM 토큰 등록 |

### 1-2. 지역 / 관광지 / 가맹점

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 10 | region | GET | `/api/regions?residence=서울특별시 종로구` | 없음 | `{ "success": true, "data": [ { "id": 1, "name": "완도", "province": "전라남도", "refundConditionAmount": 200000, "mockBudgetRemaining": 11, "halfPriceApplyUrl": "...", "digitalTourCardApplyUrl": "...", "dataSourceNote": "SAMPLE_SEED", "statusCode": "APPLYING", "digitalBenefitAvailable": true, "displayOrder": 1, "mapTopPercent": 92, "mapLeftPercent": 55, "residenceRestrictionNote": "...", "matchedByResidence": true } ], "message": null }` | 지역 목록 조회 |
| 11 | region | GET | `/api/regions/{regionId}?residence=서울특별시 종로구&includeMerchants=true` | 없음 | `{ "success": true, "data": { "region": { "id": 1, "name": "완도", "...": "..." }, "halfPricePlaces": [ { "id": 1, "name": "완도타워", "address": "...", "description": "...", "latitude": 34.31, "longitude": 126.75, "eligibleForRefund": true } ], "digitalTourCardPlaces": [ { "id": 101, "name": "완도 로컬카페", "address": "...", "discountDescription": "...", "latitude": 34.31, "longitude": 126.75 } ], "merchants": [ { "id": 201, "name": "완도 특산품 상회", "address": "...", "category": "생활", "latitude": 34.31, "longitude": 126.75, "kakaoPlaceName": "", "kakaoPhoneNumber": "", "kakaoRoadAddress": "", "kakaoCategoryName": "", "kakaoPlaceUrl": "" } ], "onlineMalls": [ { "id": 301, "name": "완도 온라인몰", "mallUrl": "...", "description": "..." } ] }, "message": null }` | 지역 상세 조회 |
| 12 | region | GET | `/api/regions/{regionId}/place-info?residence=서울특별시 종로구` | 없음 | `{ "success": true, "data": { "region": { "id": 1, "name": "완도", "...": "..." }, "halfPricePlaces": [ { "id": 1, "name": "완도타워", "address": "...", "description": "...", "latitude": 34.31, "longitude": 126.75, "eligibleForRefund": true } ], "onlineMalls": [ { "id": 301, "name": "완도 온라인몰", "mallUrl": "...", "description": "..." } ] }, "message": null }` | 직접 코스용 관광지/온라인몰 조회 |
| 13 | merchant-map | GET | `/api/regions/{regionId}/merchant-map?southLat=34.30&northLat=34.32&westLng=126.74&eastLng=126.76` | 없음 | `{ "success": true, "data": { "region": { "id": 1, "name": "완도", "...": "..." }, "centerLatitude": 34.3119, "centerLongitude": 126.7551, "merchantCount": 32, "merchants": [ { "id": 946, "latitude": 34.311, "longitude": 126.754 } ] }, "message": null }` | 가맹점 마커 조회 |
| 14 | merchant-map | GET | `/api/regions/{regionId}/merchant-map/{merchantId}` | 없음 | `{ "success": true, "data": { "id": 946, "storeName": "우앤리 완도점", "roadAddress": "전남 완도군 완도읍 청해진남로39번길 9-1", "category": "미용", "latitude": 34.311, "longitude": 126.754, "kakaoPlaceName": "우앤리 완도점", "kakaoPhone": "010-5860-4450", "kakaoRoadAddress": "전남 완도군 완도읍 청해진남로39번길 9-1", "kakaoCategory": "가정,생활 > 미용 > 네일샵", "kakaoPlaceUrl": "https://place.map.kakao.com/...", "externalInfoAvailable": true }, "message": null }` | 가맹점 상세 조회 |

### 1-3. 여행 / 플래너

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 15 | trip | POST | `/api/trips` | `{ "userId": 1, "applicantName": "홍길동", "phoneNumber": "010-0000-0000", "residence": "서울특별시 종로구", "startDate": "2026-06-20", "endDate": "2026-06-22", "travelerCount": 4, "regionId": 1 }` | `{ "success": true, "data": { "id": 101, "regionId": 1, "regionName": "완도", "applicantName": "홍길동", "startDate": "2026-06-20", "endDate": "2026-06-22", "travelerCount": 4, "status": "PLANNING", "totalSpentAmount": 0, "refundConditionAmount": 200000, "settlementApplied": false }, "message": null }` | 여행 생성 |
| 16 | trip | GET | `/api/trips?userId=1` | 없음 | `{ "success": true, "data": [ { "id": 101, "regionId": 1, "regionName": "완도", "applicantName": "홍길동", "startDate": "2026-06-20", "endDate": "2026-06-22", "travelerCount": 4, "status": "PLANNING", "totalSpentAmount": 0, "refundConditionAmount": 200000, "settlementApplied": false } ], "message": null }` | 여행 목록 조회 |
| 17 | trip | GET | `/api/trips/{tripId}` | 없음 | `{ "success": true, "data": { "trip": { "id": 101, "...": "..." }, "selectedPlaces": [ { "id": 1, "placeType": "HALF_PRICE", "referencePlaceId": 1, "placeName": "완도타워", "address": "...", "visitOrder": 1, "latitude": 34.31, "longitude": 126.75, "checked": true } ], "uploadedFiles": [], "receipts": [], "lodgingInfo": null, "settlementSummary": { "totalSpentAmount": 0, "refundConditionAmount": 200000, "remainingAmount": 200000, "statusMessage": "정산 전" } }, "message": null }` | 여행 상세 조회 |
| 18 | trip | PUT | `/api/trips/{tripId}` | `{ "applicantName": "홍길동", "phoneNumber": "010-1111-1111", "residence": "서울특별시 종로구", "startDate": "2026-06-20", "endDate": "2026-06-23", "travelerCount": 4, "status": "TRAVELING" }` | `{ "success": true, "data": { "id": 101, "regionId": 1, "regionName": "완도", "applicantName": "홍길동", "startDate": "2026-06-20", "endDate": "2026-06-23", "travelerCount": 4, "status": "TRAVELING", "totalSpentAmount": 0, "refundConditionAmount": 200000, "settlementApplied": false }, "message": null }` | 여행 수정 |
| 19 | planner | POST | `/api/trips/{tripId}/places` | `{ "placeType": "HALF_PRICE", "referencePlaceId": 1, "placeName": "완도타워", "address": "전남 완도군 ...", "latitude": 34.3119, "longitude": 126.7551 }` | `{ "success": true, "data": [ { "id": 11, "placeType": "HALF_PRICE", "referencePlaceId": 1, "placeName": "완도타워", "address": "전남 완도군 ...", "visitOrder": 1, "latitude": 34.3119, "longitude": 126.7551, "checked": true } ], "message": null }` | 플래너 장소 1건 추가 |
| 20 | planner | PUT | `/api/trips/{tripId}/places` | `{ "places": [ { "placeType": "HALF_PRICE", "referencePlaceId": 1, "placeName": "완도타워", "address": "...", "latitude": 34.31, "longitude": 126.75 }, { "placeType": "MERCHANT", "referencePlaceId": 946, "placeName": "우앤리 완도점", "address": "...", "latitude": 34.311, "longitude": 126.754 } ] }` | `{ "success": true, "data": [ { "id": 11, "placeType": "HALF_PRICE", "referencePlaceId": 1, "placeName": "완도타워", "address": "...", "visitOrder": 1, "latitude": 34.31, "longitude": 126.75, "checked": true }, { "id": 12, "placeType": "MERCHANT", "referencePlaceId": 946, "placeName": "우앤리 완도점", "address": "...", "visitOrder": 2, "latitude": 34.311, "longitude": 126.754, "checked": true } ], "message": null }` | 플래너 전체 교체 |
| 21 | planner | POST | `/api/trips/{tripId}/places/reorder` | `{ "orderedTripPlaceIds": [12, 11] }` | `{ "success": true, "data": [ { "id": 12, "visitOrder": 1, "...": "..." }, { "id": 11, "visitOrder": 2, "...": "..." } ], "message": null }` | 플래너 순서 변경 |

### 1-4. 파일 업로드 / OCR / 숙박 / 정산

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 22 | file | POST | `/api/trips/{tripId}/uploaded-files?category=AUTH_PHOTO` | multipart `file` | `{ "success": true, "data": { "id": 501, "fileCategory": "AUTH_PHOTO", "originalFileName": "photo.jpg", "storagePath": "uploads/trips/101/photo.jpg", "fileSize": 123456, "mimeType": "image/jpeg", "createdAt": "2026-06-11T10:00:00" }, "message": null }` | 파일 업로드 |
| 23 | auth-photo | POST | `/api/trips/{tripId}/auth-photos/analyze/{uploadedFileId}` | 없음 | `{ "success": true, "data": { "approved": true, "detectedPeopleCount": 4, "requiredPeopleCount": 4, "facesClear": true, "backgroundVisible": true, "reason": "인원수와 배경 조건 충족" }, "message": null }` | 인증사진 AI 판정 |
| 24 | file | GET | `/api/trips/{tripId}/uploaded-files/{uploadedFileId}/binary` | 없음 | binary | 업로드 파일 다운로드 |
| 25 | file | DELETE | `/api/trips/{tripId}/uploaded-files/{uploadedFileId}` | 없음 | `{ "success": true, "data": null, "message": null }` | 업로드 파일 삭제 |
| 26 | receipt | POST | `/api/trips/{tripId}/receipts/analyze/{uploadedFileId}` | `{ "usageScope": "GENERAL" }` | `{ "success": true, "data": { "id": 701, "uploadedFileId": 601, "paymentType": "CREDIT_CARD", "usageScope": "GENERAL", "reviewStatus": "APPROVED", "amount": 42000, "paymentDateTime": "2026-05-06T19:24:00", "eligibleAmount": 42000, "reviewReason": "결제수단 및 금액 확인", "rawText": "..." }, "message": null }` | 영수증 분석 |
| 27 | lodging | POST | `/api/trips/{tripId}/lodging-info` | `{ "lodgingName": "완도호텔", "representativeName": "김대표", "phoneNumber": "061-000-0000", "address": "전남 완도군 ...", "signatureSvgPath": "<svg>...</svg>", "agreedPersonalInfo": true, "agreedStayProof": true, "uploadedFileId": 801 }` | `{ "success": true, "data": { "id": 901, "lodgingName": "완도호텔", "representativeName": "김대표", "phoneNumber": "061-000-0000", "address": "전남 완도군 ...", "signatureSvgPath": "<svg>...</svg>", "agreedPersonalInfo": true, "agreedStayProof": true, "uploadedFileId": 801 }, "message": null }` | 숙박 정보 저장 |
| 28 | lodging | POST | `/api/trips/{tripId}/lodging-info/extract/{uploadedFileId}` | 없음 | `{ "success": true, "data": { "id": 901, "lodgingName": "완도호텔", "representativeName": "김대표", "phoneNumber": "061-000-0000", "address": "전남 완도군 ...", "signatureSvgPath": "", "agreedPersonalInfo": false, "agreedStayProof": false, "uploadedFileId": 801 }, "message": null }` | 숙박확인서 OCR 추출 |
| 29 | settlement | GET | `/api/trips/{tripId}/settlement-summary` | 없음 | `{ "success": true, "data": { "totalSpentAmount": 120000, "refundConditionAmount": 200000, "remainingAmount": 80000, "statusMessage": "추가 결제 필요" }, "message": null }` | 정산 요약 조회 |
| 30 | settlement | POST | `/api/trips/{tripId}/settlement-apply` | 없음 | `{ "success": true, "data": { "tripId": 101, "status": "SETTLEMENT_READY", "settlementAppliedAt": "2026-06-11T15:00:00" }, "message": null }` | 정산 신청 |
| 31 | settlement | GET | `/api/trips/settlement-reminder-targets?date=2026-06-11` | 없음 | `{ "success": true, "data": [ { "id": 101, "regionId": 1, "regionName": "완도", "...": "..." } ], "message": null }` | 정산 리마인드 대상 조회 |

### 1-5. 숙박확인서 / PDF

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 32 | lodging-form | GET | `/api/integrations/lodging-form/{tripId}` | 없음 | `{ "success": true, "data": { "tripId": 101, "regionName": "횡성", "template": { "templateId": 12, "templateKey": "stay-confirm-hoengseong", "templateName": "stay_confirm_hoengseong.pdf", "sourceFormat": "PDF", "previewTitle": "숙박확인서", "previewSubtitle": "횡성 지역", "fields": [ { "key": "lodging_name", "label": "숙소명", "type": "text", "x": 120, "y": 200, "width": 180, "height": 24, "editable": true, "multiline": false, "helperText": "" } ], "notes": [] }, "instance": { "instanceId": 55, "status": "DRAFT", "payload": {}, "lastSavedAt": "2026-06-11T12:00:00", "renderedPdfFileName": "trip-101-lodging.pdf" }, "todos": [] }, "message": null }` | 숙박확인서 데이터 조회 |
| 33 | lodging-form | PUT | `/api/trips/{tripId}/lodging-form` | `{ "payload": { "lodging_name": "횡성호텔", "representative_name": "김대표" }, "status": "DRAFT" }` | `{ "success": true, "data": { "tripId": 101, "...": "..." }, "message": null }` | 숙박확인서 입력값 저장 |
| 34 | lodging-form | PUT | `/api/integrations/lodging-form/{tripId}/template-layout` | `{ "fields": [ { "key": "lodging_name", "label": "숙소명", "type": "text", "x": 120, "y": 200, "width": 180, "height": 24, "editable": true, "multiline": false, "helperText": "" } ] }` | `{ "success": true, "data": { "tripId": 101, "...": "..." }, "message": null }` | 템플릿 레이아웃 저장 |
| 35 | lodging-form | POST | `/api/integrations/lodging-form/{tripId}/analyze-template` | 없음 | `{ "success": true, "data": { "tripId": 101, "...": "..." }, "message": null }` | 템플릿 자동 분석 |
| 36 | lodging-form | GET | `/api/integrations/lodging-form/{tripId}/pdf` | 없음 | binary PDF | 작성 완료 숙박확인서 PDF 다운로드 |
| 37 | lodging-form | GET | `/api/integrations/lodging-form/{tripId}/template-pdf` | 없음 | binary PDF | 원본 템플릿 PDF 다운로드 |
| 38 | pdf | GET | `/api/integrations/pdf/merge/{tripId}?uploadedFileIds=501&uploadedFileIds=601` | 없음 | binary PDF | 여러 파일 병합 PDF 다운로드 |

### 1-6. 유튜브 코스 Job

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 39 | youtube-job | POST | `/api/youtube-course-jobs` | `{ "userId": 1, "tripId": 101, "regionId": 1, "youtubeUrl": "https://www.youtube.com/watch?v=..." }` | `{ "success": true, "data": { "jobId": "uuid-string", "status": "PENDING" }, "message": null }` | 유튜브 코스 Job 생성 |
| 40 | youtube-job | GET | `/api/youtube-course-jobs/{jobId}` | 없음 | `{ "success": true, "data": { "jobId": "uuid-string", "userId": 1, "tripId": 101, "regionId": 1, "regionName": "완도", "youtubeUrl": "https://www.youtube.com/watch?v=...", "status": "COMPLETED", "result": { "title": "완도 유튜브 추천 코스", "summary": "영상 기반 추천 코스", "stops": [ { "order": 1, "placeName": "완도타워", "address": "전남 완도군 ...", "latitude": 34.31, "longitude": 126.75, "category": "관광지", "source": "youtube_frame_or_transcript", "reason": "영상에서 주요 장소로 확인" } ] }, "errorMessage": null, "createdAt": "2026-06-11T14:00:00", "updatedAt": "2026-06-11T14:03:00" }, "message": null }` | 유튜브 Job 상태/결과 조회 |
| 41 | youtube-job | GET | `/api/youtube-course-jobs/active?userId=1&tripId=101` | 없음 | `{ "success": true, "data": { "jobId": "uuid-string", "status": "PROCESSING", "...": "..." }, "message": null }` | 진행 중 Job 조회 |
| 42 | youtube-job-callback | PATCH | `/api/youtube-course-jobs/{jobId}/processing` | 없음 | `{ "success": true, "data": { "jobId": "uuid-string", "status": "PROCESSING", "...": "..." }, "message": null }` | Worker 처리 시작 callback |
| 43 | youtube-job-callback | PATCH | `/api/youtube-course-jobs/{jobId}/complete` | `{ "resultJson": { "title": "완도 유튜브 추천 코스", "summary": "영상 기반 추천 코스", "stops": [ { "order": 1, "placeName": "완도타워", "address": "전남 완도군 ...", "latitude": 34.31, "longitude": 126.75, "category": "관광지", "source": "youtube_frame_or_transcript", "reason": "영상에서 주요 장소로 확인" } ] } }` | `{ "success": true, "data": { "jobId": "uuid-string", "status": "COMPLETED", "...": "..." }, "message": null }` | Worker 완료 callback |
| 44 | youtube-job-callback | PATCH | `/api/youtube-course-jobs/{jobId}/fail` | `{ "errorMessage": "yt-dlp failed" }` | `{ "success": true, "data": { "jobId": "uuid-string", "status": "FAILED", "errorMessage": "yt-dlp failed", "...": "..." }, "message": null }` | Worker 실패 callback |

### 1-7. FastAPI 내부 API

| Index | MVP | Method | URI | request body | response body | Description |
|---|---|---|---|---|---|---|
| 45 | fastapi-doc | POST | `/api/v1/documents/ocr/receipt` | multipart `file` | `{ "success": true, "data": { "payment_type": "CREDIT_CARD", "payment_datetime": "2026-05-06 19:24", "raw_text": "...", "candidates": ["신용카드", "국민카드"] }, "message": null }` | 영수증 OCR |
| 46 | fastapi-doc | POST | `/api/v1/documents/ocr/receipt-amount` | multipart `file` | `{ "success": true, "data": { "amount": 42000, "currency": "KRW", "payment_datetime": "2026-05-06 19:24", "raw_text": "..." }, "message": null }` | 영수증 금액 추출 |
| 47 | fastapi-doc | POST | `/api/v1/documents/ocr/lodging` | multipart `file` | `{ "success": true, "data": { "lodging_name": "완도호텔", "representative_name": "김대표", "phone_number": "061-000-0000", "address": "전남 완도군 ...", "warnings": [] }, "message": null }` | 숙박확인서 OCR |
| 48 | fastapi-doc | POST | `/api/v1/documents/photos/auth-review` | multipart `file`, form `required_people_count=4` | `{ "success": true, "data": { "approved": true, "detected_people_count": 4, "required_people_count": 4, "faces_clear": true, "background_visible": true, "reason": "조건 충족" }, "message": null }` | 인증사진 판별 |
| 49 | fastapi-doc | POST | `/api/v1/documents/pdf/merge` | multipart `files[]` | binary PDF | PDF 병합 |
| 50 | fastapi-doc | POST | `/api/v1/documents/pdf/lodging-form` | lodging form render JSON | binary PDF | 숙박확인서 PDF 렌더 |
| 51 | fastapi-doc | POST | `/api/v1/documents/templates/analyze` | template analyze JSON | `{ "success": true, "data": { "fields": [ { "key": "lodging_name", "label": "숙소명", "type": "text", "x": 120, "y": 200, "width": 180, "height": 24, "editable": true, "multiline": false, "helper_text": "" } ], "warnings": [], "used_ai": true }, "message": null }` | 템플릿 분석 |
| 52 | fastapi-video | POST | `/api/v1/videos/youtube/analyze` | `{ "url": "https://www.youtube.com/watch?v=...", "region_name": "완도", "themes": ["맛집", "바다"] }` | `{ "success": true, "data": { "video_id": "abc123", "title": "완도 브이로그", "summary": "영상 기반 추천 코스", "keywords": ["완도", "맛집"], "transcript_place_names": ["완도타워"], "frame_only_place_names": ["청해진"], "suggested_place_names": ["청해진"], "transcript_excerpt": "...", "used_transcript": true, "used_thumbnail_ocr": true, "used_frame_ocr": true, "frame_count": 12, "warnings": [] }, "message": null }` | direct 유튜브 분석 |

## 2. DB 명세서

### 2-1. 사용자 계열

| Index | Table | Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|---|---|
| 1 | `users` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 사용자 ID |
| 2 | `users` | `name` | VARCHAR(120) | N |  |  | 이름 |
| 3 | `users` | `login_id` | VARCHAR(80) | Y | UK |  | 로컬 로그인 ID |
| 4 | `users` | `email` | VARCHAR(160) | N | UK |  | 이메일 |
| 5 | `users` | `password_hash` | VARCHAR(255) | Y |  |  | 비밀번호 해시 |
| 6 | `users` | `phone_number` | VARCHAR(40) | Y |  |  | 연락처 |
| 7 | `users` | `residence` | VARCHAR(120) | Y |  |  | 거주지 |
| 8 | `users` | `auth_provider` | VARCHAR(30) | N |  |  | 인증 제공자 |
| 9 | `users` | `oauth_subject` | VARCHAR(120) | Y |  |  | OAuth subject |
| 10 | `users` | `created_at` | DATETIME | N |  |  | 생성일 |
| 11 | `users` | `updated_at` | DATETIME | N |  |  | 수정일 |
| 12 | `user_notification_settings` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 13 | `user_notification_settings` | `user_id` | BIGINT | N | FK, UK |  | 사용자 1:1 |
| 14 | `user_notification_settings` | `favorite_region_preopen_alert` | BIT | N |  |  | 관심지역 알림 |
| 15 | `user_notification_settings` | `trip_end_settlement_alert` | BIT | N |  |  | 정산 알림 |
| 16 | `user_notification_settings` | `created_at` | DATETIME | N |  |  | 생성일 |
| 17 | `user_notification_settings` | `updated_at` | DATETIME | N |  |  | 수정일 |
| 18 | `user_favorite_regions` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 19 | `user_favorite_regions` | `user_id` | BIGINT | N | FK |  | 사용자 |
| 20 | `user_favorite_regions` | `region_id` | BIGINT | N | FK |  | 지역 |
| 21 | `user_favorite_regions` | `created_at` | DATETIME | N |  |  | 생성일 |
| 22 | `user_favorite_regions` | `updated_at` | DATETIME | N |  |  | 수정일 |
| 23 | `user_fcm_tokens` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 24 | `user_fcm_tokens` | `user_id` | BIGINT | N | FK |  | 사용자 |
| 25 | `user_fcm_tokens` | `fcm_token` | VARCHAR(512) | N |  |  | FCM token |
| 26 | `user_fcm_tokens` | `platform` | VARCHAR(40) | N |  | `'unknown'` | 플랫폼 |
| 27 | `user_fcm_tokens` | `created_at` | DATETIME | N |  |  | 생성일 |
| 28 | `user_fcm_tokens` | `updated_at` | DATETIME | N |  |  | 수정일 |

### 2-2. 지역 / 장소 계열

| Index | Table | Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|---|---|
| 29 | `regions` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 지역 ID |
| 30 | `regions` | `name` | VARCHAR(100) | N |  |  | 지역명 |
| 31 | `regions` | `province` | VARCHAR(100) | N |  |  | 시도 |
| 32 | `regions` | `half_price_apply_url` | VARCHAR(255) | N |  |  | 여행 신청 URL |
| 33 | `regions` | `digital_tour_card_apply_url` | VARCHAR(255) | N |  |  | 디지털/정산 URL |
| 34 | `regions` | `refund_condition_amount` | INT | N |  |  | 환급 기준 금액 |
| 35 | `regions` | `mock_budget_remaining` | INT | N |  |  | 샘플 잔여 수량 |
| 36 | `regions` | `data_source_note` | VARCHAR(30) | N |  |  | 데이터 출처 메모 |
| 37 | `regions` | `status_code` | VARCHAR(30) | N |  | `'PREPARING'` | 지역 상태 |
| 38 | `regions` | `digital_benefit_available` | BIT | N |  | `0` | 디지털 혜택 사용 여부 |
| 39 | `regions` | `display_order` | INT | N |  | `0` | 정렬 순서 |
| 40 | `regions` | `restricted_residence_tokens` | VARCHAR(500) | Y |  |  | 제외 거주지 토큰 |
| 41 | `regions` | `residence_restriction_note` | VARCHAR(255) | Y |  |  | 거주지 제한 설명 |
| 42 | `regions` | `map_top_percent` | DOUBLE | Y |  |  | 화면상 지역 위치 |
| 43 | `regions` | `map_left_percent` | DOUBLE | Y |  |  | 화면상 지역 위치 |
| 44 | `regions` | `map_center_lat` | DOUBLE | Y |  |  | 지도 중심 위도 |
| 45 | `regions` | `map_center_lng` | DOUBLE | Y |  |  | 지도 중심 경도 |
| 46 | `places` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 관광지 ID |
| 47 | `places` | `region_id` | BIGINT | N | FK |  | 지역 |
| 48 | `places` | `name` | VARCHAR(150) | N |  |  | 관광지명 |
| 49 | `places` | `address` | VARCHAR(255) | N |  |  | 주소 |
| 50 | `places` | `description` | VARCHAR(500) | Y |  |  | 설명 |
| 51 | `places` | `latitude` | DOUBLE | Y |  |  | 위도 |
| 52 | `places` | `longitude` | DOUBLE | Y |  |  | 경도 |
| 53 | `places` | `eligible_for_refund` | BIT | Y |  |  | 환급 인정 여부 |
| 54 | `digital_tour_card_places` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 55 | `digital_tour_card_places` | `region_id` | BIGINT | N | FK |  | 지역 |
| 56 | `digital_tour_card_places` | `name` | VARCHAR(150) | N |  |  | 장소명 |
| 57 | `digital_tour_card_places` | `address` | VARCHAR(255) | N |  |  | 주소 |
| 58 | `digital_tour_card_places` | `discount_description` | VARCHAR(500) | Y |  |  | 혜택 설명 |
| 59 | `digital_tour_card_places` | `latitude` | DOUBLE | Y |  |  | 위도 |
| 60 | `digital_tour_card_places` | `longitude` | DOUBLE | Y |  |  | 경도 |
| 61 | `merchants` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 가맹점 ID |
| 62 | `merchants` | `region_id` | BIGINT | N | FK |  | 지역 |
| 63 | `merchants` | `name` | VARCHAR(150) | N |  |  | 가맹점명 |
| 64 | `merchants` | `address` | VARCHAR(255) | N |  |  | 주소 |
| 65 | `merchants` | `category` | VARCHAR(100) | Y |  |  | 업종 |
| 66 | `merchants` | `latitude` | DOUBLE | Y |  |  | 위도 |
| 67 | `merchants` | `longitude` | DOUBLE | Y |  |  | 경도 |
| 68 | `merchants` | `kakao_place_name` | VARCHAR(150) | Y |  |  | Kakao 장소명 |
| 69 | `merchants` | `kakao_phone_number` | VARCHAR(120) | Y |  |  | 전화번호 |
| 70 | `merchants` | `kakao_road_address` | VARCHAR(255) | Y |  |  | 도로명 주소 |
| 71 | `merchants` | `kakao_category_name` | VARCHAR(150) | Y |  |  | Kakao 카테고리 |
| 72 | `merchants` | `kakao_place_url` | VARCHAR(255) | Y |  |  | Kakao 상세 링크 |
| 73 | `online_malls` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 74 | `online_malls` | `region_id` | BIGINT | N | FK |  | 지역 |
| 75 | `online_malls` | `name` | VARCHAR(150) | N |  |  | 이름 |
| 76 | `online_malls` | `mall_url` | VARCHAR(255) | N |  |  | 링크 |
| 77 | `online_malls` | `description` | VARCHAR(255) | Y |  |  | 설명 |

### 2-3. 여행 / 플래너 / 파일 / 정산

| Index | Table | Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|---|---|
| 78 | `trips` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 여행 ID |
| 79 | `trips` | `user_id` | BIGINT | N | FK |  | 사용자 |
| 80 | `trips` | `region_id` | BIGINT | N | FK |  | 지역 |
| 81 | `trips` | `applicant_name` | VARCHAR(100) | N |  |  | 신청자명 |
| 82 | `trips` | `phone_number` | VARCHAR(40) | N |  |  | 연락처 |
| 83 | `trips` | `residence` | VARCHAR(120) | N |  |  | 거주지 |
| 84 | `trips` | `start_date` | DATE | N |  |  | 시작일 |
| 85 | `trips` | `end_date` | DATE | N |  |  | 종료일 |
| 86 | `trips` | `traveler_count` | INT | N |  | `2` | 인원수 |
| 87 | `trips` | `status` | VARCHAR(40) | N |  |  | 여행 상태 |
| 88 | `trips` | `refund_condition_amount` | INT | N |  |  | 환급 기준 금액 |
| 89 | `trips` | `total_spent_amount` | INT | N |  | `0` | 누적 지출 |
| 90 | `trips` | `settlement_applied` | BIT | N |  | `0` | 정산 신청 여부 |
| 91 | `trips` | `settlement_applied_at` | DATETIME | Y |  |  | 정산 신청 시각 |
| 92 | `trip_places` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 93 | `trip_places` | `trip_id` | BIGINT | N | FK |  | 여행 |
| 94 | `trip_places` | `place_type` | VARCHAR(40) | N |  |  | 장소 타입 |
| 95 | `trip_places` | `reference_place_id` | BIGINT | N |  |  | 원본 장소 ID |
| 96 | `trip_places` | `place_name` | VARCHAR(150) | N |  |  | 표시 이름 |
| 97 | `trip_places` | `address` | VARCHAR(255) | N |  |  | 주소 |
| 98 | `trip_places` | `visit_order` | INT | N |  |  | 방문 순서 |
| 99 | `trip_places` | `latitude` | DOUBLE | Y |  |  | 위도 |
| 100 | `trip_places` | `longitude` | DOUBLE | Y |  |  | 경도 |
| 101 | `trip_places` | `checked` | BIT | Y |  |  | 체크 여부 |
| 102 | `uploaded_files` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 파일 ID |
| 103 | `uploaded_files` | `trip_id` | BIGINT | N | FK |  | 여행 |
| 104 | `uploaded_files` | `file_category` | VARCHAR(40) | N |  |  | 파일 유형 |
| 105 | `uploaded_files` | `original_file_name` | VARCHAR(255) | N |  |  | 원본 파일명 |
| 106 | `uploaded_files` | `storage_path` | VARCHAR(255) | N |  |  | 저장 경로 |
| 107 | `uploaded_files` | `file_size` | BIGINT | N |  |  | 파일 크기 |
| 108 | `uploaded_files` | `mime_type` | VARCHAR(120) | N |  |  | MIME |
| 109 | `receipts` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 110 | `receipts` | `uploaded_file_id` | BIGINT | N | FK, UK |  | 업로드 파일 |
| 111 | `receipts` | `payment_type` | VARCHAR(40) | N |  |  | 결제 수단 |
| 112 | `receipts` | `usage_scope` | VARCHAR(30) | N |  | `'GENERAL'` | 사용 범위 |
| 113 | `receipts` | `review_status` | VARCHAR(30) | N |  | `'PENDING'` | 검토 상태 |
| 114 | `receipts` | `amount` | INT | Y |  |  | 결제 금액 |
| 115 | `receipts` | `payment_date_time` | DATETIME | Y |  |  | 결제 일시 |
| 116 | `receipts` | `eligible_amount` | INT | N |  | `0` | 인정 금액 |
| 117 | `receipts` | `review_reason` | VARCHAR(255) | Y |  |  | 판정 사유 |
| 118 | `receipts` | `raw_text` | VARCHAR(500) | Y |  |  | OCR 원문 |
| 119 | `lodging_infos` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 120 | `lodging_infos` | `trip_id` | BIGINT | N | FK |  | 여행 |
| 121 | `lodging_infos` | `uploaded_file_id` | BIGINT | Y | FK |  | 숙박 증빙 파일 |
| 122 | `lodging_infos` | `lodging_name` | VARCHAR(150) | Y |  |  | 숙소명 |
| 123 | `lodging_infos` | `representative_name` | VARCHAR(100) | Y |  |  | 대표자명 |
| 124 | `lodging_infos` | `phone_number` | VARCHAR(40) | Y |  |  | 전화번호 |
| 125 | `lodging_infos` | `address` | VARCHAR(255) | Y |  |  | 주소 |
| 126 | `lodging_infos` | `signature_svg_path` | TEXT | Y |  |  | 서명 SVG/경로 |
| 127 | `lodging_infos` | `agreed_personal_info` | BIT | N |  |  | 개인정보 동의 |
| 128 | `lodging_infos` | `agreed_stay_proof` | BIT | N |  |  | 숙박 증빙 동의 |

### 2-4. 숙박확인서 / 유튜브 Job

| Index | Table | Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|---|---|
| 129 | `lodging_form_templates` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 130 | `lodging_form_templates` | `region_id` | BIGINT | N | FK, UK |  | 지역별 템플릿 |
| 131 | `lodging_form_templates` | `template_key` | VARCHAR(80) | N | UK |  | 템플릿 키 |
| 132 | `lodging_form_templates` | `template_name` | VARCHAR(150) | N |  |  | 템플릿명 |
| 133 | `lodging_form_templates` | `source_format` | VARCHAR(40) | N |  |  | 원본 포맷 |
| 134 | `lodging_form_templates` | `source_file_path` | VARCHAR(255) | Y |  |  | 원본 경로 |
| 135 | `lodging_form_templates` | `render_asset_path` | VARCHAR(255) | Y |  |  | 렌더 asset 경로 |
| 136 | `lodging_form_templates` | `preview_title` | VARCHAR(120) | N |  |  | 미리보기 제목 |
| 137 | `lodging_form_templates` | `preview_subtitle` | VARCHAR(255) | Y |  |  | 미리보기 부제 |
| 138 | `lodging_form_templates` | `template_schema_json` | LONGTEXT | N |  |  | 필드 schema |
| 139 | `lodging_form_templates` | `data_source_note` | VARCHAR(40) | N |  |  | 출처 메모 |
| 140 | `lodging_form_templates` | `is_active` | BIT | N |  | `1` | 활성 여부 |
| 141 | `lodging_form_instances` | `id` | BIGINT | N | PK | AUTO_INCREMENT | ID |
| 142 | `lodging_form_instances` | `trip_id` | BIGINT | N | FK, UK |  | 여행별 1개 |
| 143 | `lodging_form_instances` | `template_id` | BIGINT | N | FK |  | 템플릿 |
| 144 | `lodging_form_instances` | `template_snapshot_json` | LONGTEXT | N |  |  | 저장 시점 schema |
| 145 | `lodging_form_instances` | `payload_json` | LONGTEXT | N |  |  | 사용자 입력 payload |
| 146 | `lodging_form_instances` | `status` | VARCHAR(40) | N |  | `'DRAFT'` | 작성 상태 |
| 147 | `lodging_form_instances` | `rendered_pdf_file_name` | VARCHAR(255) | Y |  |  | 렌더링 파일명 |
| 148 | `lodging_form_instances` | `last_rendered_at` | DATETIME | Y |  |  | 마지막 렌더 시각 |
| 149 | `youtube_course_jobs` | `id` | BIGINT | N | PK | AUTO_INCREMENT | 내부 ID |
| 150 | `youtube_course_jobs` | `job_id` | VARCHAR(64) | N | UK |  | 외부 노출 jobId |
| 151 | `youtube_course_jobs` | `user_id` | BIGINT | N | FK |  | 요청 사용자 |
| 152 | `youtube_course_jobs` | `region_id` | BIGINT | N | FK |  | 대상 지역 |
| 153 | `youtube_course_jobs` | `trip_id` | BIGINT | Y | FK |  | 연결 여행 |
| 154 | `youtube_course_jobs` | `youtube_url` | VARCHAR(1000) | N |  |  | 원본 URL |
| 155 | `youtube_course_jobs` | `status` | VARCHAR(30) | N |  |  | PENDING/PROCESSING/COMPLETED/FAILED |
| 156 | `youtube_course_jobs` | `result_json` | LONGTEXT | Y |  |  | 결과 JSON |
| 157 | `youtube_course_jobs` | `error_message` | TEXT | Y |  |  | 에러 메시지 |
| 158 | `youtube_course_jobs` | `created_at` | DATETIME | N |  |  | 생성일 |
| 159 | `youtube_course_jobs` | `updated_at` | DATETIME | N |  |  | 수정일 |

## 3. ERD

```mermaid
erDiagram
    users ||--|| user_notification_settings : has
    users ||--o{ user_favorite_regions : favorites
    regions ||--o{ user_favorite_regions : referenced_by

    users ||--o{ user_fcm_tokens : owns
    users ||--o{ trips : owns
    regions ||--o{ trips : has

    regions ||--o{ places : designated_places
    regions ||--o{ digital_tour_card_places : digital_places
    regions ||--o{ merchants : merchants
    regions ||--o{ online_malls : malls

    trips ||--o{ trip_places : planner_places
    trips ||--o{ uploaded_files : uploads
    uploaded_files ||--|| receipts : receipt
    trips ||--o{ lodging_infos : lodging_info

    regions ||--|| lodging_form_templates : template
    trips ||--|| lodging_form_instances : form_instance
    lodging_form_templates ||--o{ lodging_form_instances : based_on

    users ||--o{ youtube_course_jobs : requests
    trips ||--o{ youtube_course_jobs : linked
    regions ||--o{ youtube_course_jobs : target_region
```

## 4. 환경변수

### 4-1. Spring Boot

| Index | Service | Variable | Example | Required | Description |
|---|---|---|---|---|---|
| 1 | spring | `SPRING_DATASOURCE_URL` | `jdbc:mysql://localhost:3306/travel_mvp?serverTimezone=Asia/Seoul` | Y | DB URL |
| 2 | spring | `SPRING_DATASOURCE_USERNAME` | `travel_user` | Y | DB 계정 |
| 3 | spring | `SPRING_DATASOURCE_PASSWORD` | `travel_password` | Y | DB 비밀번호 |
| 4 | spring | `SPRING_DATA_REDIS_HOST` | `casual-moose-138255.upstash.io` | 캐시/stream 사용 시 Y | Redis host |
| 5 | spring | `SPRING_DATA_REDIS_PORT` | `6379` | 캐시/stream 사용 시 Y | Redis port |
| 6 | spring | `SPRING_DATA_REDIS_USERNAME` | `default` | 캐시/stream 사용 시 Y | Redis username |
| 7 | spring | `SPRING_DATA_REDIS_PASSWORD` | `******` | 캐시/stream 사용 시 Y | Redis password |
| 8 | spring | `SPRING_DATA_REDIS_SSL_ENABLED` | `true` | 캐시/stream 사용 시 Y | Redis SSL 사용 여부 |
| 9 | spring | `FASTAPI_BASE_URL` | `https://halftrip-fastapi.onrender.com` | Y | FastAPI base URL |
| 10 | spring | `APP_KAKAO_REST_API_KEY` | `b6c3...` | Kakao API 사용 시 Y | Kakao REST API key |
| 11 | spring | `APP_KAKAO_TIMEOUT_SECONDS` | `4` | N | Kakao timeout |
| 12 | spring | `APP_FCM_SERVICE_ACCOUNT_PATH` | `/secrets/firebase-admin.json` | FCM 사용 시 Y 또는 JSON 대체 | Firebase 서비스 계정 파일 경로 |
| 13 | spring | `APP_FCM_SERVICE_ACCOUNT_JSON` | `{...}` | FCM 사용 시 Y 또는 PATH 대체 | Firebase 서비스 계정 JSON |
| 14 | spring | `APP_FIREBASE_PROJECT_ID` | `halftrip-f4335` | FCM 사용 시 Y | Firebase project id |
| 15 | spring | `APP_STORAGE_ROOT` | `./uploads` | N | 업로드 저장 경로 |
| 16 | spring | `APP_ALLOWED_ORIGINS` | `*` | N | CORS 허용 origin |

### 4-2. FastAPI

| Index | Service | Variable | Example | Required | Description |
|---|---|---|---|---|---|
| 17 | fastapi | `APP_ENV` | `local` | N | 실행 환경 |
| 18 | fastapi | `TEMP_UPLOAD_DIR` | `./tmp` | Y | 임시 파일 저장 경로 |
| 19 | fastapi | `COMMON_LODGING_TEMPLATE_PATH` | `./templates/common_lodging_form.pdf` | N | 공통 숙박 템플릿 경로 |
| 20 | fastapi | `OPEN_AI_KEY` | `sk-...` | 유튜브 AI 분석 시 Y | OpenAI API key |
| 21 | fastapi | `OPEN_AI_MODEL` | `gpt-4.1-mini` | N | OpenAI model |
| 22 | fastapi | `YOUTUBE_API_KEY` | `AIza...` | 유튜브 메타데이터 보강 시 Y | YouTube API key |
| 23 | fastapi | `KAKAO_REST_API_KEY` | `b6c3...` | 장소 정규화 시 Y | Kakao REST key |
| 24 | fastapi | `APP_ALLOWED_ORIGINS` | `*` | N | CORS origin |
| 25 | fastapi | `REDIS_URL` | `rediss://default:***@casual-moose-138255.upstash.io:6379` | Worker 사용 시 Y | Redis URL |
| 26 | fastapi | `SPRING_API_BASE_URL` | `https://halftrip-springboot.onrender.com/api` | Worker 사용 시 Y | Spring callback base URL |
| 27 | fastapi | `YOUTUBE_COURSE_STREAM_NAME` | `youtube-course-jobs` | N | Stream 이름 |
| 28 | fastapi | `YOUTUBE_COURSE_CONSUMER_GROUP` | `youtube-course-worker` | N | Consumer group |
| 29 | fastapi | `YOUTUBE_COURSE_CONSUMER_NAME` | `fastapi-worker-1` | N | Consumer 이름 |

### 4-3. Flutter

| Index | Service | Variable | Example | Required | Description |
|---|---|---|---|---|---|
| 30 | flutter | `API_BASE_URL` | `https://halftrip-springboot.onrender.com/api` | Y | Spring API base URL |
| 31 | flutter | `FASTAPI_BASE_URL` | `https://halftrip-fastapi.onrender.com` | 현재 direct FastAPI 호출이 남아있다면 Y | FastAPI base URL |
| 32 | flutter | `USE_MOCK_LOGIN` | `true` | N | mock 로그인 사용 여부 |
| 33 | flutter | `USE_MOCK_API` | `false` | N | mock repository 사용 여부 |
| 34 | flutter | `MAP_PROVIDER` | `kakao` | Kakao 지도 사용 시 Y | 지도 provider |
| 35 | flutter | `KAKAO_MAP_APP_KEY` | `0a04bcf1d503e4d308af70020fa0819f` | Kakao 지도 사용 시 Y | Kakao JavaScript key |

## 5. 참고

- 모든 Spring/FastAPI 응답은 공통적으로 `success`, `data`, `message` 래퍼를 사용합니다.
- `trip_places.reference_place_id`는 강한 FK가 아니라 원본 장소 참조용 숫자입니다.
- `youtube_course_jobs.result_json`은 화면 표시용 임시 코스 결과입니다.
- 실제 인증/인가 필터는 코드상 별도 확인이 필요합니다.
