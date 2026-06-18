import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
import 'region_action_screen.dart';
import 'region_course_builder_screen.dart';

enum _RegionFilter { all, applying, preparing, closed }

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
  _RegionFilter _selectedFilter = _RegionFilter.all;

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

  List<RegionSummary> _filtered(List<RegionSummary> regions) {
    return regions.where((region) {
      switch (_selectedFilter) {
        case _RegionFilter.all:
          return true;
        case _RegionFilter.applying:
          return region.statusCode.toUpperCase() == 'APPLYING';
        case _RegionFilter.preparing:
          return region.statusCode.toUpperCase() == 'PREPARING';
        case _RegionFilter.closed:
          return region.statusCode.toUpperCase() == 'CLOSED';
      }
    }).toList();
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

          final filtered = _filtered(data.regions);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 680 ? 3 : 2;
                final ratio = columns == 3 ? 0.9 : 0.84;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  children: [
                    _ResidenceHeader(user: data.user),
                    const SizedBox(height: 18),
                    const _PromoBanner(),
                    const SizedBox(height: 18),
                    _FilterRow(
                      regions: data.regions,
                      selected: _selectedFilter,
                      onChanged: (next) {
                        setState(() => _selectedFilter = next);
                      },
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (context, index) {
                        final region = filtered[index];
                        return _RegionCard(
                          region: region,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegionActionScreen(region: region),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    SectionCard(
                      title: '저장 코스',
                      subtitle: '저장해둔 여행 코스를 다시 열어보고 일정을 이어서 만들 수 있어요.',
                      child: _SavedCourses(courses: data.savedCourses),
                    ),
                  ],
                );
              },
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

class _ResidenceHeader extends StatelessWidget {
  const _ResidenceHeader({required this.user});

  final AppUser user;

  String _displayResidence(String residence) {
    final tokens = residence.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first.isEmpty) {
      return residence;
    }

    final primary = tokens.first;
    return primary
        .replaceAll('특별자치도', '')
        .replaceAll('특별자치시', '')
        .replaceAll('광역시', '')
        .replaceAll('특별시', '')
        .replaceAll('자치시', '')
        .replaceAll('자치도', '')
        .replaceAll('도', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final primaryResidence = _displayResidence(user.residence);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '내 거주지',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                primaryResidence,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                      letterSpacing: -1.3,
                    ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFD9E2EC)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text('변경'),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1FBF2), Color(0xFFF8FFF9)],
        ),
        border: Border.all(color: const Color(0xFFDDF3E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금, 반값여행을\n시작해보세요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1B8E4B),
                        height: 1.22,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '여행경비의 50%를 환급해드려요!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF334155),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: Color(0xFFD8E4DB)),
                    ),
                  ),
                  child: const Text('이용 방법 안내'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const SizedBox(
            width: 144,
            height: 144,
            child: _PromoIllustration(),
          ),
        ],
      ),
    );
  }
}

class _PromoIllustration extends StatelessWidget {
  const _PromoIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 10,
          left: 6,
          child: _accentChip(
            angle: -0.24,
            color: const Color(0xFF56C78A),
            width: 28,
            height: 16,
          ),
        ),
        Positioned(
          right: 0,
          top: 24,
          child: _accentChip(
            angle: 0.22,
            color: const Color(0xFFF6B27F),
            width: 24,
            height: 15,
          ),
        ),
        Positioned(
          left: 0,
          bottom: 12,
          child: _accentChip(
            angle: -0.08,
            color: const Color(0xFF9EDAB0),
            width: 20,
            height: 20,
            borderRadius: 8,
            icon: Icons.park_rounded,
          ),
        ),
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD9F0DF), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/card/card.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        const Color(0xFFDAF2E1).withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accentChip({
    required double angle,
    required Color color,
    required double width,
    required double height,
    double borderRadius = 6,
    IconData? icon,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: icon == null
            ? null
            : Icon(
                icon,
                size: 12,
                color: Colors.white,
              ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.regions,
    required this.selected,
    required this.onChanged,
  });

  final List<RegionSummary> regions;
  final _RegionFilter selected;
  final ValueChanged<_RegionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final counts = <_RegionFilter, int>{
      _RegionFilter.all: regions.length,
      _RegionFilter.applying:
          regions.where((e) => e.statusCode.toUpperCase() == 'APPLYING').length,
      _RegionFilter.preparing:
          regions.where((e) => e.statusCode.toUpperCase() == 'PREPARING').length,
      _RegionFilter.closed:
          regions.where((e) => e.statusCode.toUpperCase() == 'CLOSED').length,
    };

    return Row(
      children: [
        for (final filter in _RegionFilter.values) ...[
          Expanded(
            child: _FilterChip(
              label: _filterLabel(filter),
              count: counts[filter] ?? 0,
              selected: filter == selected,
              onTap: () => onChanged(filter),
            ),
          ),
          if (filter != _RegionFilter.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF111827) : const Color(0xFFDCE4EC),
          ),
          boxShadow: selected
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            '$label $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.onTap,
  });

  final RegionSummary region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = region.mockBudgetRemaining.clamp(0, 100);
    final tone = _budgetTone(remaining);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7EDF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _regionEmoji(region.name),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF111827),
                                    letterSpacing: -0.8,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          region.province,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF7C8798),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatusBadge(statusCode: region.statusCode),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '잔여 예산',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '$remaining%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: remaining / 100,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFEAEFF3),
                  valueColor: AlwaysStoppedAnimation<Color>(tone.$1),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tone.$2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tone.$3,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedCourses extends StatelessWidget {
  const _SavedCourses({required this.courses});

  final List<SavedCourse> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _EmptyBlock(message: '저장한 여행 코스가 없어요.');
    }

    return Column(
      children: courses.take(3).map((course) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
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
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: Color(0xFF0F766E),
                      ),
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${course.regionName} · ${course.stops.length}개 장소',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBF1)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF64748B),
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

String _filterLabel(_RegionFilter filter) {
  switch (filter) {
    case _RegionFilter.all:
      return '전체';
    case _RegionFilter.applying:
      return '접수중';
    case _RegionFilter.preparing:
      return '오픈예정';
    case _RegionFilter.closed:
      return '마감';
  }
}

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

(Color, String, Color) _budgetTone(int remaining) {
  if (remaining >= 60) {
    return (
      const Color(0xFF22B35E),
      '여유 있어요',
      const Color(0xFF1B8E4B),
    );
  }
  if (remaining >= 35) {
    return (
      const Color(0xFFF5A623),
      '서둘러 확인해보세요',
      const Color(0xFFB87200),
    );
  }
  return (
    const Color(0xFFEF4444),
    '마감이 가까워요',
    const Color(0xFFB91C1C),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusCode});

  final String statusCode;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    switch (statusCode.toUpperCase()) {
      case 'APPLYING':
        background = const Color(0xFFE9F9EE);
        foreground = const Color(0xFF16A34A);
        label = '접수중';
        break;
      case 'PREPARING':
        background = const Color(0xFFF4F7FB);
        foreground = const Color(0xFF64748B);
        label = '오픈예정';
        break;
      default:
        background = const Color(0xFFF4F5F7);
        foreground = const Color(0xFF6B7280);
        label = '마감';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: background.withValues(alpha: 0.95)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
