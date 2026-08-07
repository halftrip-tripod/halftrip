"""통합 QA — API로 자동 검증 가능한 케이스 실행기.

사용법:
    python halftrip/docs/test/scripts/api_qa.py --base http://localhost:8080

Spring이 `app.auth.token-enforced=true` 로 떠 있어야 보안 케이스가 의미를 갖는다.
enforce=false 면 권한 케이스는 SKIP으로 표시한다.
표준 라이브러리만 쓴다(설치 불필요).
"""
import argparse
import json
import sys
import urllib.error
import urllib.request

PASSWORD = "1234"
ACCOUNTS = [("qaA", "큐에이A"), ("qaB", "큐에이B")]

results = []


def call(base, method, path, body=None, token=None):
    request = urllib.request.Request(base + path, method=method)
    if body is not None:
        request.add_header("Content-Type", "application/json")
        request.data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        response = urllib.request.urlopen(request, timeout=20)
        return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", "replace")
        try:
            return error.code, json.loads(raw)
        except ValueError:
            return error.code, raw
    except Exception as error:  # noqa: BLE001
        return 0, str(error)


def check(case_id, description, actual, expected):
    ok = actual == expected if not isinstance(expected, (list, tuple)) else actual in expected
    results.append((ok, case_id, description, actual, expected))
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {case_id} {description} (실제 {actual} / 기대 {expected})")
    return ok


def sign_up_all(base):
    for login_id, name in ACCOUNTS:
        call(base, "POST", "/api/auth/signup", {
            "name": name,
            "loginId": login_id,
            "password": PASSWORD,
            "phoneNumber": "010-0000-0001",
            "residence": "서울특별시 강남구",
        })


def login(base, login_id):
    status, body = call(base, "POST", "/api/auth/login", {"loginId": login_id, "password": PASSWORD})
    if status != 200:
        sys.exit(f"로그인 실패({login_id}): {status} {body}")
    return body["data"]


def run_security(base, a, b, enforced):
    print("\n== TC-SEC 인증·권한 ==")
    check("TC-SEC-001", "로그인 토큰이 JWT 형식", a["token"].count("."), 2)
    check("TC-SEC-001", "mockToken == token (하위호환)", a["mockToken"] == a["token"], True)

    if not enforced:
        print("  [SKIP] TC-SEC-002~009 — token-enforced=false 라 권한 검사가 동작하지 않는다")
        return

    check("TC-SEC-002", "토큰 없이 /api/trips", call(base, "GET", f"/api/trips?userId={a['userId']}")[0], 401)
    check("TC-SEC-003", "위조 토큰", call(base, "GET", f"/api/users/{a['userId']}", token="aaa.bbb.ccc")[0], 401)
    check("TC-SEC-004", "남의 ?userId= 여행목록",
          call(base, "GET", f"/api/trips?userId={b['userId']}", token=a["token"])[0], 403)
    check("TC-SEC-004", "남의 ?userId= 알림",
          call(base, "GET", f"/api/notifications?userId={b['userId']}", token=a["token"])[0], 403)
    check("TC-SEC-005", "자기 /users/{id}",
          call(base, "GET", f"/api/users/{a['userId']}", token=a["token"])[0], 200)
    check("TC-SEC-005", "남의 /users/{id}",
          call(base, "GET", f"/api/users/{b['userId']}", token=a["token"])[0], 403)
    check("TC-SEC-005", "남의 커뮤니티 작성글",
          call(base, "GET", f"/api/community/users/{b['userId']}/posts", token=a["token"])[0], 403)

    # body 위장 — 경로·쿼리만 막고 body를 놓치면 여기서 잡힌다
    status, _ = call(base, "POST", "/api/community/posts", {
        "userId": b["userId"], "type": "REVIEW", "regionId": 1,
        "body": "QA 위장 시도", "visibility": "PUBLIC",
    }, token=a["token"])
    check("TC-SEC-007", "커뮤니티 글 body userId 위장", status, 403)

    status, _ = call(base, "POST", "/api/community/reports", {
        "userId": b["userId"], "targetType": "POST", "targetId": 1, "reason": "QA",
    }, token=a["token"])
    check("TC-SEC-007", "신고 body userId 위장", status, 403)

    print("\n== TC-SEC-008 공개 경로 (401이면 안 된다) ==")
    for path, method, body in [
        ("/api/regions", "GET", None),
        ("/api/youtube-course-jobs/qa-none/processing", "PATCH", {}),
        ("/api/trips/settlement-reminder-targets?date=2026-08-08", "GET", None),
    ]:
        status, _ = call(base, method, path, body)
        check("TC-SEC-008", f"{method} {path.split('?')[0]}", status != 401, True)

    print("\n== TC-SEC-010 비밀번호 ==")
    check("TC-SEC-010", "틀린 비밀번호 거부",
          call(base, "POST", "/api/auth/login", {"loginId": "qaA", "password": "wrong"})[0], 400)


def run_contract(base, a):
    print("\n== TC-CONTRACT 계약 ==")
    status, body = call(base, "GET", "/api/regions")
    check("TC-CONTRACT-001", "공통 래퍼 success 키",
          isinstance(body, dict) and "success" in body and "data" in body, True)

    status, body = call(base, "GET", f"/api/community/users/{a['userId']}/posts", token=a["token"])
    posts = (body.get("data") or {}).get("posts") if isinstance(body, dict) else None
    if posts:
        created_at = posts[0].get("createdAt", "")
        has_offset = created_at.endswith("Z") or "+" in created_at[10:]
        check("TC-CONTRACT-002", f"createdAt KST offset ({created_at})", has_offset, True)
    else:
        print("  [SKIP] TC-CONTRACT-002 — 확인할 글이 없다")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://localhost:8080", help="Spring API base URL")
    args = parser.parse_args()
    base = args.base.rstrip("/")

    status, _ = call(base, "GET", "/api/regions")
    if status == 0:
        sys.exit(f"서버에 붙지 못했다: {base} — 포트를 확인한다(기본 10000, PORT=8080 권장)")

    sign_up_all(base)
    a, b = login(base, "qaA"), login(base, "qaB")

    # 토큰 없이 보호 API가 열려 있으면 enforce가 꺼진 것
    enforced = call(base, "GET", f"/api/trips?userId={a['userId']}")[0] == 401
    print(f"token-enforced = {enforced}")

    run_security(base, a, b, enforced)
    run_contract(base, a)

    failed = [r for r in results if not r[0]]
    print(f"\n결과: {len(results) - len(failed)} PASS / {len(failed)} FAIL")
    for _, case_id, description, actual, expected in failed:
        print(f"  FAIL {case_id} {description} — 실제 {actual}, 기대 {expected}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
