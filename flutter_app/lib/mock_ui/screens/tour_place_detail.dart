import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../widgets/place_map_view.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// TourAPI 관광지 상세. contentId로 개요·운영정보를 실시간 조회 —
/// 있으면 소개·이용정보·지도, 없으면 이름·주소·지도만.
/// 코스 담기는 코스 편집의 장소 검색에서만 한다(여기선 보기 전용).
class TourPlaceDetailScreen extends StatefulWidget {
  const TourPlaceDetailScreen({
    super.key,
    required this.attraction,
    this.regionId,
  });

  final TourAttraction attraction;

  /// contentId가 없는 지정관광지 등은 이 지역에서 이름으로 TourAPI를 찾아 상세를 붙인다.
  final int? regionId;

  @override
  State<TourPlaceDetailScreen> createState() => _TourPlaceDetailScreenState();
}

class _TourPlaceDetailScreenState extends State<TourPlaceDetailScreen> {
  Future<TourPlaceDetail?>? _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = _resolveDetail();
    _initialized = true;
  }

  /// contentId가 있으면 바로 상세, 없으면(지정관광지) 이름으로 TourAPI를 찾아 contentId를 얻는다.
  Future<TourPlaceDetail?> _resolveDetail() async {
    final repo = AppScope.of(context).repository;
    final a = widget.attraction;
    String contentId = a.contentId;
    int contentTypeId = int.tryParse(a.contentTypeId) ?? 12;
    if (contentId.isEmpty && widget.regionId != null && a.title.isNotEmpty) {
      try {
        final results = await repo.getRegionAttractions(widget.regionId!, keyword: a.title);
        final exact = results.where((r) => _norm(r.title) == _norm(a.title));
        final picked = exact.isNotEmpty
            ? exact.first
            : (results.isNotEmpty ? results.first : null);
        if (picked != null) {
          contentId = picked.contentId;
          contentTypeId = int.tryParse(picked.contentTypeId) ?? 12;
        }
      } catch (_) {/* 못 찾으면 기본 정보만 */}
    }
    if (contentId.isEmpty) return null;
    return repo.getTourPlaceDetail(contentId, contentTypeId: contentTypeId);
  }

  String _norm(String s) => s.replaceAll(RegExp(r'\s+|\(.*\)'), '').trim();

  Future<void> _open(String url) async {
    if (url.trim().isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attraction;
    return DetailScaffold(
      title: '장소 정보',
      children: [
        // 헤더 (사진 없음)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.8)),
            const SizedBox(height: 4),
            Text(a.address,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            if (a.category.isNotEmpty) ...[
              const SizedBox(height: 12),
              Pill(a.category),
            ],
          ]),
        ),
        FutureBuilder<TourPlaceDetail?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final detail = snapshot.data;
            final overview = detail?.overview ?? '';
            final rows = detail?.infoRows ?? const <TourPlaceInfoRow>[];
            final homepage = detail?.homepageUrl ?? '';
            final lat = detail?.latitude ?? a.latitude;
            final lng = detail?.longitude ?? a.longitude;

            return Column(children: [
              if (overview.isNotEmpty)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('소개',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                    const SizedBox(height: 12),
                    Text(overview,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.7)),
                  ]),
                ),
              if (overview.isNotEmpty) const SizedBox(height: 16),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('이용 정보',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                  const SizedBox(height: 13),
                  if (rows.isEmpty && homepage.isEmpty) ...[
                    _InfoRow(Icons.place_outlined, '주소', a.address),
                    const SizedBox(height: 13),
                    const _InfoRow(Icons.info_outline_rounded, '안내', '운영시간·요금 등 상세 정보가 없어요.', muted: true),
                  ] else ...[
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 13),
                      _InfoRow(_iconFor(rows[i].label), rows[i].label, rows[i].value),
                    ],
                    if (homepage.isNotEmpty) ...[
                      if (rows.isNotEmpty) const SizedBox(height: 13),
                      _InfoRow(Icons.link_rounded, '홈페이지', '바로가기', link: true, onTap: () => _open(homepage)),
                    ],
                  ],
                ]),
              ),
              if (lat != null && lng != null) const SizedBox(height: 16),
              if (lat != null && lng != null)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('위치',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: PlaceMapView(
                        markers: [
                          PlaceMapMarkerData(
                            id: 1,
                            name: a.title,
                            address: a.address,
                            latitude: lat,
                            longitude: lng,
                            selected: false,
                          ),
                        ],
                        emptyMessage: '위치 정보가 없습니다.',
                        kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                        height: 170,
                      ),
                    ),
                  ]),
                ),
              if (detail != null) const SizedBox(height: 12),
              if (detail != null)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('출처: ⓒ한국관광공사',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  static IconData _iconFor(String label) {
    return switch (label) {
      '운영시간' || '영업시간' => Icons.schedule_rounded,
      '휴무일' => Icons.event_busy_rounded,
      '주차' => Icons.local_parking_rounded,
      '문의' => Icons.call_rounded,
      '대표메뉴' => Icons.restaurant_rounded,
      '체크인' => Icons.login_rounded,
      '체크아웃' => Icons.logout_rounded,
      '예약' => Icons.event_available_rounded,
      _ => Icons.info_outline_rounded,
    };
  }
}

/// 볼거리·맛집 행 (아이콘 없이 이름 + 카테고리 칩 + 주소). 탭 시 TourAPI 상세.
class TourAttractionRow extends StatelessWidget {
  const TourAttractionRow({super.key, required this.attraction});
  final TourAttraction attraction;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TourPlaceDetailScreen(attraction: attraction))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(attraction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                ),
                if (attraction.category.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.p100, borderRadius: BorderRadius.circular(999)),
                    child: Text(attraction.category,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.p700)),
                  ),
                ],
              ]),
              if (attraction.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(attraction.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink4),
        ]),
      ),
    );
  }
}

/// 볼거리·맛집 전체보기 — 그 지역 관광지(또는 맛집) 전량 리스트.
class TourAttractionListScreen extends StatelessWidget {
  const TourAttractionListScreen({super.key, required this.items, required this.type});
  final List<TourAttraction> items;
  final String type;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '이 지역 $type',
      children: [
        for (final a in items) TourAttractionRow(attraction: a),
        const Padding(
          padding: EdgeInsets.only(top: 4, right: 2),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('출처: ⓒ한국관광공사',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink4)),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value,
      {this.muted = false, this.link = false, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final bool link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: AppColors.p600),
        ),
        const SizedBox(width: 11),
        SizedBox(
          width: 62,
          child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5, height: 22 / 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: link ? AppColors.p600 : (muted ? AppColors.ink4 : AppColors.ink7),
                  height: 1.5)),
        ),
      ]),
    );
  }
}
