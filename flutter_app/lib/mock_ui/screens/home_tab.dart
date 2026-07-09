import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'course_flow.dart';
import 'region_detail.dart';

/// S1-1 홈 메인 (대시보드).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _pane = 0; // 0 전국지도 / 1 접수중 / 2 오픈예정

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final open = s.regions.where((r) => r.status == RegionStatus.open).toList();
    final soon = s.regions.where((r) => r.status == RegionStatus.soon).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '지금 떠날 수 있는\n'),
                TextSpan(text: '반값여행', style: TextStyle(color: AppColors.p600)),
              ]),
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1.2, height: 1.25),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppShadows.soft,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.p600),
              const SizedBox(width: 5),
              Text(s.residence.split(' ').first,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink7)),
            ]),
          ),
        ]),
        const SizedBox(height: 22),
        SegChips(
          labels: ['전국지도', '접수중 ${open.length}', '오픈예정 ${soon.length}'],
          selected: _pane,
          onChanged: (i) => setState(() => _pane = i),
        ),
        const SizedBox(height: 14),
        if (_pane == 0) _MapPane(open: open.length, soon: soon.length),
        if (_pane == 1) ...[for (final r in open) ...[_UrgCard(region: r), const SizedBox(height: 14)]],
        if (_pane == 2) ...[for (final r in soon) ...[_SoonRow(region: r), const SizedBox(height: 10)]],
        const SizedBox(height: 10),
        // 저장 코스
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.bookmark_rounded, size: 19, color: AppColors.p600),
              SizedBox(width: 8),
              Text('저장 코스',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
            ]),
            const SizedBox(height: 14),
            SurfRow(
              icon: Icons.route_outlined,
              title: s.courses.first.title,
              subtitle: '${s.courses.first.region} · ${s.courses.first.placeCount}개 장소',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CourseSavedScreen())),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        // 커뮤니티 인기 코스
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.p600),
              const SizedBox(width: 8),
              const Text('인기 코스',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => AppState.I.tabRequest.value = 3,
                child: const Text('더보기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _PopCard(region: '완도', title: '하루 동선 짜는 법', likes: 18, onTap: () => _openPost(context))),
              const SizedBox(width: 12),
              Expanded(child: _PopCard(region: '영월', title: '숙박확인서 꿀팁', likes: 12, onTap: () => _openPost(context))),
            ]),
          ]),
        ),
      ],
    );
  }

  void _openPost(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(post: AppState.I.posts.first)));
  }
}

class _MapPane extends StatelessWidget {
  const _MapPane({required this.open, required this.soon});
  final int open;
  final int soon;

  /// 지역 핀 좌표 — 디자인 home.html krmap SVG(viewBox 544.8×1000) 기준.
  static const _pinPos = {
    '평창': Offset(368.8, 226.1),
    '제천': Offset(339.4, 269.7),
    '영월': Offset(379.1, 260.6),
    '거창': Offset(298.1, 531.5),
    '고창': Offset(119.9, 578.7),
    '강진': Offset(130.2, 722.3),
    '완도': Offset(168, 798),
  };
  static const _residencePos = Offset(161.1, 189.7);

  @override
  Widget build(BuildContext context) {
    final regions = AppState.I.regions.where((r) => _pinPos.containsKey(r.name));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(children: [
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 1000 / 544.8;
          double px(Offset o) => o.dx / 544.8 * w;
          double py(Offset o) => o.dy / 1000 * h;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              SvgPicture.asset('assets/brand/krmap.svg', width: w, height: h),
              // 내 거주지 핀
              Positioned(
                left: px(_residencePos) - 10,
                top: py(_residencePos) - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.coral, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x33D9534F), blurRadius: 7, offset: Offset(0, 3))],
                  ),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.coralDeep, shape: BoxShape.circle),
                  ),
                ),
              ),
              // 지역 핀 (탭 → 지역 상세)
              for (final r in regions)
                Positioned(
                  left: px(_pinPos[r.name]!) - 26,
                  top: py(_pinPos[r.name]!) - (r.status == RegionStatus.open ? 13 : 10),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RegionDetailScreen(region: r))),
                    child: SizedBox(
                      width: 52,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: r.status == RegionStatus.open ? 26 : 20,
                          height: r.status == RegionStatus.open ? 26 : 20,
                          decoration: BoxDecoration(
                            color: r.status == RegionStatus.open
                                ? AppColors.p500
                                : const Color(0xFF5CC4EE),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x660284C7), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: SizedBox(width: 6, height: 6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(r.name,
                            style: TextStyle(
                              fontSize: r.status == RegionStatus.open ? 12 : 11,
                              fontWeight: FontWeight.w900,
                              color: r.status == RegionStatus.open
                                  ? const Color(0xFF0F2A3E)
                                  : const Color(0xFF1F7BB0),
                            )),
                      ]),
                    ),
                  ),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(AppColors.p500, '접수중 $open'),
          const SizedBox(width: 14),
          _legend(AppColors.p300, '오픈예정 $soon'),
          const SizedBox(width: 14),
          _legend(AppColors.gray, '마감'),
          const SizedBox(width: 14),
          _legend(AppColors.coral, '내 거주지'),
        ]),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _legend(Color c, String label) => Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]);
}

/// 접수중 지역 카드 (urg).
class _UrgCard extends StatelessWidget {
  const _UrgCard({required this.region});
  final Region region;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region: region))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EmojiBox(region.emoji, size: 52, fontSize: 26, radius: 15),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(region.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
              const SizedBox(width: 7),
              Text(region.province,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: region.favorite,
                builder: (_, fav, _) => GestureDetector(
                  onTap: () => AppState.I.toggleFavorite(region),
                  child: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22, color: fav ? AppColors.warning : AppColors.ink4),
                ),
              ),
            ]),
            const SizedBox(height: 7),
            Text(region.condition,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            if (region.mintBenefit) ...[
              const SizedBox(height: 7),
              const Row(children: [Pill('디민증 중복혜택', tone: PillTone.mint)]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              DdayChip(region.ddayWarn ? '마감 임박 D-${region.dday}' : '마감 D-${region.dday}',
                  warn: region.ddayWarn),
              const Spacer(),
              const Text('신청 정보 보기',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
              const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.p600),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// 오픈예정 행 (+ 관심).
class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.region});
  final Region region;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region: region))),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: AppShadows.soft,
          ),
          child: Text(region.emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${region.name} · ${region.province}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
            const SizedBox(height: 2),
            Text('${region.openLabel} · D-${region.dday}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
          ]),
        ),
        ValueListenableBuilder(
          valueListenable: region.favorite,
          builder: (_, fav, _) => GestureDetector(
            onTap: () {
              AppState.I.toggleFavorite(region);
              showMock(context,
                  fav ? '${region.name} 관심 등록을 해제했어요.' : '${region.name}을(를) 관심 지역에 담았어요. 오픈하면 알려드릴게요!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: fav ? AppColors.p100 : AppColors.p500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(fav ? '관심 ✓' : '+ 관심',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fav ? AppColors.p700 : Colors.white)),
            ),
          ),
        ),
      ]),
      ),
    );
  }
}

class _PopCard extends StatelessWidget {
  const _PopCard({required this.region, required this.title, required this.likes, required this.onTap});
  final String region;
  final String title;
  final int likes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pill(region),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink9, height: 1.35)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.favorite_rounded, size: 13, color: AppColors.ink4),
            const SizedBox(width: 5),
            Text('$likes',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
          ]),
        ]),
      ),
    );
  }
}
