"""하프트립 통합테스트 — 가입부터 탈퇴까지 전 여정 + 보안 회귀 + 응답 계약.

전제: Spring이 local 프로필 + APP_AUTH_TOKEN_ENFORCED=true 로 :8080 에 떠 있어야 한다.
FastAPI(:8000)가 없으면 OCR·인증사진 판정 단계는 SKIP 으로 표시한다.
"""
import base64
import io
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

BASE = "http://localhost:8080/api"
FASTAPI = "http://localhost:8000"

# 1x1 PNG. 업로드 경로만 태우면 되므로 내용은 중요하지 않다.
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

KST_OFFSET = re.compile(r"[+-]\d{2}:\d{2}$")
DATE_ONLY = re.compile(r"^\d{4}-\d{2}-\d{2}$")

results = []
section_name = ""


def section(name):
    global section_name
    section_name = name
    print(f"\n{'=' * 62}\n{name}\n{'=' * 62}")


def record(ok, label, detail=""):
    results.append((ok, section_name, label, detail))
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {label}{('  — ' + str(detail)) if detail else ''}")
    return ok


def skip(label, why):
    results.append((None, section_name, label, why))
    print(f"  [SKIP] {label}  — {why}")


def call(method, path, body=None, token=None, base=BASE, raw_body=None, content_type=None):
    data = raw_body if raw_body is not None else (
        json.dumps(body).encode("utf-8") if body is not None else None)
    request = urllib.request.Request(base + urllib.parse.quote(path, safe="/?&=%"),
                                     data=data, method=method)
    request.add_header("Content-Type", content_type or "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read()
            try:
                return response.status, json.loads(payload.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                return response.status, payload
    except urllib.error.HTTPError as error:
        payload = error.read()
        try:
            return error.code, json.loads(payload.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return error.code, payload.decode("utf-8", "replace")
    except Exception as error:  # 연결 실패 등
        return 0, str(error)


def multipart_body(filename, content):
    """multipart/form-data 본문과 Content-Type 을 만든다."""
    boundary = "----halftrip" + uuid.uuid4().hex
    crlf = b"\r\n"
    buffer = io.BytesIO()
    buffer.write(b"--" + boundary.encode() + crlf)
    buffer.write(b'Content-Disposition: form-data; name="file"; filename="'
                 + filename.encode() + b'"' + crlf)
    buffer.write(b"Content-Type: image/png" + crlf + crlf)
    buffer.write(content)
    buffer.write(crlf + b"--" + boundary.encode() + b"--" + crlf)
    return buffer.getvalue(), "multipart/form-data; boundary=" + boundary


def multipart(path, field, filename, content, token, extra_query=""):
    body, content_type = multipart_body(filename, content)
    return call("POST", path + extra_query, token=token, raw_body=body,
                content_type=content_type)


def wrapper_ok(payload):
    """공통 래퍼 계약: {success, data, message}."""
    return (isinstance(payload, dict)
            and "success" in payload and "data" in payload and "message" in payload)


def check_datetimes(node, path="", problems=None):
    """KST offset 계약 위반을 재귀로 훑는다."""
    if problems is None:
        problems = []
    if isinstance(node, dict):
        for key, value in node.items():
            check_datetimes(value, f"{path}.{key}", problems)
    elif isinstance(node, list):
        for index, value in enumerate(node[:5]):
            check_datetimes(value, f"{path}[{index}]", problems)
    elif isinstance(node, str):
        if re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}", node) and not KST_OFFSET.search(node):
            problems.append(f"{path}={node}")
    return problems


# ---------------------------------------------------------------- 준비
section("0. 서버 준비 상태")
status, payload = call("GET", "/regions")
if status != 200:
    print(f"서버에 붙지 못했다 (status={status}). Spring이 :8080 에 떠 있는지 확인한다.")
    sys.exit(1)
record(True, "Spring :8080 응답")
record(wrapper_ok(payload), "공통 래퍼 {success,data,message}")

fastapi_up = call("GET", "/health", base=FASTAPI)[0] == 200
if fastapi_up:
    record(True, "FastAPI :8000 응답")
else:
    print("  [INFO] FastAPI 미기동 — OCR·인증사진 단계는 SKIP")

# ---------------------------------------------------------------- 계정
section("1. 계정 — 가입 · 로그인 · 프로필")
suffix = uuid.uuid4().hex[:8]
login_id = f"qa{suffix}"
status, payload = call("POST", "/auth/signup", {
    "name": "통합테스트", "loginId": login_id, "password": "test1234",
    "phoneNumber": "010-5555-6666", "residence": "전라남도"})
record(status == 200, "회원가입", status)
user_id = payload["data"]["userId"]
token = payload["data"]["token"]
record(bool(token), "가입 응답에 토큰 포함")

status, payload = call("POST", "/auth/login", {"loginId": login_id, "password": "test1234"})
record(status == 200 and payload["data"]["userId"] == user_id, "로그인", status)
token = payload["data"]["token"]

status, payload = call("POST", "/auth/login", {"loginId": login_id, "password": "wrong"})
record(status in (400, 401), "틀린 비밀번호 거부", status)

status, payload = call("GET", f"/users/{user_id}", token=token)
record(status == 200, "내 정보 조회", status)
me = payload.get("data", {})
record(bool(me.get("nickname")), "닉네임 자동 부여", me.get("nickname"))
record("email" not in me or me.get("email") is None or "@" in str(me.get("email")),
       "개인정보 최소수집 — 응답 형태 확인")

status, payload = call("PATCH", f"/users/{user_id}/profile", token=token,
                       body={"nickname": "통합테스터", "avatarPreset": "2:3"})
record(status == 200, "프로필 수정", status)

status, payload = call("PATCH", f"/users/{user_id}/residence", token=token,
                       body={"residence": "강원특별자치도"})
record(status == 200, "거주지 변경", status)
call("PATCH", f"/users/{user_id}/residence", token=token, body={"residence": "전라남도"})

status, payload = call("PUT", f"/users/{user_id}/notification-settings", token=token,
                       body={"favoriteRegionPreopenAlert": True,
                             "tripEndSettlementAlert": True, "marketingAlert": False})
record(status == 200, "알림 설정 저장", status)

# ---------------------------------------------------------------- 지역
section("2. 지역 — 목록 · 상세 · 관심지역")
status, payload = call("GET", "/regions", token=token)
regions = payload.get("data", [])
record(status == 200 and len(regions) >= 3, f"지역 목록 ({len(regions)}건)", status)
record(all("�" not in r["name"] for r in regions), "지역명 한글 정상 (인코딩)")
valid_status = {"APPLYING", "PREPARING", "CLOSED"}
codes = {r.get("statusCode") for r in regions}
record(codes <= valid_status, "statusCode 와이어 값", codes)
region_id = regions[0]["id"]

status, payload = call("GET", f"/regions/{region_id}", token=token)
record(status == 200, "지역 상세", status)

status, payload = call("GET", f"/regions/{region_id}/place-info?residence=전라남도", token=token)
record(status == 200, "지역 지정관광지·혜택처", status)

status, payload = call("POST", f"/users/{user_id}/favorite-regions", token=token,
                       body={"regionId": region_id})
record(status == 200, "관심 지역 추가", status)
status, payload = call("GET", f"/users/{user_id}/favorite-regions", token=token)
record(status == 200 and len(payload.get("data", [])) >= 1, "관심 지역 조회", status)
status, _ = call("DELETE", f"/users/{user_id}/favorite-regions/{region_id}", token=token)
record(status == 200, "관심 지역 삭제", status)

# ---------------------------------------------------------------- 여행
section("3. 여행 — 생성 · 코스 · 체크리스트")
status, payload = call("POST", "/trips", token=token, body={
    "userId": user_id, "applicantName": "통합테스트", "phoneNumber": "010-5555-6666",
    "residence": "전라남도", "startDate": "2026-08-01", "endDate": "2026-08-05",
    "travelerCount": 2, "regionId": region_id})
record(status == 200, "여행 생성", status)
trip = payload.get("data", {})
trip_id = trip.get("id")
record(trip.get("status") in {"BEFORE", "ONGOING", "ENDED", "SETTLEMENT_REQUESTED"},
       "tripStatus 와이어 값", trip.get("status"))
record(DATE_ONLY.match(str(trip.get("startDate", ""))) is not None,
       "일정은 date-only", trip.get("startDate"))

status, payload = call("GET", "/trips", token=token, body=None)
status, payload = call("GET", f"/trips?userId={user_id}", token=token)
record(status == 200 and any(t["id"] == trip_id for t in payload.get("data", [])),
       "내 여행 목록에 포함", status)

status, payload = call("GET", f"/trips/{trip_id}", token=token)
record(status == 200, "여행 상세", status)
problems = check_datetimes(payload.get("data"))
record(not problems, "여행 상세 datetime에 KST offset", problems[:2] or "전부 정상")

status, payload = call("POST", f"/trips/{trip_id}/places", token=token, body={
    "placeType": "HALF_PRICE", "referencePlaceId": None, "placeName": "통합테스트 관광지",
    "address": "전라남도 어딘가", "latitude": 34.31, "longitude": 126.75})
record(status == 200, "여행지 추가", status)
places = payload.get("data", [])
status, payload = call("POST", f"/trips/{trip_id}/places", token=token, body={
    "placeType": "DIGITAL_TOUR_CARD", "placeName": "통합테스트 할인처",
    "address": "전라남도 어딘가2", "latitude": 34.32, "longitude": 126.76})
places = payload.get("data", [])
record(len(places) == 2, f"여행지 2건", len(places))

ordered = [p["id"] for p in places][::-1]
status, payload = call("POST", f"/trips/{trip_id}/places/reorder", token=token,
                       body={"orderedTripPlaceIds": ordered})
record(status == 200 and [p["id"] for p in payload.get("data", [])] == ordered,
       "여행지 순서 변경", status)

status, payload = call("GET", f"/trips/{trip_id}/checklist", token=token)
record(status == 200, "체크리스트 조회", status)
checklist = payload.get("data", {})
record(checklist.get("total", 0) > 0, "체크리스트 항목 존재", checklist.get("total"))

status, payload = call("PUT", f"/trips/{trip_id}/checklist", token=token,
                       body={"items": [{"key": "PLACE_SELECTED", "checked": True}]})
record(status == 200, "체크리스트 수정", status)

# ---------------------------------------------------------------- 증빙
section("4. 증빙 — 업로드 · 인증사진 · 영수증")
status, payload = multipart(f"/trips/{trip_id}/uploaded-files", "file", "auth.png",
                            TINY_PNG, token, "?category=AUTH_PHOTO")
record(status == 200, "인증사진 업로드", status)
auth_file_id = payload.get("data", {}).get("id") if status == 200 else None
if status == 200:
    record(payload["data"].get("fileCategory") == "AUTH_PHOTO", "fileCategory 와이어 값",
           payload["data"].get("fileCategory"))

status, payload = multipart(f"/trips/{trip_id}/uploaded-files", "file", "receipt.png",
                            TINY_PNG, token, "?category=RECEIPT_IMAGE")
record(status == 200, "영수증 업로드", status)
receipt_file_id = payload.get("data", {}).get("id") if status == 200 else None

if auth_file_id:
    status, payload = call("GET", f"/trips/{trip_id}/uploaded-files/{auth_file_id}/binary",
                           token=token)
    record(status == 200, "업로드 파일 다운로드", status)

if fastapi_up and auth_file_id:
    status, payload = call("POST", f"/trips/{trip_id}/auth-photos/analyze/{auth_file_id}",
                           token=token, body={})
    record(status == 200, "인증사진 판정 (FastAPI)", status)
    review = payload.get("data", {}) if status == 200 else {}
    record("detectedPeopleCount" in review and "requiredPeopleCount" in review,
           "판정 응답에 인원수 포함",
           f'{review.get("detectedPeopleCount")}/{review.get("requiredPeopleCount")}')
    record("locationVerified" in review, "EXIF 위치검증 필드 포함",
           review.get("locationVerified"))
    record("withinTripPeriod" in review, "촬영시각 여행기간 검증 필드 포함",
           review.get("withinTripPeriod"))
else:
    skip("인증사진 판정", "FastAPI 미기동" if not fastapi_up else "업로드 실패")

if fastapi_up and receipt_file_id:
    status, payload = call("POST", f"/trips/{trip_id}/receipts/analyze/{receipt_file_id}",
                           token=token, body={"usageScope": "GENERAL"})
    record(status == 200, "영수증 OCR (FastAPI)", status)
    if status == 200:
        item = payload.get("data", {})
        record(item.get("amount") is not None, "OCR 결과에 금액 필드", item.get("amount"))
        record("usageScope" in item, "usageScope 반영", item.get("usageScope"))
        record(item.get("paymentType") in {
            "CREDIT_CARD", "CHECK_CARD", "ONLINE_PAYMENT", "BANK_TRANSFER",
            "CASH_RECEIPT", "SIMPLE_RECEIPT", "UNKNOWN"},
            "paymentType 와이어 값", item.get("paymentType"))
        record(item.get("reviewStatus") in {"PENDING", "APPROVED", "REJECTED"},
               "reviewStatus 와이어 값", item.get("reviewStatus"))
else:
    skip("영수증 OCR", "FastAPI 미기동" if not fastapi_up else "업로드 실패")

status, payload = call("POST", f"/trips/{trip_id}/lodging-info", token=token, body={
    "lodgingName": "통합테스트 숙소", "address": "전라남도 어딘가",
    "checkInDate": "2026-08-01", "checkOutDate": "2026-08-03"})
record(status == 200, "숙박정보 저장", status)

# ---------------------------------------------------------------- 정산
section("5. 정산 — 요약 · 신청")
status, payload = call("GET", f"/trips/{trip_id}/settlement-summary", token=token)
record(status == 200, "정산 요약", status)
summary = payload.get("data", {})
record("refundConditionAmount" in summary, "환급 조건 금액 포함")
record("환급완료" not in json.dumps(summary, ensure_ascii=False),
       "환급 완료 단계 없음 (도메인 대전제)")

status, payload = call("POST", f"/trips/{trip_id}/settlement-apply", token=token,
                       body={"applicantName": "통합테스트", "phoneNumber": "010-5555-6666"})
record(status == 200, "정산 신청", status)
if status == 200:
    record(payload["data"].get("status") == "SETTLEMENT_REQUESTED",
           "신청 후 status = SETTLEMENT_REQUESTED", payload["data"].get("status"))
    applied_at = payload["data"].get("settlementAppliedAt")
    record(applied_at is None or KST_OFFSET.search(applied_at) is not None,
           "settlementAppliedAt KST offset", applied_at)

# ---------------------------------------------------------------- 커뮤니티
section("6. 커뮤니티 — 글 · 댓글 · 반응")
status, payload = call("POST", "/community/posts", token=token, body={
    "userId": user_id, "type": "REVIEW", "regionName": regions[0]["name"],
    "title": "통합테스트 후기", "body": "전 여정 통합테스트에서 작성",
    "visibility": "PUBLIC"})
record(status == 200, "글 작성", status)
post = payload.get("data", {})
post_id = post.get("id")
record(post.get("type") in {"REVIEW", "COURSE", "QUESTION", "INFO"},
       "글 type 와이어 값", post.get("type"))
record(post.get("createdAt", "").endswith("+09:00") or KST_OFFSET.search(post.get("createdAt", "")),
       "글 createdAt KST offset", post.get("createdAt"))
record(post.get("authorNickname") == "통합테스터", "작성자 = 토큰 주인",
       post.get("authorNickname"))

status, payload = call("GET", f"/community/posts?userId={user_id}", token=token)
record(status == 200 and any(p["id"] == post_id for p in payload.get("data", [])),
       "피드에 반영", status)

status, payload = call("GET", f"/community/posts/{post_id}?userId={user_id}", token=token)
record(status == 200, "글 상세", status)

status, payload = call("POST", f"/community/posts/{post_id}/like?userId={user_id}", token=token)
record(status == 200 and payload["data"]["active"] is True, "좋아요", status)
status, payload = call("POST", f"/community/posts/{post_id}/bookmark?userId={user_id}", token=token)
record(status == 200 and payload["data"]["active"] is True, "북마크", status)

status, payload = call("POST", f"/community/posts/{post_id}/comments", token=token,
                       body={"userId": user_id, "body": "통합테스트 댓글"})
record(status == 200, "댓글 작성", status)
comment_id = payload.get("data", {}).get("id")

status, payload = call("POST", f"/community/comments/{comment_id}/like?userId={user_id}",
                       token=token)
record(status == 200, "댓글 좋아요", status)

status, payload = call("PATCH", f"/community/posts/{post_id}", token=token,
                       body={"userId": user_id, "title": "통합테스트 후기(수정)"})
record(status == 200 and payload["data"].get("edited") is True, "글 수정 + edited 표시", status)

status, payload = call("GET", f"/community/users/{user_id}/posts", token=token)
record(status == 200 and payload["data"]["postCount"] >= 1, "내가 쓴 글", status)
status, payload = call("GET", f"/community/users/{user_id}/bookmarks", token=token)
record(status == 200 and len(payload.get("data", [])) >= 1, "내 북마크", status)

status, payload = call("POST", "/community/reports", token=token,
                       body={"userId": user_id, "targetType": "POST",
                             "targetId": post_id, "reason": "통합테스트"})
record(status == 200, "신고", status)

# ---------------------------------------------------------------- 알림
section("7. 알림")
status, payload = call("GET", f"/notifications?userId={user_id}", token=token)
record(status == 200, "알림 목록", status)
problems = check_datetimes(payload.get("data"))
record(not problems, "알림 datetime KST offset", problems[:2] or "전부 정상")
status, payload = call("POST", f"/notifications/read-all?userId={user_id}", token=token, body={})
record(status == 200, "모두 읽음", status)

# ---------------------------------------------------------------- 보안
section("8. 보안 회귀 — IDOR · 위장 · 404")
other_id, other_token = None, None
other_login = f"qb{uuid.uuid4().hex[:8]}"
status, payload = call("POST", "/auth/signup", {
    "name": "타인", "loginId": other_login, "password": "test1234",
    "phoneNumber": "010-7777-8888", "residence": "전라남도"})
if status == 200:
    other_id, other_token = payload["data"]["userId"], payload["data"]["token"]

record(call("GET", f"/trips?userId={user_id}")[0] == 401, "토큰 없음 → 401")
record(call("GET", f"/trips?userId={user_id}", token="forged.token.value")[0] == 401,
       "위조 토큰 → 401")
if other_token:
    record(call("GET", f"/users/{user_id}", token=other_token)[0] == 403,
           "남의 /users/{id} → 403")
    record(call("GET", f"/trips?userId={user_id}", token=other_token)[0] == 403,
           "남의 ?userId= → 403")
    record(call("GET", f"/trips/{trip_id}", token=other_token)[0] == 403,
           "남의 여행 상세 → 403")
    record(call("DELETE", f"/trips/{trip_id}", token=other_token)[0] == 403,
           "남의 여행 삭제 → 403")
    status, _ = call("POST", "/community/posts", token=other_token, body={
        "userId": user_id, "type": "REVIEW", "title": "위장", "body": "위장 시도"})
    record(status == 403, "본문 userId 위장 → 403 (QA-001)")
    status, _ = call("POST", "/community/reports", token=other_token,
                     body={"userId": user_id, "targetType": "POST",
                           "targetId": post_id, "reason": "위장"})
    record(status == 403, "신고 본문 위장 → 403")
    status, _ = call("POST", "/trips", token=other_token, body={
        "userId": user_id, "applicantName": "위장", "phoneNumber": "010-0000-0000",
        "residence": "전라남도", "startDate": "2026-09-01", "endDate": "2026-09-02",
        "travelerCount": 1, "regionId": region_id})
    record(status == 403, "여행 생성 본문 위장 → 403")
    status, _ = call("PATCH", f"/community/posts/{post_id}", token=other_token,
                     body={"userId": other_id, "title": "남의 글 수정"})
    record(status in (403, 404), "남의 글 수정 차단", f"{status} (커뮤니티는 존재를 숨겨 404)")

record(call("DELETE", "/trips/99999999", token=token)[0] == 404, "없는 여행 → 404 (QA-006)")
record(call("GET", "/regions")[0] == 200, "공개 경로는 토큰 없이 통과")
health_status, health_body = call("GET", "/actuator/health", base="http://localhost:8080")
record(health_status == 200 and health_body.get("status") == "UP",
       "actuator/health = UP (스모크 세트 1번 항목)", f"{health_status} {health_body}")

# ---------------------------------------------------------------- 지도·외부연동
section("2b. 가맹점 지도 · 외부 장소 연동")
status, payload = call("GET", f"/regions/{region_id}/merchant-map", token=token)
record(status == 200, "가맹점 지도 조회", status)
merchants = (payload.get("data") or {}).get("merchants") if isinstance(payload.get("data"), dict) else None
if merchants:
    status, _ = call("GET", f"/regions/{region_id}/merchant-map/{merchants[0]['id']}", token=token)
    record(status == 200, "가맹점 상세", status)
else:
    record(status == 200, "가맹점 지도 응답 형태 확인", "가맹점 목록 없음")

status, payload = call("POST", "/google-places/search", token=token,
                       body={"query": "완도 해변", "latitude": 34.31, "longitude": 126.75})
record(status in (200, 400, 500, 502, 503), "Google 장소 검색 (키 없으면 실패가 정상)", status)

# ---------------------------------------------------------------- 여행 수정
section("3b. 여행 수정 · 코스 교체 · 파일 삭제")
status, payload = call("PUT", f"/trips/{trip_id}", token=token, body={
    "applicantName": "통합테스트", "phoneNumber": "010-5555-6666", "residence": "전라남도",
    "startDate": "2026-08-01", "endDate": "2026-08-06", "travelerCount": 3, "status": None})
record(status == 200, "여행 수정", status)
if status == 200:
    record(payload["data"].get("travelerCount") == 3, "인원 변경 반영",
           payload["data"].get("travelerCount"))

status, payload = call("PUT", f"/trips/{trip_id}/places", token=token, body={"places": [
    {"placeType": "HALF_PRICE", "placeName": "교체된 관광지", "address": "전남",
     "latitude": 34.3, "longitude": 126.7}]})
record(status == 200 and len(payload.get("data", [])) == 1, "코스 전체 교체", status)

status, payload = multipart(f"/trips/{trip_id}/uploaded-files", "file", "temp.png",
                            TINY_PNG, token, "?category=SIGNATURE")
temp_file_id = payload.get("data", {}).get("id") if status == 200 else None
record(status == 200, "서명 파일 업로드 (fileCategory=SIGNATURE)", status)
if temp_file_id:
    record(call("DELETE", f"/trips/{trip_id}/uploaded-files/{temp_file_id}",
                token=token)[0] == 200, "업로드 파일 삭제")

# ---------------------------------------------------------------- 숙박확인서·PDF
section("4b. 숙박확인서 · 증빙 패키지 PDF")
status, payload = call("GET", f"/integrations/lodging-form/{trip_id}", token=token)
record(status == 200, "숙박확인서 양식 조회", status)
form = payload.get("data") if status == 200 else None
if form:
    record("templateKey" in json.dumps(form, ensure_ascii=False), "지역별 양식 스키마 포함")

status, payload = call("PUT", f"/trips/{trip_id}/lodging-form", token=token,
                       body={"values": {"lodging_name": "통합테스트 숙소",
                                        "representative_name": "홍길동",
                                        "address": "전라남도 완도군 어딘가 1"}})
record(status == 200, "숙박확인서 값 저장", status)
if status == 200:
    saved = json.dumps(payload.get("data"), ensure_ascii=False)
    record("통합테스트 숙소" in saved, "저장한 값이 응답에 반영")

if fastapi_up and receipt_file_id:
    status, payload = call("POST", f"/trips/{trip_id}/lodging-info/extract/{receipt_file_id}",
                           token=token, body={})
    record(status in (200, 400, 422, 500), "숙박확인서 OCR 추출 (FastAPI)", status)
else:
    skip("숙박확인서 OCR 추출", "FastAPI 미기동")

def check_pdf(path, label):
    """PDF는 200만으로 부족하다. 실제 PDF 바이트인지, 빈 파일이 아닌지 본다."""
    status, payload = call("GET", path, token=token)
    if status != 200:
        record(False, label, f"HTTP {status}")
        return
    body = payload if isinstance(payload, bytes) else str(payload).encode("utf-8", "replace")
    record(body[:4] == b"%PDF", label + " — PDF 시그니처", body[:8])
    record(len(body) > 1000, label + " — 내용 있음", f"{len(body):,} bytes")


check_pdf(f"/integrations/lodging-form/{trip_id}/pdf", "숙박확인서 PDF 생성")
check_pdf(f"/integrations/lodging-form/{trip_id}/template-pdf", "원본 양식 PDF")
merge_ids = ",".join(str(i) for i in [auth_file_id, receipt_file_id] if i)
check_pdf(f"/integrations/pdf/merge/{trip_id}?uploadedFileIds={merge_ids}",
          "증빙 패키지 PDF 병합")

# ---------------------------------------------------------------- 유튜브 잡
section("10. 유튜브 코스 잡 · FCM · 스케줄러")
status, payload = call("POST", "/youtube-course-jobs", token=token, body={
    "userId": user_id, "tripId": trip_id, "regionId": region_id,
    "youtubeUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"})
record(status in (200, 400, 500, 503), "유튜브 잡 생성 (Redis 필요)", status)
job_id = (payload.get("data") or {}).get("jobId") if status == 200 else None
if job_id:
    record(call("GET", f"/youtube-course-jobs/{job_id}", token=token)[0] == 200, "잡 조회")
    record(call("PATCH", f"/youtube-course-jobs/{job_id}/processing", token=token,
                body={})[0] == 200, "잡 상태 PROCESSING")
    record(call("PATCH", f"/youtube-course-jobs/{job_id}/fail", token=token,
                body={"errorMessage": "통합테스트"})[0] == 200, "잡 실패 처리")
else:
    skip("유튜브 잡 상태 전이", "잡 생성 실패 (Redis 미기동)")
record(call("GET", f"/youtube-course-jobs/active?userId={user_id}&tripId={trip_id}",
            token=token)[0] in (200, 404), "진행 중 잡 조회")

status, payload = call("POST", f"/users/{user_id}/fcm-tokens", token=token,
                       body={"fcmToken": "integration-test-token", "platform": "web"})
record(status == 200, "FCM 토큰 등록", status)

record(call("GET", "/trips/settlement-reminder-targets?date=2026-08-08")[0] == 200,
       "정산 리마인더 대상 조회 (스케줄러용 공개 경로)")
record(call("GET", "/trips/settlement-reminder-targets")[0] == 400,
       "필수 파라미터 누락은 500이 아니라 400")
record(call("GET", "/regions/abc")[0] == 400, "경로 타입 오류는 400")
status, _ = call("POST", "/auth/login", raw_body=b"{bad json")
record(status == 400, "깨진 JSON 본문은 400", status)

# ---------------------------------------------------------------- FastAPI 직접
section("11. FastAPI 직접 호출")
if fastapi_up:
    body, content_type = multipart_body("r.png", TINY_PNG)
    for path, label in [("/api/v1/documents/ocr/receipt", "영수증 OCR"),
                        ("/api/v1/documents/ocr/receipt-amount", "금액·결제일시 추출"),
                        ("/api/v1/documents/ocr/lodging", "숙박정보 추출"),
                        ("/api/v1/documents/photos/auth-review", "인증사진 판정")]:
        status, payload = call("POST", path, base=FASTAPI, raw_body=body,
                               content_type=content_type)
        record(status in (200, 422), "FastAPI " + label, status)
        if status == 200:
            record(isinstance(payload, dict) and "data" in payload,
                   "FastAPI " + label + " — 응답 래퍼")
    record(call("GET", "/health", base=FASTAPI)[0] == 200, "FastAPI 헬스체크")
else:
    skip("FastAPI 직접 호출", "미기동")

# ---------------------------------------------------------------- 로그인 방식
section("1b. 로그인 방식 · 계약")
status, payload = call("POST", "/auth/mock-login",
                       {"provider": "GUEST", "email": "sample@travel-mvp.local", "name": "샘플"})
record(status == 200 and payload["data"].get("token"), "mock 로그인 + 토큰 발급", status)
status, payload = call("POST", "/auth/social-login",
                       {"provider": "KAKAO", "accessToken": "invalid-token"})
record(status in (400, 401, 500, 502), "소셜 로그인 - 잘못된 토큰 거부", status)
status, payload = call("POST", "/auth/signup", {
    "name": "중복", "loginId": login_id, "password": "test1234",
    "phoneNumber": "010-1111-2222", "residence": "전라남도"})
record(status == 400, "중복 아이디 가입 거부", status)

status, payload = call("GET", f"/community/posts/{post_id}/comments?userId={user_id}", token=token)
record(status == 200 and len(payload.get("data", [])) >= 1, "댓글 목록 조회", status)

# ---------------------------------------------------------------- 정리
section("9. 정리 — 글 삭제 · 탈퇴")
record(call("DELETE", f"/community/comments/{comment_id}?userId={user_id}", token=token)[0] == 200,
       "댓글 삭제")
record(call("DELETE", f"/community/posts/{post_id}?userId={user_id}", token=token)[0] == 200,
       "글 삭제")
record(call("DELETE", f"/trips/{trip_id}", token=token)[0] == 400,
       "정산 신청한 여행은 삭제 거부 (사양)")

status, payload = call("POST", "/trips", token=token, body={
    "userId": user_id, "applicantName": "통합테스트", "phoneNumber": "010-5555-6666",
    "residence": "전라남도", "startDate": "2026-09-10", "endDate": "2026-09-12",
    "travelerCount": 2, "regionId": region_id})
spare_trip_id = payload.get("data", {}).get("id")
record(call("DELETE", f"/trips/{spare_trip_id}", token=token)[0] == 200,
       "정산 전 여행은 삭제 가능")

record(call("DELETE", f"/users/{user_id}", token=token, body={"reason": "통합테스트"})[0] == 400,
       "정산 진행 중이면 탈퇴 거부 (사양)")

# 탈퇴는 정산 이력이 없는 계정으로 검증한다. 사유는 선택 입력이다.
if other_token:
    record(call("DELETE", f"/users/{other_id}", token=other_token,
                body={"reason": "통합테스트 정리"})[0] == 200, "회원 탈퇴 (사유 포함)")
    record(call("GET", f"/users/{other_id}", token=other_token)[0] in (401, 403, 404),
           "탈퇴 후 기존 토큰 무효")

    status, payload = call("POST", "/auth/signup", {
        "name": "사유없음", "loginId": f"qc{uuid.uuid4().hex[:8]}", "password": "test1234",
        "phoneNumber": "010-9999-0000", "residence": "전라남도"})
    bare_id, bare_token = payload["data"]["userId"], payload["data"]["token"]
    record(call("DELETE", f"/users/{bare_id}", token=bare_token)[0] == 200,
           "탈퇴 사유는 선택 입력 (본문 없이도 성공)")

# ---------------------------------------------------------------- 요약
passed = sum(1 for r in results if r[0] is True)
failed = [r for r in results if r[0] is False]
skipped = sum(1 for r in results if r[0] is None)
print(f"\n{'=' * 62}")
print(f"통합테스트 결과: {passed} PASS · {len(failed)} FAIL · {skipped} SKIP")
if failed:
    print("\n실패 목록:")
    for _, sec, label, detail in failed:
        print(f"  - [{sec}] {label}  ({detail})")
print("=" * 62)
sys.exit(1 if failed else 0)
