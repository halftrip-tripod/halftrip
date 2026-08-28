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

  // 지역 실제 위경도 (군청 소재지 기준) — _project()로 지도 좌표에 투영한다.
  static const _regionLatLng = <String, (double, double)>{
    '평창': (37.370, 128.390),
    '횡성': (37.492, 127.985),
    '영월': (37.184, 128.462),
    '제천': (37.133, 128.191),
    '거창': (35.687, 127.909),
    '고창': (35.436, 126.702),
    '합천': (35.567, 128.166),
    '영광': (35.277, 126.512),
    '밀양': (35.504, 128.747),
    '영암': (34.800, 126.697),
    '하동': (35.067, 127.751),
    '강진': (34.642, 126.767),
    '남해': (34.838, 127.893),
    '해남': (34.573, 126.599),
    '고흥': (34.611, 127.285),
    '완도': (34.311, 126.755),
    '화천': (38.106, 127.708),
    '영천': (35.973, 128.938),
    '함양': (35.520, 127.725),
    '산청': (35.415, 127.873),
    '고성': (34.973, 128.322), // 경남 고성
    '안동': (36.568, 128.729),
    '서천': (36.080, 126.691),
    '태안': (36.745, 126.298),
    '장흥': (34.681, 126.907),
  };

  /// 실제 위경도 → krmap viewBox(544.8×1000) 좌표.
  /// 지도 SVG가 실지리 기반이라 서울·강진 앵커로 선형 보정하면 1px 내로 맞는다.
  static Offset _project(double lat, double lng) => Offset(
        161.1 + 146.4 * (lng - 126.978),
        189.7 - 182.1 * (lat - 37.567),
      );

  // 도·광역시 라벨 — 디자인 SVG <text> 좌표 (flutter_svg가 text 미지원이라 오버레이).
  static const _provinceLabels = <(String, Offset)>[
    ('서울', Offset(138.0, 176.0)),
    ('경기', Offset(196.0, 218.0)),
    ('강원', Offset(331.8, 158.2)),
    ('충북', Offset(290.9, 343.8)),
    ('충남', Offset(132.5, 377.6)),
    ('전북', Offset(171.1, 526.2)),
    ('전남', Offset(149.1, 681.5)),
    ('경북', Offset(396.3, 432.8)),
    ('경남', Offset(363.2, 613.9)),
    ('제주', Offset(117.7, 947.5)),
  ];

  // 주요 거주지(시/도청 소재지) 실제 위경도.
  static const _residenceLatLng = <String, (double, double)>{
    '서울': (37.567, 126.978),
    '경기': (37.263, 127.029),
    '인천': (37.456, 126.705),
    '강원': (37.881, 127.730),
    '대전': (36.351, 127.385),
    '세종': (36.480, 127.289),
    '충북': (36.635, 127.491),
    '충남': (36.659, 126.673),
    '전북': (35.820, 127.109),
    '전남': (34.816, 126.463),
    '경북': (36.576, 128.506),
    '경남': (35.238, 128.692),
    '부산': (35.180, 129.075),
    '대구': (35.871, 128.601),
    '광주': (35.160, 126.851),
    '울산': (35.539, 129.311),
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

  /// 실좌표 투영 우선, 없으면 시드 percent 폴백. (% 단위 반환)
  double _xOf(RegionSummary r) {
    final latLng = _regionLatLng[r.name];
    if (latLng == null) return r.mapLeftPercent.toDouble();
    return _project(latLng.$1, latLng.$2).dx / 544.8 * 100;
  }

  double _yOf(RegionSummary r) {
    final latLng = _regionLatLng[r.name];
    if (latLng == null) return r.mapTopPercent.toDouble();
    return _project(latLng.$1, latLng.$2).dy / 1000 * 100;
  }

  Offset? _residenceFor(String? label) {
    if (label == null || label.trim().isEmpty) return null;
    for (final entry in _residenceLatLng.entries) {
      if (label.contains(entry.key)) {
        final pos = _project(entry.value.$1, entry.value.$2);
        return Offset(pos.dx / 544.8 * 100, pos.dy / 1000 * 100);
      }
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
              const SizedBox(height: 2),
              Text(
                region.name,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: applying ? 12 : (closed ? 9.5 : 11),
                  fontWeight: closed ? FontWeight.w700 : FontWeight.w900,
                  color: applying
                      ? const Color(0xFF0F2A3E)
                      : (closed
                          ? const Color(0xFF8A99AB)
                          : const Color(0xFF1F7BB0)),
                ),
              ),
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
