import 'package:flutter/material.dart';

import '../screens/my_trips_tab.dart' show regionEmojiOf;
import 'ui.dart';

/// 지역 대표 이미지 — AI 일러스트(assets/illust/region/{키}.png)가 있으면 사용,
/// 없으면 기존 이모지 폴백. 일러스트는 docs/illustration-guide.md 규약으로 제작.
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

  static const _assetKeys = <String, String>{
    '완도': 'wando',
    '강진': 'gangjin',
    '평창': 'pyeongchang',
    '해남': 'haenam',
    '영광': 'yeonggwang',
    '횡성': 'hoengseong',
    '영월': 'yeongwol',
    '제천': 'jecheon',
    '거창': 'geochang',
    '고창': 'gochang',
    '영암': 'yeongam',
    '합천': 'hapcheon',
    '밀양': 'miryang',
    '하동': 'hadong',
    '남해': 'namhae',
    '고흥': 'goheung',
  };

  @override
  Widget build(BuildContext context) {
    final key = _assetKeys[regionName];
    final fallback = EmojiBox(
      regionEmojiOf(regionName),
      size: size,
      fontSize: fontSize,
      radius: radius,
    );
    if (key == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/illust/region/$key.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
