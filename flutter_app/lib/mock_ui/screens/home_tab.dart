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
    return _HomeData(residence: user.residence, regions: eligible);
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;

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
              if (_pane == 0) _MapPane(regions: data.regions),
              if (_pane == 1) ...[
                for (final r in applying) ...[_UrgCard(region: r), const SizedBox(height: 14)],
                if (applying.isEmpty) const _EmptyBlock(message: '지금 접수 중인 지역이 없어요.'),
              ],
              if (_pane == 2) ...[
                for (final r in preparing) ...[_SoonRow(region: r), const SizedBox(height: 10)],
                if (preparing.isEmpty) const _EmptyBlock(message: '오픈 예정인 지역이 없어요.'),
              ],
              const SizedBox(height: 10),
              // 저장 코스 (아직 목업 — 코스 탭 API 연동은 별도 작업)
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
  const _HomeData({required this.residence, required this.regions});
  final String residence;
  final List<RegionSummary> regions;
}

void _openRegion(BuildContext context, RegionSummary region) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region: region)));
}

class _MapPane extends StatelessWidget {
  const _MapPane({required this.regions});
  final List<RegionSummary> regions;

  @override
  Widget build(BuildContext context) {
    final applying = regions.where((r) => r.statusCode.toUpperCase() == 'APPLYING').length;
    final preparing = regions.where((r) => r.statusCode.toUpperCase() == 'PREPARING').length;

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
          return SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              SvgPicture.asset('assets/brand/krmap.svg', width: w, height: h),
              for (final r in regions)
                Positioned(
                  left: px(pinOffset(r)) - 26,
                  top: py(pinOffset(r)) - (r.statusCode.toUpperCase() == 'APPLYING' ? 13 : 10),
                  child: GestureDetector(
                    onTap: () => _openRegion(context, r),
                    child: SizedBox(
                      width: 52,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: r.statusCode.toUpperCase() == 'APPLYING' ? 26 : 20,
                          height: r.statusCode.toUpperCase() == 'APPLYING' ? 26 : 20,
                          decoration: BoxDecoration(
                            color: r.statusCode.toUpperCase() == 'APPLYING'
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
            ]),
          );
        }),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(AppColors.p500, '접수중 $applying'),
          const SizedBox(width: 14),
          _legend(AppColors.p300, '오픈예정 $preparing'),
          const SizedBox(width: 14),
          _legend(AppColors.gray, '마감'),
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

/// 접수중 지역 카드 (urg) — 조건 요약 + 잔여 예산 + 즐겨찾기.
class _UrgCard extends StatelessWidget {
  const _UrgCard({required this.region});
  final RegionSummary region;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isFavorite =
        controller.currentUser?.favoriteRegions.any((f) => f.id == region.id) ?? false;
    final dday = _mockDday[region.name];

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

/// 오픈예정 "+관심" — 백엔드에 지역별 알림 신청 API가 없어서 세션 동안만 유지되는
/// 임시 로컬 상태(재방문 시 초기화됨). API 생기면 이 맵은 지우고 컨트롤러로 교체.
final Map<int, ValueNotifier<bool>> _preopenInterestNotifiers = {};

ValueNotifier<bool> _preopenInterestFor(int regionId) =>
    _preopenInterestNotifiers.putIfAbsent(regionId, () => ValueNotifier(false));

/// 오픈예정 행 (+ 관심 = 오픈 알림).
class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.region});
  final RegionSummary region;

  @override
  Widget build(BuildContext context) {
    final interest = _preopenInterestFor(region.id);

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
          ValueListenableBuilder(
            valueListenable: interest,
            builder: (_, on, __) => GestureDetector(
              onTap: () {
                interest.value = !on;
                showMock(context,
                    on ? '${region.name} 관심 등록을 해제했어요.' : '${region.name}을(를) 관심 지역에 담았어요. 오픈하면 알려드릴게요!');
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

/// 실제 위경도 → krmap.svg viewBox(544.8×1000) 좌표. 서울·강진 앵커로 선형 보정.
Offset _projectLatLng(double lat, double lng) => Offset(
      161.1 + 146.4 * (lng - 126.978),
      189.7 - 182.1 * (lat - 37.567),
    );

/// 임시 D-day 목업값 — 백엔드에 마감일 필드가 생기면 이 테이블은 지우고 실 데이터로 교체.
const _mockDday = <String, (int, bool)>{
  '평창': (2, true),
  '강진': (5, false),
  '영월': (3, false),
  '거창': (7, false),
  '고창': (11, false),
  '완도': (9, false),
  '제천': (12, false),
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
