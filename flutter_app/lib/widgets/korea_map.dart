import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/app_models.dart';
import '../theme/app_colors.dart';

/// 전국지도 — 디자인: halftrip-design/home.html krmap.
/// 한국 실루엣(SVG) 위에 지역 핀을 시드 좌표(mapLeft/TopPercent)로 올린다.
/// 접수중 = 진한 하늘색 큰 핀, 오픈예정 = 연한 하늘색, 마감 = 회색 점.
class KoreaMap extends StatelessWidget {
  const KoreaMap({
    super.key,
    required this.regions,
    required this.onSelect,
    this.residenceLabel,
  });

  final List<RegionSummary> regions;
  final ValueChanged<RegionSummary> onSelect;

  /// 내 거주지 표기 (예: '서울'). null이면 거주지 핀 생략.
  final String? residenceLabel;

  // 디자인 krmap viewBox 비율 (544.8 × 1000).
  static const _aspect = 544.8 / 1000.0;

  // 주요 거주지(시/도)의 지도 좌표 % — 디자인 home.html 거주지 핀 기준.
  static const _residencePos = <String, Offset>{
    '서울': Offset(29.6, 19.0),
    '경기': Offset(30.0, 21.0),
    '인천': Offset(21.0, 20.0),
    '강원': Offset(61.0, 16.0),
    '대전': Offset(41.0, 36.0),
    '부산': Offset(77.0, 57.0),
    '대구': Offset(66.0, 47.0),
    '광주': Offset(28.0, 63.0),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = width / _aspect;
            final residence = _residenceFor(residenceLabel);

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset(
                    'assets/map/krmap.svg',
                    width: width,
                    height: height,
                  ),
                  if (residence != null)
                    Positioned(
                      left: width * residence.dx / 100 - 10,
                      top: height * residence.dy / 100 - 10,
                      child: const _ResidencePin(),
                    ),
                  for (final region in regions)
                    _RegionPin(
                      region: region,
                      left: width * region.mapLeftPercent / 100,
                      top: height * region.mapTopPercent / 100,
                      onTap: () => onSelect(region),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const _Legend(),
      ],
    );
  }

  Offset? _residenceFor(String? label) {
    if (label == null || label.trim().isEmpty) return null;
    for (final entry in _residencePos.entries) {
      if (label.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

class _RegionPin extends StatelessWidget {
  const _RegionPin({
    required this.region,
    required this.left,
    required this.top,
    required this.onTap,
  });

  final RegionSummary region;
  final double left;
  final double top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = region.statusCode.toUpperCase();
    final applying = status == 'APPLYING';
    final closed = status == 'CLOSED';
    final dotSize = applying ? 26.0 : (closed ? 12.0 : 20.0);
    final color = applying
        ? AppColors.p500
        : (closed ? const Color(0xFFA3B2C2) : const Color(0xFF5CC4EE));

    return Positioned(
      left: left - 26,
      top: top - dotSize / 2,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: closed ? 1.5 : 2.5),
                  boxShadow: closed
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x660284C7),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: closed
                    ? null
                    : const Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: SizedBox(width: 6, height: 6),
                        ),
                      ),
              ),
              if (!closed) ...[
                const SizedBox(height: 2),
                Text(
                  region.name,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: applying ? 12 : 11,
                    fontWeight: FontWeight.w900,
                    color: applying
                        ? const Color(0xFF0F2A3E)
                        : const Color(0xFF1F7BB0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResidencePin extends StatelessWidget {
  const _ResidencePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.coral, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33D9534F), blurRadius: 7, offset: Offset(0, 3)),
        ],
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.coralDeep,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink5,
              ),
            ),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(AppColors.p500, '접수중'),
        const SizedBox(width: 14),
        dot(const Color(0xFF5CC4EE), '오픈예정'),
        const SizedBox(width: 14),
        dot(const Color(0xFFA3B2C2), '마감'),
        const SizedBox(width: 14),
        dot(AppColors.coral, '내 거주지'),
      ],
    );
  }
}
