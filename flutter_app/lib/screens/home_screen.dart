import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../mock_ui/widgets/region_art.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/korea_map.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';
import '../widgets/ui/seg_chips.dart';
import 'region_action_screen.dart';
import 'region_course_builder_screen.dart';

/// 홈 대시보드 (S1-1) — 디자인: halftrip-design/home.html
/// 인사말 + 거주지 칩 + 뷰 전환(전국지도/접수중/오픈예정) + 저장 코스.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeDashboardData>? _future;
  bool _initialized = false;
  int _pane = 0; // 0 전국지도 / 1 접수중 / 2 오픈예정

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // 데이터 로딩(컨트롤러 notifyListeners 동반)을 첫 프레임 이후로 미뤄
    // 빌드 도중 markNeedsBuild 예외를 방지한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _future = _loadData();
      });
    });
  }

  Future<_HomeDashboardData> _loadData() async {
    final controller = AppScope.of(context);
    final user = await controller.refreshCurrentUser();
    final regions = await controller.repository.getRegions(
      residence: user.residence,
    );

    final eligible = regions
        .where(
          (region) =>
              user.residence.trim().isEmpty || region.matchedByResidence,
        )
        .toList()
      ..sort((a, b) {
        final priority =
            _statusPriority(a.statusCode).compareTo(_statusPriority(b.statusCode));
        if (priority != 0) return priority;
        return a.displayOrder.compareTo(b.displayOrder);
      });

    return _HomeDashboardData(
      user: user,
      regions: eligible,
      savedCourses: controller.savedCourses,
    );
  }

  Future<void> _refresh() async {
    await AppScope.of(context).refreshTrips();
    if (!mounted) return;
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  void _openRegion(RegionSummary region) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegionActionScreen(region: region)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return AppShell(
      title: '하프트립',
      modeName: controller.modeName,
      currentTabIndex: widget.currentTabIndex,
      onTabSelected: widget.onTabSelected,
      child: FutureBuilder<_HomeDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '화면을 불러오지 못했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('표시할 데이터가 없습니다.'));
          }

          final applying = data.regions
              .where((r) => r.statusCode.toUpperCase() == 'APPLYING')
              .toList();
          final preparing = data.regions
              .where((r) => r.statusCode.toUpperCase() == 'PREPARING')
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              children: [
                _Greeting(user: data.user),
                const SizedBox(height: 22),
                SegChips(
                  labels: [
                    '전국지도',
                    '접수중 ${applying.length}',
                    '오픈예정 ${preparing.length}',
                  ],
                  selected: _pane,
                  onChanged: (i) => setState(() => _pane = i),
                ),
                const SizedBox(height: 14),
                if (_pane == 0)
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: KoreaMap(
                      regions: data.regions,
                      residenceLabel: data.user.residence,
                      onSelect: _openRegion,
                    ),
                  ),
                if (_pane == 1) ...[
                  for (final region in applying) ...[
                    _ApplyingCard(region: region, onTap: () => _openRegion(region)),
                    const SizedBox(height: 14),
                  ],
                  if (applying.isEmpty)
                    const _EmptyBlock(message: '지금 접수 중인 지역이 없어요.'),
                ],
                if (_pane == 2) ...[
                  for (final region in preparing) ...[
                    _PreparingRow(region: region, onTap: () => _openRegion(region)),
                    const SizedBox(height: 10),
                  ],
                  if (preparing.isEmpty)
                    const _EmptyBlock(message: '오픈 예정인 지역이 없어요.'),
                ],
                const SizedBox(height: 10),
                _SavedCoursesCard(courses: data.savedCourses),
                const SizedBox(height: 22),
                _PopularCoursesCard(
                  onMore: () => widget.onTabSelected?.call(3),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeDashboardData {
  const _HomeDashboardData({
    required this.user,
    required this.regions,
    required this.savedCourses,
  });

  final AppUser user;
  final List<RegionSummary> regions;
  final List<SavedCourse> savedCourses;
}

/// 인사말 + 거주지 칩 (우측).
class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final residence = user.residence.trim().isEmpty
        ? '미설정'
        : user.residence.trim().split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '지금 떠날 수 있는\n'),
              TextSpan(text: '반값여행', style: TextStyle(color: AppColors.p600)),
            ]),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -1.2,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.p600),
              const SizedBox(width: 5),
              Text(
                residence,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 접수중 지역 카드 (디자인 .urg) — 조건 요약 + 잔여 예산 + 관심 토글.
class _ApplyingCard extends StatelessWidget {
  const _ApplyingCard({required this.region, required this.onTap});

  final RegionSummary region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isFavorite = controller.currentUser?.favoriteRegions
            .any((item) => item.id == region.id) ??
        false;
    final remaining = region.mockBudgetRemaining.clamp(0, 100);
    final urgent = remaining < 35;

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegionArt(region.name, size: 52, fontSize: 26, radius: 15),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      region.name,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink9,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        region.province,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.toggleFavoriteRegion(region),
                      child: Icon(
                        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 22,
                        color: isFavorite ? AppColors.warning : AppColors.ink4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  region.refundConditionAmount > 0
                      ? '최소 소비 ${_man(region.refundConditionAmount)} · 지정관광지 2곳 인증'
                      : '지정관광지 2곳 인증 · 1박 숙박',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5,
                  ),
                ),
                if (region.digitalBenefitAvailable) ...[
                  const SizedBox(height: 7),
                  const Row(children: [Pill('디민증 중복혜택', tone: PillTone.mint)]),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: urgent ? const Color(0xFFFEECEC) : AppColors.p100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            urgent ? Icons.local_fire_department_rounded : Icons.savings_outlined,
                            size: 14,
                            color: urgent ? AppColors.danger : AppColors.p700,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            urgent ? '잔여 예산 $remaining% · 마감 임박' : '잔여 예산 $remaining%',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: urgent ? AppColors.danger : AppColors.p700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '신청 정보 보기',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.p600,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.p600),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 오픈예정 행 (디자인 .row + 관심 버튼).
class _PreparingRow extends StatelessWidget {
  const _PreparingRow({required this.region, required this.onTap});

  final RegionSummary region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isFavorite = controller.currentUser?.favoriteRegions
            .any((item) => item.id == region.id) ??
        false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            RegionArt(region.name,
                size: 40, fontSize: 18, radius: 12, boxColor: Colors.white, shadow: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${region.name} · ${region.province}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '오픈 예정 · 조건은 상세에서 미리 확인',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink5,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                controller.toggleFavoriteRegion(region);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isFavorite
                      ? '${region.name} 관심 등록을 해제했어요.'
                      : '${region.name}을(를) 관심 지역에 담았어요. 오픈하면 알려드릴게요!'),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isFavorite ? AppColors.p100 : AppColors.p500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFavorite ? '관심 ✓' : '+ 관심',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isFavorite ? AppColors.p700 : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 저장 코스 카드 (디자인 .card + .row).
class _SavedCoursesCard extends StatelessWidget {
  const _SavedCoursesCard({required this.courses});

  final List<SavedCourse> courses;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bookmark_rounded, size: 19, color: AppColors.p600),
              SizedBox(width: 8),
              Text(
                '저장 코스',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (courses.isEmpty)
            const _EmptyBlock(message: '저장한 여행 코스가 없어요.')
          else
            for (final course in courses.take(3)) ...[
              _SavedCourseRow(course: course),
              if (course != courses.take(3).last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SavedCourseRow extends StatelessWidget {
  const _SavedCourseRow({required this.course});

  final SavedCourse course;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RegionCourseBuilderScreen(
              regionId: course.regionId,
              regionName: course.regionName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(Icons.route_outlined, size: 20, color: AppColors.p600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${course.regionName} · ${course.stops.length}개 장소',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
          ],
        ),
      ),
    );
  }
}

/// 커뮤니티 인기 코스 카드 — 디자인 home.html .pop (탭하면 커뮤니티 탭으로).
class _PopularCoursesCard extends StatelessWidget {
  const _PopularCoursesCard({required this.onMore});

  final VoidCallback onMore;

  static const _posts = [
    ('완도', '하루 동선 짜는 법', 18),
    ('영월', '숙박확인서 꿀팁', 12),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 19, color: AppColors.p600),
              const SizedBox(width: 8),
              const Text(
                '인기 코스',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onMore,
                child: const Text(
                  '더보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (region, title, likes) in _posts)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: region == _posts.last.$1 ? 0 : 12),
                    child: GestureDetector(
                      onTap: onMore,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surf,
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill(region),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink9,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 13, color: AppColors.ink4),
                                const SizedBox(width: 5),
                                Text(
                                  '$likes',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.ink5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 지역 이모지 박스.
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          color: AppColors.ink5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

int _statusPriority(String code) {
  switch (code.toUpperCase()) {
    case 'APPLYING':
      return 0;
    case 'PREPARING':
      return 1;
    default:
      return 2;
  }
}

String _man(int amount) {
  if (amount % 10000 == 0) return '${amount ~/ 10000}만원';
  return '${(amount / 10000).toStringAsFixed(1)}만원';
}

