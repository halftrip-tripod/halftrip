# 🎨 지역·관광지 일러스트 제작 가이드 (규희)

> **확정 스타일(07-27):** 이소메트릭 미니 디오라마 (cute premium low-poly, cream 배경, 40° 카메라).
> **저장 경로:** 지역 `flutter_app/assets/illust/region/{키}.png` · 관광지 `.../place/{키}.png`
> 파일 있으면 이미지, 없으면 기존 이모지 폴백 → **일부만 만들어도 앱 안 깨짐.**

### ⚠️ 앱 연결 시 주의 (규희↔AI 확인용)
1. **비율:** 프롬프트는 `Square 1:1` → **카드 슬롯도 1:1로 맞춘다.** (지금 관광지 카드는 128×90 가로) 이미지 넣어 연결할 때 이미지 영역 `128×128`로 바꾸고 바깥 `SizedBox(height:148→약 180)`도 같이 키움 → `BoxFit.cover`로 안 잘리고 딱 맞음. ※ 관광지 카드는 `region_detail.dart`(준서 영역)라 이미지 연결하는 김에 한 번에 조정. 지역 히어로도 정사각으로.
2. **톤 통일:** 같은 세션/시드 연속 생성 or **확정 1장을 레퍼런스로 재투입**("같은 스타일 유지, 대상만 교체"). 컬렉션 전체가 한 세트로 보이는 게 핵심.
3. **pubspec:** `assets/illust/` 경로는 공유영역 → 등록/변경 시 단톡 공지.

---

# 지역 대표 일러스트 프롬프트

## 템플릿

```text
Create an isometric miniature diorama representing the identity of [REGION].

This is NOT a recreation of one specific location.
Instead, create a symbolic miniature that immediately communicates the region at a glance.

The scene should focus on the region's strongest and most recognizable identity.

PRIMARY ICONS (must dominate the composition)
- [Primary Landmark 1]
- [Primary Landmark 2]

SECONDARY ICONS (supporting elements)
- [Element 1]
- [Element 2]
- [Element 3]

BACKGROUND
- [Natural landscape]

SEASON
Represent the region in its most iconic season:
[Winter / Spring / Summer / Autumn]

Use the seasonal atmosphere consistently throughout the entire scene.

The primary landmarks should occupy roughly 70% of the visual attention.
Secondary elements should support the composition without competing.

Do not include unrelated architecture or generic scenery.

The entire scene should instantly communicate "[REGION]" even without text.

STYLE

Cute premium low-poly miniature diorama

Floating rounded-square base

Rounded corners

Fixed 40° isometric camera

Consistent proportions

Consistent object density

Simplified geometric modeling

Soft matte materials

Soft studio lighting

Subtle ambient occlusion

Gentle floating shadow

Clean silhouettes

Minimal details

Premium mobile app icon

Cream background

Centered composition

Square 1:1

No text

No border

High consistency across the entire regional icon collection.
```

---

# 예시 (평창)

```text
Create an isometric miniature diorama representing the identity of Pyeongchang County, South Korea.

This is NOT a recreation of one specific location.
Instead, create a symbolic miniature that immediately communicates the region at a glance.

The scene should focus on the region's strongest and most recognizable identity.

PRIMARY ICONS (must dominate the composition)
- Olympic Ski Jump Tower
- Snow-covered Taebaek Mountains

SECONDARY ICONS (supporting elements)
- Ski Slopes
- Evergreen Forest
- Daegwallyeong Sheep Ranch

BACKGROUND
- High alpine mountain landscape

SEASON
Represent the region in its most iconic season:
Winter

Use the seasonal atmosphere consistently throughout the entire scene.

The primary landmarks should occupy roughly 70% of the visual attention.
Secondary elements should support the composition without competing.

Do not include traditional villages, generic temples, rivers, beaches, or unrelated architecture.

The entire scene should instantly communicate "Pyeongchang" even without text.

STYLE

Cute premium low-poly miniature diorama

Floating rounded-square base

Rounded corners

Fixed 40° isometric camera

Consistent proportions

Consistent object density

Simplified geometric modeling

Soft matte materials

Soft studio lighting

Subtle ambient occlusion

Gentle floating shadow

Clean silhouettes

Minimal details

Premium mobile app icon

Cream background

Centered composition

Square 1:1

No text

No border

High consistency across the entire regional icon collection.
```

---

# 지정 관광지 일러스트 프롬프트

## 템플릿

```text
Create an isometric miniature diorama recreating the real-world landmark [LANDMARK].

This is a stylized recreation of the real landmark.

Preserve the landmark's recognizable architecture, layout, terrain, proportions, surrounding landscape, and signature visual features.

Do NOT redesign the landmark.
Do NOT invent new structures.
Only simplify the landmark into a cute premium low-poly miniature style while preserving its identity.

The landmark should immediately be recognizable even without text.

REQUIRED FEATURES
- [Feature 1]
- [Feature 2]
- [Feature 3]
- [Feature 4]

SURROUNDING ELEMENTS
- [Tree / Forest / Ocean / River / Cliff / Garden / Stone Path / etc.]

Keep the composition clean and balanced.

The main landmark should occupy roughly 70% of the visual attention.

The surrounding environment should enhance the landmark without overpowering it.

STYLE

Cute premium low-poly miniature diorama

Floating rounded-square base

Rounded corners

Fixed 40° isometric camera

Consistent proportions

Consistent object density

Simplified geometric modeling

Soft matte materials

Soft studio lighting

Subtle ambient occlusion

Gentle floating shadow

Clean silhouettes

Minimal details

Premium mobile app icon

Cream background

Centered composition

Square 1:1

No text

No border

High consistency across the entire regional icon collection.
```

---

# 예시 (다산초당)

```text
Create an isometric miniature diorama recreating the real-world landmark Dasan Chodang.

This is a stylized recreation of the real landmark.

Preserve the landmark's recognizable architecture, layout, terrain, proportions, surrounding landscape, and signature visual features.

Do NOT redesign the landmark.
Do NOT invent new structures.
Only simplify the landmark into a cute premium low-poly miniature style while preserving its identity.

The landmark should immediately be recognizable even without text.

REQUIRED FEATURES
- Traditional Hanok
- Dense Bamboo Forest
- Stone Pathway
- Tea Garden
- Memorial Stone
- Small Pavilion

SURROUNDING ELEMENTS
- Mountain Forest
- Small Stream
- Natural Rocks
- Trees
- Garden Landscape

Keep the composition clean and balanced.

The hanok should occupy roughly 70% of the visual attention.

The surrounding bamboo forest and landscape should enhance the landmark without overpowering it.

STYLE

Cute premium low-poly miniature diorama

Floating rounded-square base

Rounded corners

Fixed 40° isometric camera

Consistent proportions

Consistent object density

Simplified geometric modeling

Soft matte materials

Soft studio lighting

Subtle ambient occlusion

Gentle floating shadow

Clean silhouettes

Minimal details

Premium mobile app icon

Cream background

Centered composition

Square 1:1

No text

No border

High consistency across the entire regional icon collection.
```

---

# 작성 가이드

## 지역 대표 일러스트

작성해야 하는 항목

- REGION
- PRIMARY ICONS (2개)
- SECONDARY ICONS (3~5개)
- BACKGROUND
- SEASON

기준

- 지역을 가장 잘 대표하는 요소 선정
- 실제 장소 재현 X
- 지역 전체를 상징하는 미니어처 제작

---

## 지정 관광지 일러스트

작성해야 하는 항목

- LANDMARK
- REQUIRED FEATURES (4~6개)
- SURROUNDING ELEMENTS (3~5개)

기준

- 실제 관광지를 최대한 유지
- 구조 변경 X
- 특징 유지
- Low-poly 스타일로 단순화
- 주변 자연환경 함께 표현


