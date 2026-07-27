# 🎨 지역 일러스트 제작 가이드 (규희)

> 결정(07-14): 지역·관광지 이미지는 실사진 대신 **AI 일러스트** (저작권·앱 톤).
> 적용 구조: `assets/illust/region/{키}.png` 가 있으면 이미지, 없으면 기존 이모지 폴백 — **일부만 만들어도 앱이 깨지지 않음.**

## 공통 스타일 프롬프트 (모든 지역 앞에 붙이기)

```
soft pastel flat illustration, travel app style, sky blue accent palette (#0EA5E9),
rounded shapes, minimal details, warm and friendly, white background,
square composition, no text, no people faces
```

## 지역 16곳 — 파일명·모티프·프롬프트

| 파일명 | 지역 | 모티프 | 개별 프롬프트 |
| --- | --- | --- | --- |
| `wando.png` | 완도 | 청정바다·전복·완도타워 | turquoise sea with small island tower, abalone shell, gentle waves |
| `gangjin.png` | 강진 | 청자·가우도 출렁다리 | celadon pottery vase, suspension footbridge over calm bay |
| `pyeongchang.png` | 평창 | 대관령 목장·산 | alpine sheep ranch on rolling green hills, windmill |
| `haenam.png` | 해남 | 땅끝마을·전망대 | lands-end viewpoint on coastal cliff, sunrise |
| `yeonggwang.png` | 영광 | 굴비·백수해안도로 | dried yellow croaker fish hanging, coastal road |
| `hoengseong.png` | 횡성 | 한우·계곡 | korean cattle grazing near valley stream |
| `yeongwol.png` | 영월 | 동강·별마로천문대 | river bend between cliffs, small observatory dome, starry sky |
| `jecheon.png` | 제천 | 청풍호·케이블카 | lake cable car over blue lake, mountains |
| `geochang.png` | 거창 | 수승대·산 계곡 | rocky river valley pavilion, forest |
| `gochang.png` | 고창 | 고인돌·청보리밭 | dolmen stones in green barley field |
| `yeongam.png` | 영암 | 월출산·F1 | rocky granite peaks, small racing circuit ribbon |
| `hapcheon.png` | 합천 | 해인사·황매산 | temple gate in mountains, royal azalea hill |
| `miryang.png` | 밀양 | 영남루·얼음골 | traditional pavilion by river, icy valley |
| `hadong.png` | 하동 | 녹차밭·섬진강 | green tea terraces along river |
| `namhae.png` | 남해 | 다랭이마을·독일마을 | terraced rice paddies on coastal slope, orange-roof village |
| `goheung.png` | 고흥 | 우주센터·유자 | small rocket launch tower by the sea, citron fruit |

## 제작 체크

- [ ] 1024×1024 PNG, 배경 흰색(카드 위에 얹힘)
- [ ] 톤 통일: 같은 세션/시드에서 연달아 생성 권장
- [ ] `flutter_app/assets/illust/region/`에 파일명대로 저장 → 빌드하면 자동 적용
- [ ] 관광지 일러스트는 백엔드 C·D 확정 후 2차 (지정관광지 목록 뽑아서 동일 방식)
