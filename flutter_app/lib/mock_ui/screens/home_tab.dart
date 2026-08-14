import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/mypage_screen.dart';
import '../../screens/notification_center_screen.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'course_flow.dart';
import 'my_trips_tab.dart' show stageOf, TripStageView;
import 'region_detail.dart';

/// S1-1 홈 메인 (대시보드).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _pane = 0; // 0 전국지도 / 1 접수중 / 2 오픈예정
  Future<_HomeData>? _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // 데이터 로딩(컨트롤러 notifyListeners 동반)을 첫 프레임 이후로 미뤄
    // 빌드 도중 markNeedsBuild 예외를 방지한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() { _future = _load(); });
    });
  }

  Future<_HomeData> _load() async {
    final controller = AppScope.of(context);
    final user = await controller.refreshCurrentUser();
    final regions = await controller.repository.getRegions(
      residence: user.residence,
    );
    final eligible = regions
        .where((r) => user.residence.trim().isEmpty || r.matchedByResidence)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    await controller.refreshTrips();
    final visitedRegionIds = controller.trips
        .where((t) =>
            stageOf(t) == TripStageView.settle || stageOf(t) == TripStageView.review)
        .map((t) => t.regionId)
        .toSet();
    return _HomeData(
      residence: user.residence,
      regions: eligible,
      visitedRegionIds: visitedRegionIds,
    );
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('화면을 불러오지 못했어요.\n${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final data = snapshot.data!;
        final applying =
            data.regions.where((r) => r.statusCode.toUpperCase() == 'APPLYING').toList();
        final preparing =
            data.regions.where((r) => r.statusCode.toUpperCase() == 'PREPARING').toList();
        final residenceLabel =
            data.residence.trim().isEmpty ? '미설정' : data.residence.split(' ').first;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              // 홈 헤더 개편(8/6 규희 확정): 로고 바는 홈 전용 + 리스트 안에 있어 스크롤 시 함께 사라짐.
              // 로고 ─ 여백 ─ [타이틀+접수 현황] 한 덩어리, 거주지 칩은 현황 줄 오른쪽.
              const _HomeTopBar(),
              const SizedBox(height: 12),
              const Text('어디로 떠날까요?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1.2, height: 1.05)),
              const SizedBox(height: 1),
              Row(children: [
                Text(
                  applying.isEmpty
                      ? '곧 오픈하는 지역을 확인해보세요'
                      : '지금 ${applying.length}개 지역이 접수 중이에요',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.p600),
                    const SizedBox(width: 5),
                    Text(residenceLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink7)),
                  ]),
                ),
              ]),
              const SizedBox(height: 9),
              SegChips(
                labels: ['전국지도', '접수중 ${applying.length}', '오픈예정 ${preparing.length}'],
                selected: _pane,
                onChanged: (i) => setState(() => _pane = i),
              ),
              const SizedBox(height: 14),
              if (_pane == 0)
                _MapPane(
                  regions: data.regions,
                  residence: data.residence,
                  visitedRegionIds: data.visitedRegionIds,
                ),
              if (_pane == 1) ...[
                for (final r in applying) ...[_UrgCard(region: r), const SizedBox(height: 14)],
                if (applying.isEmpty) const _EmptyBlock(message: '지금 접수 중인 지역이 없어요.'),
              ],
              if (_pane == 2) ...[
                for (final r in preparing) ...[_SoonRow(region: r), const SizedBox(height: 10)],
                if (preparing.isEmpty) const _EmptyBlock(message: '오픈 예정인 지역이 없어요.'),
              ],
              const SizedBox(height: 10),
              // 저장 코스 — 내 여행 보관함과 같은 소스(controller.savedCourses)를 쓴다.
              // 목업(AppState.courses)을 그리면 보관함은 0개인데 홈만 코스가 있는 것처럼 보인다.
              _SavedCourseCard(courses: AppScope.of(context).savedCourses),
              const SizedBox(height: 22),
              // 커뮤니티 인기 글 — 공개 글 좋아요순 상위 2개 (코스 태그 우선).
              if (_popularPosts().isNotEmpty)
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
                      for (final (i, p) in _popularPosts().indexed) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                            child: _PopCard(
                                region: p.region,
                                title: p.courseName ?? p.text,
                                likes: p.likes,
                                onTap: () => _openPost(context, p))),
                      ],
                    ]),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 공개 글 좋아요순 상위 2개 — 코스 첨부/코스 태그 글 우선.
  List<Post> _popularPosts() {
    final public = AppState.I.posts.where((p) => !p.private).toList();
    int weight(Post p) => (p.courseName != null || p.tag == PostTag.course) ? 1 : 0;
    public.sort((a, b) {
      final byCourse = weight(b).compareTo(weight(a));
      return byCourse != 0 ? byCourse : b.likes.compareTo(a.likes);
    });
    return public.take(2).toList();
  }

  void _openPost(BuildContext context, Post post) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(post: post)));
  }
}

class _HomeData {
  const _HomeData({
    required this.residence,
    required this.regions,
    required this.visitedRegionIds,
  });
  final String residence;
  final List<RegionSummary> regions;
  final Set<int> visitedRegionIds;
}

void _openRegion(BuildContext context, RegionSummary region) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region: region)));
}

class _MapPane extends StatelessWidget {
  const _MapPane({
    required this.regions,
    required this.residence,
    required this.visitedRegionIds,
  });
  final List<RegionSummary> regions;
  final String residence;
  final Set<int> visitedRegionIds;

  /// 거주지("시도 시군구") 문자열의 시/도 부분을 시/도청 위경도로 투영.
  Offset? _residenceOffset() {
    final province = residence.trim().split(' ').first;
    final latLng = _provinceLatLng[province];
    if (latLng == null) return null;
    return _projectLatLng(latLng.$1, latLng.$2);
  }

  @override
  Widget build(BuildContext context) {
    final applying = regions.where((r) => r.statusCode.toUpperCase() == 'APPLYING').length;
    final preparing = regions.where((r) => r.statusCode.toUpperCase() == 'PREPARING').length;
    final meOffset = _residenceOffset();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(children: [
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 1000 / 544.8;
          // 백엔드 mapTopPercent/mapLeftPercent는 시드용 폴백이라 정확도가 낮음(lib/widgets/korea_map.dart 참고).
          // 실제 위경도를 서울·강진 기준으로 투영해서 krmap.svg 좌표(544.8×1000)를 구한다.
          Offset pinOffset(RegionSummary r) {
            final latLng = _regionLatLng[r.name];
            if (latLng == null) {
              return Offset(r.mapLeftPercent / 100 * 544.8, r.mapTopPercent / 100 * 1000);
            }
            return _projectLatLng(latLng.$1, latLng.$2);
          }

          double px(Offset o) => o.dx / 544.8 * w;
          double py(Offset o) => o.dy / 1000 * h;

          // 완도·강진처럼 가까운 지역은 이름표가 서로 겹쳐 아예 읽을 수 없다.
          // 이미 놓인 이름표와 부딪히면 그 핀의 이름표만 아래로 한 칸씩 내린다.
          const labelStep = 15.0;
          final labelShift = <int, double>{};
          final placedLabels = <Offset>[];
          for (final r in regions) {
            final o = Offset(px(pinOffset(r)), py(pinOffset(r)));
            var shift = 0.0;
            while (placedLabels.any((p) =>
                (p.dx - o.dx).abs() < 58 &&
                (p.dy - (o.dy + shift)).abs() < labelStep)) {
              shift += labelStep;
            }
            labelShift[r.id] = shift;
            placedLabels.add(Offset(o.dx, o.dy + shift));
          }

          return SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              SvgPicture.asset('assets/brand/krmap.svg', width: w, height: h),
              // 내 지역(거주지) 핀 — 코랄. 시/도 대표 좌표 기준.
              if (_residenceLatLng[residence.split(' ').first] != null)
                Positioned(
                  left: px(_projectLatLng(
                          _residenceLatLng[residence.split(' ').first]!.$1,
                          _residenceLatLng[residence.split(' ').first]!.$2)) -
                      26,
                  top: py(_projectLatLng(
                          _residenceLatLng[residence.split(' ').first]!.$1,
                          _residenceLatLng[residence.split(' ').first]!.$2)) -
                      11,
                  child: SizedBox(
                    width: 52,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66D9534F), blurRadius: 6, offset: Offset(0, 2)),
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
                      const Text('내 지역',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.coralDeep,
                          )),
                    ]),
                  ),
                ),
              for (final r in regions)
                Positioned(
                  left: px(pinOffset(r)) - 45,
                  top: py(pinOffset(r)) - (r.statusCode.toUpperCase() == 'APPLYING' ? 13 : 10),
                  child: GestureDetector(
                    onTap: () => _openRegion(context, r),
                    child: SizedBox(
                      width: 90,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _RegionPinDot(
                          applying: r.statusCode.toUpperCase() == 'APPLYING',
                          visited: visitedRegionIds.contains(r.id),
                        ),
                        SizedBox(height: 2 + (labelShift[r.id] ?? 0)),
                        // 좁은 상자에 가두면 "태백 샘플권/역"처럼 글자 중간에서 끊긴다.
                        Text(r.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.statusCode.toUpperCase() == 'APPLYING' ? 12 : 11,
                              fontWeight: FontWeight.w900,
                              color: r.statusCode.toUpperCase() == 'APPLYING'
                                  ? const Color(0xFF0F2A3E)
                                  : const Color(0xFF1F7BB0),
                            )),
                      ]),
                    ),
                  ),
                ),
              if (meOffset != null)
                Positioned(
                  left: px(meOffset) - 11,
                  top: py(meOffset) - 11,
                  child: const IgnorePointer(
                    child: _MapDot(size: 22, color: AppColors.coral),
                  ),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(AppColors.p500, '접수중 $applying'),
            _legend(AppColors.p300, '오픈예정 $preparing'),
            _legend(AppColors.gray, '마감'),
            _legend(AppColors.coral, '내 위치'),
            _legend(AppColors.coralDeep, '다녀온 지역'),
          ],
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]);
}

/// 지도 위 지역 핀 — 다녀온 지역(정산 신청 이상 단계)은 파란 점 대신 도장 표시.
class _RegionPinDot extends StatelessWidget {
  const _RegionPinDot({required this.applying, required this.visited});
  final bool applying;
  final bool visited;

  @override
  Widget build(BuildContext context) {
    final size = applying ? 26.0 : 20.0;
    if (visited) {
      return Transform.rotate(
        angle: -0.2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.coralTint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.coralDeep, width: 2.2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(Icons.star_rounded, size: size * 0.65, color: AppColors.coralDeep),
        ),
      );
    }
    return _MapDot(size: size, color: applying ? AppColors.p500 : const Color(0xFF5CC4EE));
  }
}

/// 지도 핀 공통 모양 — 색 테두리 원 + 흰 점(디자인 시안 halftrip-design/home.html과 동일 형태).
class _MapDot extends StatelessWidget {
  const _MapDot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
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
    );
  }
}

/// 접수중 지역 카드 (urg) — 조건 요약 + 잔여 예산 + 즐겨찾기.
class _UrgCard extends StatelessWidget {
  const _UrgCard({required this.region});
  final RegionSummary region;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isFavorite =
        controller.currentUser?.favoriteRegions.any((f) => f.id == region.id) ?? false;
    final dday = regionDday(region);

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      onTap: () => _openRegion(context, region),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EmojiBox(_regionEmoji(region.name), size: 52, fontSize: 26, radius: 15),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(region.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(region.province,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
              ),
              GestureDetector(
                onTap: () => controller.toggleFavoriteRegion(region),
                child: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 22, color: isFavorite ? AppColors.warning : AppColors.ink4),
              ),
            ]),
            const SizedBox(height: 7),
            Text(
              region.refundConditionAmount > 0
                  ? '최소 소비 ${_man(region.refundConditionAmount)} · 지정관광지 2곳 인증'
                  : '지정관광지 2곳 인증 · 1박 숙박',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5),
            ),
            if (region.digitalBenefitAvailable) ...[
              const SizedBox(height: 7),
              const Row(children: [Pill('디민증 중복혜택', tone: PillTone.mint)]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              DdayChip(
                dday == null ? '마감일 확인 필요' : (dday.$2 ? '마감 임박 D-${dday.$1}' : '마감 D-${dday.$1}'),
                warn: dday?.$2 ?? false,
              ),
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

/// 오픈예정 행 (+ 관심 = 오픈 알림 — 접수중 별표시와 동일한 즐겨찾기).
class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.region});
  final RegionSummary region;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final on =
        controller.currentUser?.favoriteRegions.any((f) => f.id == region.id) ??
            false;

    return GestureDetector(
      onTap: () => _openRegion(context, region),
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
            child: Text(_regionEmoji(region.name), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${region.name} · ${region.province}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
              const SizedBox(height: 2),
              const Text('오픈 예정 · 조건은 상세에서 미리 확인',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            ]),
          ),
          GestureDetector(
            onTap: () async {
              final wasEnabled = on;
              await controller.toggleFavoriteRegion(region);
              if (!context.mounted) return;
              showMock(context,
                  wasEnabled ? '${region.name} 관심 등록을 해제했어요.' : '${region.name}을(를) 관심 지역에 담았어요. 오픈하면 알려드릴게요!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: on ? AppColors.p100 : AppColors.p500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(on ? '관심 ✓' : '+ 관심',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.p700 : Colors.white)),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

/// 홈의 저장 코스 카드. 내 여행 보관함과 같은 목록을 본다.
class _SavedCourseCard extends StatelessWidget {
  const _SavedCourseCard({required this.courses});
  final List<SavedCourse> courses;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bookmark_rounded, size: 19, color: AppColors.p600),
          const SizedBox(width: 8),
          const Text('저장 코스',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
          const Spacer(),
          if (courses.isNotEmpty)
            Text('${courses.length}개',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ]),
        const SizedBox(height: 14),
        if (courses.isEmpty)
          const _EmptyBlock(message: '저장한 여행 코스가 없어요. 코스를 만들면 여기에 모여요.')
        else
          for (final course in courses.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfRow(
                icon: Icons.route_outlined,
                title: course.title,
                subtitle: '${course.regionName} · ${course.stops.length}개 장소',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CourseSavedScreen())),
              ),
            ),
      ]),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(18)),
      child: Text(message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
    );
  }
}

String _man(int amount) {
  if (amount % 10000 == 0) return '${amount ~/ 10000}만원';
  return '${(amount / 10000).toStringAsFixed(1)}만원';
}

/// 지역 실제 위경도(군청 소재지 기준) — lib/widgets/korea_map.dart와 동일 출처.
/// 백엔드 mapTopPercent/mapLeftPercent보다 정확해서 지도 핀 위치 계산에 이걸 우선 사용.
const _regionLatLng = <String, (double, double)>{
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
};

/// 거주지(시/도) 대표 위경도 — 내 지역 코랄 핀용.
const _residenceLatLng = <String, (double, double)>{
  '서울특별시': (37.567, 126.978),
  '인천광역시': (37.456, 126.705),
  '경기도': (37.289, 127.053),
  '대전광역시': (36.351, 127.385),
  '대구광역시': (35.871, 128.601),
  '부산광역시': (35.180, 129.075),
  '광주광역시': (35.160, 126.851),
  '울산광역시': (35.539, 129.311),
};

/// 실제 위경도 → krmap.svg viewBox(544.8×1000) 좌표. 서울·강진 앵커로 선형 보정.
Offset _projectLatLng(double lat, double lng) => Offset(
      161.1 + 146.4 * (lng - 126.978),
      189.7 - 182.1 * (lat - 37.567),
    );

/// 시/도청 소재지 위경도 — "내 위치" 마커는 거주지(residence, "시도 시군구" 형식)의
/// 시/도 부분만 이 표로 투영한다. 실제 GPS가 아니라 등록 거주지 기준.
const _provinceLatLng = <String, (double, double)>{
  '서울특별시': (37.5665, 126.9780),
  '부산광역시': (35.1796, 129.0756),
  '대구광역시': (35.8714, 128.6014),
  '인천광역시': (37.4563, 126.7052),
  '광주광역시': (35.1595, 126.8526),
  '대전광역시': (36.3504, 127.3845),
  '울산광역시': (35.5384, 129.3114),
  '세종특별자치시': (36.4800, 127.2890),
  '경기도': (37.2750, 127.0095),
  '강원특별자치도': (37.8228, 128.1555),
  '충청북도': (36.6357, 127.4917),
  '충청남도': (36.6588, 126.6728),
  '전북특별자치도': (35.8202, 127.1088),
  '전라남도': (34.8161, 126.4630),
  '경상북도': (36.5760, 128.5056),
  '경상남도': (35.2380, 128.6924),
  '제주특별자치도': (33.4996, 126.5312),
};


/// 지역별 이모지 — 백엔드에 없는 순수 장식용 값이라 클라이언트에서 고정 매핑.
String _regionEmoji(String regionName) {
  const map = <String, String>{
    '평창': '🏔️',
    '횡성': '🥩',
    '영월': '🌊',
    '제천': '⛰️',
    '거창': '🌿',
    '고창': '🏛️',
    '합천': '🌄',
    '영광': '🐟',
    '밀양': '🏞️',
    '영암': '🏎️',
    '하동': '🍃',
    '강진': '🍲',
    '남해': '🌴',
    '해남': '🌾',
    '고흥': '🚀',
    '완도': '🏝️',
  };
  return map[regionName] ?? '📍';
}


/// 홈 전용 상단 바 — 로고·알림(배지)·마이페이지. 스크롤에 함께 올라간다.
class _HomeTopBar extends StatefulWidget {
  const _HomeTopBar();

  @override
  State<_HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<_HomeTopBar> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
  }

  Future<void> _loadUnread() async {
    try {
      final controller = AppScope.of(context);
      final userId = controller.currentUser?.id;
      if (userId == null) return;
      final notifications = await controller.repository.getNotifications(userId);
      if (!mounted) return;
      setState(() => _unread = notifications.where((n) => !n.read).length);
    } catch (_) {
      // 배지는 부가 정보 — 실패해도 조용히 넘어간다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Image.asset('assets/logo/logo-3d-header.png', height: 40),
        const Spacer(),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          badge: _unread > 0,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => const NotificationCenterScreen()))
              .then((_) => _loadUnread()),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.person_outline_rounded,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyPageScreen())),
        ),
      ]),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap, this.badge = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.soft,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: 22, color: AppColors.ink7),
          if (badge)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
