# API Specification Draft

## Spring Boot API (`/api`)

### Auth

- `POST /auth/mock-login`
  - request: `{ "provider": "kakao|google|guest", "email": "...", "name": "..." }`
  - response: user profile + mock token

### Users

- `GET /users/{id}`
- `PUT /users/{id}/notification-settings`
- `POST /users/{id}/favorite-regions`
- `GET /users/{id}/favorite-regions`

### Regions / Places / Merchants

- `GET /regions?residence=전라남도`
- `GET /regions/{regionId}/places?type=HALF_PRICE`
- `GET /regions/{regionId}/digital-tour-card-places`
- `GET /regions/{regionId}/merchants`
- `GET /regions/{regionId}/online-malls`

### Trips

- `POST /trips`
- `GET /trips?userId=1`
- `GET /trips/{tripId}`
- `PUT /trips/{tripId}`
- `PUT /trips/{tripId}/places`
- `POST /trips/{tripId}/places/reorder`
- `POST /trips/{tripId}/uploaded-files`
- `POST /trips/{tripId}/receipts`
- `POST /trips/{tripId}/lodging-info`
- `GET /trips/{tripId}/settlement-summary`
- `GET /trips/settlement-reminder-targets?date=2026-04-24`

### FastAPI Proxy / Integration

- `GET /integrations/pdf/merge/{tripId}?uploadedFileIds=1&uploadedFileIds=2`
- `GET /integrations/lodging-form/{tripId}`

## FastAPI (`/api/v1`)

### Document AI

- `POST /documents/ocr/receipt`
  - multipart image/file
  - returns payment type classification and raw text candidates
- `POST /documents/ocr/receipt-amount`
  - multipart image/file
  - returns amount and normalized currency payload
- `POST /documents/ocr/lodging`
  - multipart image/file
  - returns lodging info candidates
- `POST /documents/pdf/merge`
  - multipart files[] or JSON file URLs
  - returns merged PDF bytes
- `POST /documents/lodging-form-data`
  - request: trip info + lodging info + signer info
  - returns PDF render JSON

## Response Convention

```json
{
  "success": true,
  "data": {},
  "message": "optional"
}
```

에러 응답도 같은 envelope를 사용합니다.
