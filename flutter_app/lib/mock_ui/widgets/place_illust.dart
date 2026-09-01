import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 지정관광지 일러스트 — 장소 이름에서 유형을 뽑아 그 유형의 그림 한 장을 쓴다.
///
/// 관광지가 526곳이라 한 곳씩 그릴 수 없다. 한국 지명은 유형이 뒤에 붙어서
/// (월출산·대흥사·고창읍성) 이름만으로 유형이 거의 갈린다. 실제 운영 데이터
/// 526개를 이 규칙에 넣어보면 92%가 분류된다. 나머지는 default 한 장.
///
/// 분류 규칙 원본과 검증 스크립트는 docs/handoff-place-illust-2026-09-01.md 참고.

/// 파일이 실제로 들어온 키만 넣는다.
/// 없는 키를 넣으면 웹에서 404를 찍고 나서야 폴백이 뜨므로,
/// `assets/illust/place/`에 png를 넣은 뒤 여기에 키를 추가한다.
const Set<String> kAvailablePlaceIllusts = <String>{};

/// (키, 이름 어디에 있어도 인정하는 말, 이름 끝에 올 때만 인정하는 말)
///
/// 위에서부터 먼저 걸리는 쪽이 이긴다 — 좁은 유형을 위에 둔다.
/// 짧은 말을 접미사로만 보는 이유: '가지산 정상'의 '정'이 정자로,
/// '철도문화공원'의 '도'가 섬으로 잡히는 걸 막기 위해서다.
const List<(String, List<String>, List<String>)> _rules = [
  ('trail', [
    '둘레길', '산책로', '탐방로', '생태길', '누리길', '소리길', '바래길',
    '해안도로', '벚꽃길', '호수길', '연가길', '마루길', '방풍림', '십리',
    '슬로길', '둑방',
  ], []),
  ('sports', [
    '스포츠', '스포티움', '체육관', '골프', '컨트리클럽', '아리나',
    '올림픽플라자', '경기장', '레저', '카약', '패러글라이딩', '서프',
  ], []),
  ('cave', ['동굴', '터널'], ['굴']),
  ('healing', ['치유', '힐링', '케어팜', '멍스테이', '웰니스'], []),
  ('science', ['천문대', '과학관', '우주발사', '우주센터', '기상과학'], []),
  ('hanok', ['생가', '생가지', '고택', '고가', '종택', '종가', '가옥', '예담촌'], []),
  ('gallery', ['미술관', '갤러리', '예술관', '아트센터', '조각공원'], []),
  ('museum', ['박물관', '전시관', '유물관', '역사관', '기록관', '자료관', '뮤지엄'], []),
  ('memorial', ['기념관', '기념탑', '기념비', '추모', '호국원', '순교', '충혼', '대첩비'], []),
  ('culture', [
    '문화센터', '문화의집', '예술의전당', '예술의 전당', '국악당', '아트홀',
    '공연장', '예술회관', '웰컴센터', '커뮤니티센터', '라키비움', '청년센터', '판각',
  ], ['센터']),
  ('experience', ['체험', '학습관', '공방', '교육원', '숲체원'], []),
  ('observatory', ['전망대', '케이블카', '모노레일', '짚와이어', '스카이', '타워'], []),
  ('themepark', ['테마파크', '관광지', '랜드', '리조트', '놀이', '레포츠', '짚라인', '캠핑장'], []),
  ('forest', ['휴양림', '치유의숲', '숲길', '편백', '생태숲', '산림욕'], []),
  ('garden', ['수목원', '식물원', '정원', '창포원', '허브', '원림'], []),
  ('farm', ['목장', '양떼', '승마', '농원', '농장', '다원', '차밭', '염전', '과수원'], []),
  ('temple', ['사찰', '선원', '미륵', '성지'], ['사', '암', '암자', '대']),
  ('seowon', ['서원', '향교', '사당', '재실'], []),
  ('fortress', ['읍성', '산성', '성곽', '행궁', '관아', '동헌', '병영성'], []),
  ('heritage', ['고인돌', '지석묘', '고분', '왕릉', '석탑', '석불', '당간', '유적'], []),
  ('pavilion', ['정자', '누각'], ['정', '루', '각', '헌', '당']),
  ('village', ['마을', '민속촌', '한옥마을', '거리'], []),
  ('market', ['전통시장', '오일장', '장터'], ['시장']),
  ('beach', ['해수욕장', '해변', '백사장', '갯벌', '해안경관', '은모래'], []),
  ('island', ['군도', '무인도'], ['도', '섬']),
  ('bridge', ['출렁다리', '구름다리', '대교', '잠수교'], ['다리', '교']),
  ('valley', ['계곡', '폭포', '얼음골'], []),
  ('lake', ['저수지', '습지', '생태공원', '유원지'], ['호', '댐', '늪', '지']),
  ('park', ['공원', '광장', '쉼터'], []),
  ('mountain', ['등산', '능선', '바람언덕', '정상 표지석'], ['산', '봉', '악', '고개', '재', '령', '숲']),
];

/// 장소 이름 → 일러스트 키. 못 찾으면 null.
String? placeIllustKeyOf(String placeName) {
  final name = placeName.trim();
  if (name.isEmpty) return null;
  final head = name.split('(').first.trim(); // '백련사(강진)' → '백련사'
  for (final (key, anywhere, suffix) in _rules) {
    if (anywhere.any(name.contains)) return key;
    if (suffix.any(head.endsWith)) return key;
  }
  return null;
}

/// 지정관광지 썸네일. 일러스트가 아직 없으면 기존 📍 자리표시를 그대로 쓴다.
class PlaceIllust extends StatelessWidget {
  const PlaceIllust(
    this.placeName, {
    super.key,
    this.width = 128,
    this.height = 90,
    this.radius = 16,
    this.fontSize = 38,
  });

  final String placeName;
  final double width;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final key = placeIllustKeyOf(placeName);
    final asset = key != null && kAvailablePlaceIllusts.contains(key)
        ? key
        : (kAvailablePlaceIllusts.contains('default') ? 'default' : null);

    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.p50,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text('📍', style: TextStyle(fontSize: fontSize)),
    );
    if (asset == null) return fallback;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.p50,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset(
          'assets/illust/place/$asset.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
