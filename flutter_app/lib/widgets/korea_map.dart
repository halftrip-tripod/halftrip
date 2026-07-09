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

  // 지역 핀 좌표 — 디자인 home.html krmap viewBox(544.8×1000) 기준.
  // 시드의 mapLeft/TopPercent는 옛 지도용이라 실루엣과 안 맞아 디자인 좌표를 우선한다.
  static const _regionPos = <String, Offset>{
    '평창': Offset(368.8, 226.1),
    '횡성': Offset(330.0, 224.0),
    '영월': Offset(379.1, 260.6),
    '제천': Offset(339.4, 269.7),
    '거창': Offset(298.1, 531.5),
    '고창': Offset(119.9, 578.7),
    '합천': Offset(336.4, 553.3),
    '영광': Offset(91.9, 606.0),
    '밀양': Offset(421.8, 566.0),
    '영암': Offset(119.9, 693.2),
    '하동': Offset(274.5, 644.2),
    '강진': Offset(130.2, 722.3),
    '남해': Offset(295.2, 686.0),
    '해남': Offset(105.1, 735.0),
    '고흥': Offset(205.3, 727.8),
    '완도': Offset(127.2, 782.3),
  };

  // 도·광역시 라벨 — 디자인 SVG <text> 좌표 (flutter_svg가 text 미지원이라 오버레이).
  static const _provinceLabels = <(String, Offset)>[
    ('서울', Offset(162.2, 191.1)),
    ('경기', Offset(163.9, 203.7)),
    ('강원', Offset(331.8, 158.2)),
    ('충북', Offset(290.9, 343.8)),
    ('충남', Offset(132.5, 377.6)),
    ('전북', Offset(171.1, 526.2)),
    ('전남', Offset(149.1, 681.5)),
    ('경북', Offset(396.3, 432.8)),
    ('경남', Offset(363.2, 613.9)),
    ('제주', Offset(117.7, 947.5)),
  ];

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
                  // 도·광역시 이름
                  for (final (label, pos) in _provinceLabels)
                    Positioned(
                      left: width * pos.dx / 544.8 - 30,
                      top: height * pos.dy / 1000 - (width * 0.022),
                      child: SizedBox(
                        width: 60,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: width * 24 / 544.8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9DB4C8),
                          ),
                        ),
                      ),
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
                      left: width * _xOf(region) / 100,
                      top: height * _yOf(region) / 100,
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

  /// 디자인 좌표 우선, 없으면 시드 percent 폴백.
  double _xOf(RegionSummary r) {
    final pos = _regionPos[r.name];
    return pos != null ? pos.dx / 544.8 * 100 : r.mapLeftPercent.toDouble();
  }

  double _yOf(RegionSummary r) {
    final pos = _regionPos[r.name];
    return pos != null ? pos.dy / 1000 * 100 : r.mapTopPercent.toDouble();
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
