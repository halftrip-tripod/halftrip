# 통합 QA 테스트케이스

> 3개 레포(Flutter · Spring · FastAPI)를 **한 덩어리로** 검증하는 케이스 모음.
> 화면 단위 체크리스트는 [docs/qa-handoff.md](../qa-handoff.md), 여기는 **레포를 가로지르는 시나리오와 계약 검증**을 다룬다.

| 파일 | 다루는 것 |
| --- | --- |
| [tc-security.md](tc-security.md) | 인증 토큰·권한(IDOR)·비밀번호·개인정보 파기 |
| [tc-contract.md](tc-contract.md) | 레포 간 계약 — 응답 래퍼·enum 와이어값·타임존·포트·콜백 경로 |
| [tc-journey.md](tc-journey.md) | 핵심 여정 E2E (여행 등록 → 인증 → 정산) |
| [scripts/api_qa.py](scripts/api_qa.py) | 위 케이스 중 API로 자동 검증 가능한 것 실행 |

---

## 표기 규칙

- **TC-<영역>-<번호>** 로 식별. 케이스는 지우지 말고 `폐기` 로 표시해 이력을 남긴다.
- 각 케이스는 **전제 / 절차 / 기대결과** 3줄이 반드시 있어야 한다. 기대결과가 애매하면 케이스가 아니다.
- 결과 표기: `PASS` · `FAIL(#이슈번호)` · `BLOCKED(사유)` · `N/A(사유)`
- 심각도 기준은 QA 규칙 문서를 따른다 (🔴 막힘 / 🟡 불편 / ⚪ 사소, **보안·개인정보는 무조건 🔴 시작**).

---

## 환경 기동 (통합 QA용)

### ⚠️ 포트 주의 — 문서의 8080이 아니라 **10000**

`application.yml` 이 `server.port: ${PORT:10000}` 이라, `PORT` 를 주지 않으면 **10000** 으로 뜬다.
FastAPI `.env.example`·Flutter 실행 예시·qa-handoff 는 8080을 가리키므로 **둘 중 하나를 맞춰야 연동이 된다.**

```bash
# 방법 A) 문서에 맞추기 (권장 — 다른 레포 기본값이 8080)
PORT=8080 mvn spring-boot:run

# 방법 B) 기본값 그대로 쓰고 나머지를 10000으로 맞추기
mvn spring-boot:run   # → localhost:10000
```

### Spring (DB 없이 H2로 빠르게)

```bash
cd halftrip-springboot
PORT=8080 mvn spring-boot:run \
  -Dspring-boot.run.profiles=local \
  -Dspring-boot.run.arguments="\
--spring.data.redis.host=localhost \
--spring.sql.init.mode=never \
--app.jwt-secret=qa-secret-key-32bytes-minimum-length-ok \
--app.auth.token-enforced=true \
--app.storage-root=./qa-uploads"
```

- `spring.sql.init.mode=never` 를 빼면 **시드(data-local.sql)가 스키마와 어긋나 기동에 실패**한다 (TC-CONTRACT-005 참고). 시드가 고쳐지면 이 옵션을 뺀다.
- `app.auth.token-enforced` 는 **보안 케이스를 볼 때 반드시 true** 로 켠다. 운영 기본값은 false라 끄면 대부분의 권한 케이스가 무의미하게 통과한다.
- Redis가 없으면 `/actuator/health` 는 503(DOWN)이 정상이다. 기동 확인은 `GET /api/regions` 로 한다.

### FastAPI

```bash
cd halftrip-fastapi
docker build -t halftrip-fastapi . && docker run --rm -p 8000:8000 --env-file .env halftrip-fastapi
```

- **Python 3.12 기준**이다 (Dockerfile `python:3.12-slim`). 3.13+ 로컬 venv에서는 `Pillow`·`pydantic-core` 휠 빌드가 깨진다. venv로 돌릴 거면 3.12를 쓴다.

### Flutter

```bash
cd halftrip/flutter_app
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080/api \
  --dart-define=FASTAPI_BASE_URL=http://localhost:8000 \
  --dart-define=USE_MOCK_API=false --dart-define=USE_MOCK_LOGIN=false
```

- `--dart-define` 을 하나도 안 주면 **Render 운영 서버**를 본다 (`app_config.dart` 기본값). 로컬 검증인 줄 알고 운영 데이터를 건드리지 않도록 주의.

---

## 테스트 계정

| 계정 | 용도 | 규칙 |
| --- | --- | --- |
| `sample / 1234` | 심사위원·데모 | **탈퇴·삭제 케이스에 쓰지 말 것** |
| `qaA`, `qaB` | 권한 교차 검증(2명 필요) | 스크립트가 없으면 자동 생성 |
| `qa-del-<날짜>` | 탈퇴·삭제 | 매번 새로 만들고 버린다 |
| `openapi / 2026openapi!` | 공모전 심사 | 출시 전 생성·로그인 확인 |

```bash
# 계정 생성 (한글이 들어가므로 셸 인코딩 문제를 피하려면 스크립트 사용 권장)
curl -X POST localhost:8080/api/auth/signup -H "Content-Type: application/json" \
  -d '{"name":"QA","loginId":"qaA","password":"1234","phoneNumber":"010-0000-0001","residence":"Seoul"}'
```

---

## 자동 검증 스크립트

```bash
python halftrip/docs/test/scripts/api_qa.py --base http://localhost:8080
```

계정 2개를 만들고 로그인해 **권한·계약 케이스를 한 번에 돌린다.** 종료 코드 0이면 전부 PASS.
스크립트가 커버하는 케이스는 각 케이스 표의 `자동` 열에 ✅ 로 표시했다.
