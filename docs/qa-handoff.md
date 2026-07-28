# 🧪 하프트립 QA 핸드오프 (2026-07-28 작성)

> QA 전용 세션용. 환경 기동 → 검증 방법 → 체크리스트 → 규정/법/출시 점검 순.
> 진행 현황: [progress-status.md](progress-status.md) · 백엔드 잔여: [backend-api-requests.md](backend-api-requests.md)

---

## 1. 환경 기동 (로컬 풀스택)

```bash
# ① 인프라 (Docker Desktop 실행 후)
docker start halftrip-mysql halftrip-redis

# ② Spring (dev 최신으로)
cd ~/project/halftrip/halftrip-springboot && git switch dev && git pull
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home PORT=8080 mvn spring-boot:run
# 기동 확인: curl localhost:8080/api/regions → 200

# ③ FastAPI (인증샷 AI판정·OCR·PDF 필요 시)
cd ~/project/halftrip/halftrip-fastapi && git switch dev && git pull
.venv/bin/uvicorn app.main:app --port 8000
# ⚠️ OPENAI/YOUTUBE 키 없으면 AI판정·유튜브 분석은 실패 정상 — 키는 하민 보유

# ④ 웹 빌드 + 서빙 (localhost:8643)
cd ~/project/halftrip/halftrip-app/flutter_app
flutter build web --pwa-strategy=none \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/api \
  --dart-define=FASTAPI_BASE_URL=http://localhost:8000 \
  --dart-define=MAP_PROVIDER=google \
  --dart-define=GOOGLE_MAP_API_KEY=<구글키:android/local.properties 참고>
python3 serve_nocache.py   # 8643, no-store (유령 빌드 방지 — 일반 서버 쓰지 말 것)
```

**폰(실기기) 실행** — 같은 와이파이 필수, IP는 `ipconfig getifaddr en0`으로 매번 확인:
```bash
flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://<맥IP>:8080/api \
  --dart-define=FASTAPI_BASE_URL=http://<맥IP>:8000 \
  --dart-define=MAP_PROVIDER=google --dart-define=GOOGLE_MAP_API_KEY=<구글키>
```

**계정**: 로컬 로그인 `sample` / `1234` (완도 여행 데이터 보유). 새 계정은:
```bash
curl -X POST localhost:8080/api/auth/signup -H "Content-Type: application/json" \
  -d '{"name":"큐에이","loginId":"qa1","password":"1234","phoneNumber":"010-0000-0000","residence":"서울특별시 강남구"}'
```
⚠️ `sample` 계정은 탈퇴 테스트에 쓰지 말 것 (탈퇴 QA는 일회용 계정 생성해서).

## 2. 검증 방법

- **폰 스크린샷**: `adb exec-out screencap -p > shot.png` (또는 flutter run 중 `s` 키)
- **웹 자동 캡처(헤드리스)**: Chrome CDP로 클릭·입력·스크린샷 자동화 — 아래 스크립트를 스크래치패드에 `drive.py`로 저장, 스텝은 JSON으로:
```python
# drive.py — python3 drive.py steps.json (websocket-client 필요: pip3 install --user websocket-client)
import base64, json, subprocess, time, urllib.request, sys, websocket
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; PORT=9333
proc=subprocess.Popen([CHROME,"--headless=new","--disable-gpu",f"--remote-debugging-port={PORT}",
 "--window-size=430,932","--hide-scrollbars","--user-data-dir=/tmp/cdp-halftrip-qa","http://localhost:8643/"],
 stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); time.sleep(4)
page=next(t for t in json.load(urllib.request.urlopen(f"http://localhost:{PORT}/json")) if t["type"]=="page" and "8643" in t.get("url",""))
ws=websocket.create_connection(page["webSocketDebuggerUrl"],suppress_origin=True); _id=0
def send(m,**p):
    global _id; _id+=1; ws.send(json.dumps({"id":_id,"method":m,"params":p}))
    while True:
        r=json.loads(ws.recv())
        if r.get("id")==_id: return r.get("result",{})
def click(x,y):
    for t in("mousePressed","mouseReleased"): send("Input.dispatchMouseEvent",type=t,x=x,y=y,button="left",clickCount=1)
send("Page.enable"); time.sleep(4)
for s in json.load(open(sys.argv[1])):
    k=s[0]
    if k=="click": click(s[1],s[2])
    elif k=="type": send("Input.insertText",text=s[1])
    elif k=="wait": time.sleep(s[1])
    elif k=="scroll": send("Input.dispatchMouseEvent",type="mouseWheel",x=s[1],y=s[2],deltaX=0,deltaY=s[3])
    elif k=="shot": open(s[1],"wb").write(base64.b64decode(send("Page.captureScreenshot",format="png")["data"]))
    time.sleep(0.8)
ws.close(); proc.terminate()
```
- 스텝 예: `[["wait",3],["click",250,807],["type","sample"],["shot","a.png"]]` — 로그인 링크는 (250,807), 아이디 (250,111), 비번 (240,202), 로그인 버튼 (250,792) 기준 (창 500×845)
- **서버 교차 확인**: 화면 조작 후 curl로 DB 반영 확인 (예: 체크리스트 `curl localhost:8080/api/trips/{id}/checklist`)
- ⚠️ 헤드리스에서 이미지 에셋(로고·소셜 버튼)이 늦게 뜨거나 안 보일 수 있음 — 실브라우저로 재확인 후 버그 판정

## 3. 기능 QA 체크리스트 (E2E 검증된 것도 회귀 확인)

**온보딩·계정**
- [ ] 로컬 로그인 성공/실패(틀린 비번) · 소셜 버튼은 **아직 mock-login** (실 OAuth 미연결 — 버그 아님)
- [ ] 거주지 설정 → 홈 거주지 뱃지 반영
- [ ] 마이페이지: 거주지 변경(서버 저장 — 재로그인 후 유지 확인), 프로필 닉네임·아바타 변경(서버 저장), 알림 토글 2개
- [ ] 로그아웃 다이얼로그 / **회원 탈퇴**: 경고 다이얼로그 → 탈퇴 → 로그인 화면 → 재로그인 불가 (일회용 계정으로!)
- [ ] 이용약관·개인정보처리방침 화면 열림·내용 표시

**내여행 (핵심 여정)**
- [ ] 여행 추가: 접수중 지역 조회 → 신청완료 → 날짜·인원 → 생성 → 카드 표시
- [ ] 여행 단계: 날짜에 따라 여행전/중/종료, 정산 신청 시 "정산 신청" 칩 — **서버 status 기준** (기기 시간 바꿔도 동일해야)
- [ ] 카드 게이지: 출발 체크리스트 N/4(서버), 여행중 소비 게이지 / "인증 N/M곳"·"정산 D-day"는 **하민 C필드 전까지 미표시가 정상**
- [ ] 출발 체크리스트: 토글 → 서버 저장(재진입 유지) — 항목 문구는 자동판정 하이브리드(정훈 구현, 협의 중)
- [ ] 인증샷: **인증할 관광지 칩 선택** → 사진 업로드 → AI 판정 카드(인원·얼굴·촬영시각) — 위치검증은 **GPS EXIF 있는 실사진**으로 폰 테스트 필수 (스크린샷·SNS 사진은 GPS 없어 실패가 정상)
- [ ] 영수증 OCR → 금액 인정 → 소비 누적 / 숙박확인서 폼·서명·PDF / 증빙 패키지 병합·다운로드
- [ ] 정산 신청: 실명·전화 입력 시트(빈값 차단) → 신청 완료 → 지난여행 이동
- [ ] 지난여행: 다녀온 코스(구글맵 번호핀·핀 탭 정보창·리스트 하이라이트), 후기 쓰기→내 후기 표시→공개 전환

**알림**
- [ ] 상단바 미읽음 배지, 목록 오늘/지난 그룹, 모두 읽음
- [ ] 딥링크: **서버 refType 미구현(하민)이라 실서버에선 탭해도 무동작이 정상** — mock 모드로만 동작 확인 가능

**커뮤니티 (로컬퍼스트 — 서버 없음이 정상)**
- [ ] 글쓰기(지역·공개범위) → 피드 표시 → 좋아요·저장 → **새로고침 후 유지(기기 영속)**
- [ ] 마이페이지 작성한 글/저장한 글 목록

**코스**
- [ ] 유튜브로 만들기: 링크 입력 → 잡 생성(서버 PENDING 확인) — 실분석은 워커 키 필요(하민 환경)
- [ ] AI 추천·직접 만들기는 하민 작업 후 QA

**홈·온라인몰·지역상세** — 준서 `feat/home-api` 머지 후 QA (그 전엔 mock 표시가 정상)

## 4. 알려진 한계 (버그로 잡지 말 것)

1. 소셜 로그인 = mock (실 OAuth 클라 미착수) 2. 커뮤 서버 없음(로컬퍼스트가 사양) 3. 알림 딥링크 refType 서버 대기 4. 인증 N/M곳·정산 D-day 게이지 C필드 대기 5. AI판정·유튜브 분석은 API 키 있는 환경에서만 6. Render 배포엔 최신 백엔드 없음 — **QA는 로컬 스택 기준**

## 5. 대회·법·정책 점검 항목

- [ ] **개인정보처리방침**: 앱 내 표시 확인 + 내용이 실제 데이터 흐름과 일치(국외이전 OpenAI·Google·Render, 정산 시점 실명 수집, 14세 미만 미수집) — 코드 바뀌면 방침도 갱신
- [ ] **계정 삭제**: 앱 내 탈퇴 동작 + 웹 삭제 안내([policies/account-deletion.md](policies/account-deletion.md)) — **Play 등록 전 웹 호스팅 필요(URL 2개: 방침·삭제)**
- [ ] **위치정보**: 좌표 서버 미저장(판정만) 유지 확인 — 구조 바꾸면 법적 재검토. LBS 간이신고는 **출시 후 1개월 내**(계속 운영 시) 일정에만
- [ ] **저작권**: 일러스트=자체 AI 생성만 사용(외부 사진 금지), 폰트 Pretendard(OFL), 구글맵 로고·attribution 가리지 않기, 외부 링크(지자체·몰)는 링크만
- [ ] **대회 규정**: 출품작 원본성(외부 코드 라이선스 표기), 팀명·앱명 표기 일관성 — 제출 서류는 준서 작성분과 대조
- [ ] 심사위원 계정: `sample/1234` 동작 + 데이터 시나리오(여행 전/중/정산/지난여행 각 1개) 세팅 스크립트 준비

## 6. Play Store 출시 전 기술 점검

- [ ] **`usesCleartextTraffic="true"` 제거** — 로컬 http 테스트용. 프로덕션(https)은 불필요, 심사 감점 요소 ⚠️
- [ ] 서명: release keystore 생성(`android/key.properties`, 커밋 금지) — 현재 debug 서명 상태
- [ ] `flutter build appbundle` 통과 + versionCode/Name 정리
- [ ] 권한 최소화 확인(카메라·사진·알림만), targetSdk 최신
- [ ] Data safety 양식 초안: 수집항목=방침 2항과 동일하게
- [ ] 프로덕션 dart-define: API_BASE_URL=Render(https), Render에 최신 백엔드 배포 + 콜드스타트 대응(하민)
- [ ] 스토어 자산: 스크린샷(폰 캡처 활용)·512 아이콘·그래픽 이미지·설명문
- [ ] 비공개 테스트 트랙 W10(8/18) 전 업로드 — 14일 테스터 요건 역산

## 7. 버그 기록 규약

- 레포 이슈로 등록 (정훈이 만든 이슈 템플릿 사용), 제목: `[QA] 화면 - 증상`
- 필수: 재현 스텝 / 기대 vs 실제 / 스크린샷 / 환경(웹·폰, mock·실서버) / 심각도(🔴막힘·🟡불편·⚪사소)
- 내 영역 아닌 버그(홈·코스 등)는 고치지 말고 이슈만 — 담당 멘션
