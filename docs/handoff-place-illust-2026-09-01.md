# 핸드오프 — 지정관광지 일러스트 (준서)

> 작성 2026-09-01 · 규희
> 지정관광지 **526곳**을 다 그릴 수는 없으니 **유형별로 한 장씩** 만들어 돌려 쓴다.
> 스타일은 지역 마그넷(`assets/magnet/`, 25종)과 같게 — 앱 전체 톤을 한 벌로 맞추는 게 목적.

## 왜 카테고리 방식인가

운영 DB의 지정관광지 이름 526개를 전부 읽어서 유형어로 묶어봤다.
**26종이면 489곳(92%)이 덮인다.** 나머지 37곳은 폴백 한 장으로 처리한다.

한국 지명은 유형이 뒤에 붙어서(`월출산`·`대흥사`·`고창읍성`) 이름만으로 유형이 거의 갈린다.

---

## 그릴 목록

**A(20장)만 그려도 434곳(83%)이 덮인다.** A부터 하고 B는 여유 되면.

표의 **소재**는 사람이 읽으라고 적은 설명이고, 실제로 프롬프트에 붙여 넣을 문구는
아래 **프롬프트 → `[내용]`에 넣을 것** 표에 있다.

### A — 우선 (20장)

| # | 파일명 | 카테고리 | 곳 수 | 소재 |
| --- | --- | --- | --- | --- |
| 1 | `museum` | 박물관·전시관 | 37 | 기둥 있는 전시관 건물, 입구 계단 |
| 2 | `temple` | 사찰 | 33 | 기와 지붕 대웅전, 단청, 석등 하나 |
| 3 | `experience` | 체험관·공방 | 32 | 앞치마와 도자기 물레, 나무 작업대 |
| 4 | `mountain` | 산·봉우리 | 29 | 뾰족한 봉우리 둘, 정상 표지석 |
| 5 | `park` | 공원 | 29 | 잔디밭과 벤치, 가로등, 나무 한 그루 |
| 6 | `lake` | 호수·습지 | 25 | 잔잔한 물과 갈대, 물 위 나무 데크 |
| 7 | `village` | 마을 | 22 | 기와·초가 지붕 서너 채와 돌담 |
| 8 | `observatory` | 전망대·케이블카 | 21 | 원형 전망 데크와 망원경 |
| 9 | `themepark` | 테마파크 | 19 | 관람차와 알록달록 천막 |
| 10 | `seowon` | 서원·향교 | 17 | 낮은 기와 담장과 솟을대문 |
| 11 | `forest` | 자연휴양림 | 15 | 쭉 뻗은 나무 사이 흙길, 통나무 오두막 |
| 12 | `trail` | 둘레길·산책로 | 15 | 굽이진 나무 데크길과 이정표 |
| 13 | `hanok` | 고택·생가 | 15 | 마루 있는 한옥 한 채, 장독대 |
| 14 | `healing` | 치유센터·힐링 | 14 | 편백 사이 나무 평상, 김 오르는 찻잔 |
| 15 | `gallery` | 미술관 | 14 | 액자 걸린 흰 벽과 이젤 |
| 16 | `beach` | 해수욕장·갯벌 | 13 | 파라솔과 파도, 조개껍데기 |
| 17 | `island` | 섬 | 13 | 바다 위 작은 섬과 등대 |
| 18 | `sports` | 스포츠시설 | 13 | 트랙과 골대, 공 하나 |
| 19 | `science` | 과학관·천문대 | 12 | 은색 돔과 망원경, 작은 별 |
| 20 | `garden` | 수목원·정원 | 12 | 아치형 화단과 온실 유리집 |

### B — 여유 되면 (10장)

| # | 파일명 | 카테고리 | 곳 수 | 소재 |
| --- | --- | --- | --- | --- |
| 21 | `pavilion` | 정자·누각 | 12 | 기둥 넷 위 팔작지붕 정자 |
| 22 | `memorial` | 기념관·기념탑 | 11 | 오벨리스크형 기념탑과 헌화 |
| 23 | `bridge` | 다리·대교 | 10 | 사장교 케이블과 상판 |
| 24 | `culture` | 문화센터·공연장 | 10 | 붉은 커튼 무대와 객석 |
| 25 | `fortress` | 성곽·읍성 | 8 | 성벽과 성문 누각 |
| 26 | `farm` | 농장·목장·다원 | 12 | 계단식 밭과 사일로, 울타리 |
| 27 | `valley` | 계곡·폭포 | 6 | 바위 사이 물줄기와 너럭바위 |
| 28 | `heritage` | 유적·고인돌 | 5 | 고인돌과 석탑 |
| 29 | `market` | 전통시장 | 3 | 차양 아래 좌판과 과일 상자 |
| 30 | `cave` | 동굴·터널 | 4 | 종유석 있는 굴 입구 |

### 폴백 (1장) — **필수**

| 파일명 | 소재 |
| --- | --- |
| `default` | **나무 방향 이정표** — 기둥에 화살표 팻말 두세 개, 발밑에 잔디 |

카테고리에 안 걸리는 37곳(`돌할매`·`합천운석충돌구`·`지족해협 죽방렴` 등)과
앞으로 새로 추가될 지역의 관광지가 전부 이걸로 뜬다.

**왜 이정표인가** — "여기 볼 것이 있다"만 말하고 유형은 주장하지 않는다.
건물이나 자연물을 폴백으로 쓰면 아닌 곳에 붙었을 때 틀린 정보가 된다.
지역 마그넷 폴백이 캐리어(`assets/magnet/default.png`)라 겹치지도 않는다.

---

## 프롬프트

지역 마그넷 25종을 만든 것과 **똑같은 프롬프트**를 쓴다. `[내용]`만 갈아 끼운다.

```
A cute glossy 3D balloon-style fridge magnet illustration of [내용]
inflated puffy rounded shapes like a mylar balloon, soft plastic sheen
with gentle highlights, thick white sticker border, natural colors true
to the real object with slightly candy-toned saturation, centered single
object, transparent background, clean vector-like edges, mobile app icon
aesthetic, no text, square 1:1 aspect ratio, composition fitted within
a square canvas
```

### `[내용]`에 넣을 것

| 파일명 | `[내용]` |
| --- | --- |
| `museum` | `a Korean museum building with columns and an entrance staircase` |
| `temple` | `a Korean Buddhist temple hall with a tiled roof, dancheong patterns and a stone lantern` |
| `experience` | `a pottery wheel with clay and an apron on a wooden workbench` |
| `mountain` | `two rocky mountain peaks with a small summit marker stone` |
| `park` | `a small park with a bench, a lamppost and one tree on grass` |
| `lake` | `a calm lake with reeds and a small wooden deck` |
| `village` | `a cluster of Korean tiled and thatched roof houses behind a stone wall` |
| `observatory` | `a round observation deck with a coin-operated telescope` |
| `themepark` | `a ferris wheel with colorful striped tents` |
| `seowon` | `a Korean confucian academy gate with a low tiled wall` |
| `forest` | `a dirt path between tall straight trees with a small log cabin` |
| `trail` | `a curving wooden boardwalk trail with a signpost` |
| `hanok` | `a Korean hanok house with a wooden porch and jangdokdae jars` |
| `healing` | `a wooden platform among cypress trees with a steaming teacup` |
| `gallery` | `a white gallery wall with framed paintings and an easel` |
| `beach` | `a beach parasol with waves and a seashell` |
| `island` | `a small green island in the sea with a lighthouse` |
| `sports` | `a running track with a goal post and a ball` |
| `science` | `a silver observatory dome with a telescope and small stars` |
| `garden` | `an arched flower bed with a small glass greenhouse` |
| `pavilion` | `a Korean pavilion with four pillars and a hip-and-gable roof` |
| `memorial` | `an obelisk memorial monument with a flower wreath` |
| `bridge` | `a cable-stayed bridge deck with cables` |
| `culture` | `a theater stage with red curtains and seats` |
| `fortress` | `a stone fortress wall with a gate pavilion` |
| `farm` | `a terraced field with a silo and a wooden fence` |
| `valley` | `a mountain stream falling between rocks onto a flat boulder` |
| `heritage` | `a dolmen and a stone pagoda` |
| `market` | `a traditional market stall under an awning with fruit crates` |
| `cave` | `a cave entrance with stalactites` |
| **`default`** | **`a wooden directional signpost with two or three arrow boards on a grass patch`** |

**주의**
- **특정 장소를 그리지 않는다.** `고창 고인돌`이 아니라 "고인돌 일반"이다. 한 장이 여러 곳에 붙는다
- **글자 금지** — 프롬프트의 `no text`가 있지만 간판·현판에 글자가 새어 들어오면 다시 뽑는다
- 사람은 넣지 않는다

---

## 넣는 곳

```
~/project/halftrip/halftrip-app/flutter_app/assets/illust/place/{파일명}.png
```

- 폴더는 **만들어 뒀고 `pubspec.yaml` 등록도 끝났다.** 파일만 넣으면 된다
- 확장자 `.png`, **투명 배경**


## 참고

- 지역 마그넷 25종: `assets/magnet/` · 프롬프트는 `docs/region-magnet-prompts-2026-09-01.md`
- 분류 근거: 운영 DB `places` 526행 (2026-09-01 기준, 18개 지역)
