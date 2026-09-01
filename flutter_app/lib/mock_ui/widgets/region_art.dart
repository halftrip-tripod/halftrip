import 'package:flutter/material.dart';

import '../screens/my_trips_tab.dart' show regionEmojiOf;
import 'ui.dart';

/// 지역 대표 이미지 — 지역 마그넷(assets/magnet/{키}.png)이 있으면 쓰고,
/// 없으면 이모지 폴백.
///
/// 마그넷은 홈 지도의 "다녀온 지역" 도장과 같은 자산이다. 지도·지역 목록·여행
/// 카드가 같은 그림을 쓰게 해서 지역 상징을 한 벌로 통일한다.
class RegionArt extends StatelessWidget {
  const RegionArt(
    this.regionName, {
    super.key,
    this.size = 48,
    this.fontSize = 24,
    this.radius = 15,
  });

  final String regionName;
  final double size;
  final double fontSize;
  final double radius;

  /// 여기에 있는 지역만 마그넷을 그린다. 파일이 없는 키를 넣으면 웹에서 404를
  /// 찍고 나서야 폴백이 뜨므로, 자산을 넣은 뒤에 키를 추가한다.
  /// (해남은 아직 마그넷이 없어 이모지로 남는다.)
  static const _magnetKeys = <String, String>{
    '강진': 'gangjin',
    '거창': 'geochang',
    '고성': 'goseong',
    '고창': 'gochang',
    '고흥': 'goheung',
    '남해': 'namhae',
    '밀양': 'miryang',
    '산청': 'sancheong',
    '서천': 'seocheon',
    '안동': 'andong',
    '영광': 'yeonggwang',
    '영암': 'yeongam',
    '영월': 'yeongwol',
    '영천': 'yeongcheon',
    '완도': 'wando',
    '장흥': 'jangheung',
    '제천': 'jecheon',
    '태안': 'taean',
    '평창': 'pyeongchang',
    '하동': 'hadong',
    '함양': 'hamyang',
    '합천': 'hapcheon',
    '화천': 'hwacheon',
    '횡성': 'hoengseong',
  };

  @override
  Widget build(BuildContext context) {
    final key = _magnetKeys[regionName];
    final fallback = EmojiBox(
      regionEmojiOf(regionName),
      size: size,
      fontSize: fontSize,
      radius: radius,
    );
    if (key == null) return fallback;
    return SizedBox(
      width: size,
      height: size,
      // 마그넷은 누끼 이미지라 배경 없이 그대로 올린다. 가로·세로 비율이
      // 제각각이라 contain으로 넣어야 잘리지 않는다.
      child: Image.asset(
        'assets/magnet/$key.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
