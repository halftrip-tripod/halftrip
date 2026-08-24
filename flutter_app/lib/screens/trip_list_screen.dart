import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/trip_calendar_sheet.dart';
import '../widgets/ui/pill.dart';
import 'favorite_regions_screen.dart';
import 'past_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  Future<void> _refresh() async {
    await AppScope.of(context).refreshTrips();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final trips = controller.trips;
    final ongoing = trips.where((t) => !t.settlementApplied).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = trips.where((t) => t.settlementApplied).toList()
      ..sort((a, b) => b.endDate.compareTo(a.endDate));
    final savedCount = controller.savedCourses.length;
    final favoriteCount = controller.currentUser?.favoriteRegions.length ?? 0;

    return AppShell(
      title: '내 여행',
      modeName: controller.modeName,
      currentTabIndex: widget.currentTabIndex,
      onTabSelected: widget.onTabSelected,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            _PageHead(onAdd: _createTrip),
            const SizedBox(height: 18),
            const _SectionTitle('진행 중인 여행'),
            const SizedBox(height: 12),
            if (ongoing.isEmpty)
              _EmptyTrips(onAdd: _createTrip)
            else
              ...ongoing.map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _TripCard(
                    trip: trip,
                    onTap: () => _openDetail(trip.id),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const _SectionTitle('보관함'),
            const SizedBox(height: 12),
            _MenuRow(
              icon: Icons.bookmark_outline_rounded,
              label: '저장 코스',
              value: '$savedCount개',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('저장 코스함은 준비 중이에요.')),
                );
              },
            ),
            const SizedBox(height: 12),
            _MenuRow(
              icon: Icons.star_outline_rounded,
              label: '관심 지역',
              value: '$favoriteCount개',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FavoriteRegionsScreen())),
            ),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionTitle('지난 여행'),
              const SizedBox(height: 12),
              ...past.map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PastTripCard(
                    trip: trip,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PastTripScreen(tripId: trip.id))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(int tripId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: tripId)),
    );
  }

  Future<void> _createTrip() async {
    final controller = AppScope.of(context);
    final user = controller.currentUser;
    if (user == null) return;

    final regions = await controller.repository.getRegions(
      residence: user.residence,
    );
    final eligibleRegions = regions
        .where((r) => user.residence.trim().isEmpty || r.matchedByResidence)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    if (!mounted || eligibleRegions.isEmpty) return;

    final region = await _showRegionApplicationSheet(eligibleRegions);
    if (!mounted || region == null) return;

    final selection = await _showTripInfoSheet(region);
    if (!mounted || selection == null) return;

    final trip = await controller.runTask(
      () => controller.repository.createTrip(
        userId: user.id,
        draft: TripDraft(
          applicantName: user.name,
          phoneNumber: user.phoneNumber,
          residence: user.residence,
          startDate: selection.dateRange.start,
          endDate: selection.dateRange.end,
          travelerCount: selection.travelerCount,
        ),
        regionId: region.id,
      ),
    );

    await controller.setTripApplicationStatus(trip.id, true);
    await controller.refreshTrips();
    if (!mounted) return;
    setState(() {});
    _openDetail(trip.id);
  }

  Future<RegionSummary?> _showRegionApplicationSheet(
    List<RegionSummary> regions,
  ) {
    RegionSummary selected = regions.first;
    String query = '';
    return showModalBottomSheet<RegionSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = query.trim();
          final filtered = q.isEmpty
              ? regions
              : regions
                  .where((r) => r.name.contains(q) || r.province.contains(q))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('반값여행 신청하셨나요?',
                            style: Theme.of(ctx).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                          '먼저 여행할 지역을 고른 뒤 신청하러 가거나, 이미 신청을 마쳤다면 다음 단계에서 일정·인원을 등록해 주세요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.ink5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => setSheetState(() => query = v),
                          decoration: InputDecoration(
                            hintText: '지역 · 도 이름 검색',
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppColors.ink4),
                            filled: true,
                            fillColor: AppColors.surf,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.field),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('검색 결과가 없어요',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink4,
                                )),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final region = filtered[index];
                              return _RegionPickRow(
                                region: region,
                                selected: region.id == selected.id,
                                onTap: () =>
                                    setSheetState(() => selected = region),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text('선택한 지역  ',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink5,
                                )),
                            Text('${selected.name} · ${selected.province}',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.p600,
                                )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final url = selected.halfPriceApplyUrl.trim();
                                  if (url.isNotEmpty) {
                                    await launchUrl(Uri.parse(url),
                                        mode: LaunchMode.externalApplication);
                                  }
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '${selected.name} 신청 페이지로 이동했어요. 신청 완료 후 다시 추가해 주세요.')),
                                  );
                                  Navigator.of(ctx).pop(null);
                                },
                                child: const Text('신청하러 가기'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(selected),
                                child: const Text('신청 완료'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<_TripCreateSelection?> _showTripInfoSheet(RegionSummary region) {
    int travelerCount = 2;
    DateTimeRange range = DateTimeRange(
      start: DateTime.now().add(const Duration(days: 7)),
      end: DateTime.now().add(const Duration(days: 8)),
    );
    return _showSheet<_TripCreateSelection>(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${region.name} 여행 추가',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '신청을 완료한 여행만 일정·인원을 등록할 수 있어요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              height: 1.5,
              color: AppColors.ink5,
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.field),
            onTap: () async {
              final picked = await showTripCalendarSheet(
                sheetContext,
                initial: range,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setSheetState(() => range = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.ink5),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_kdate(range.start)} ~ ${_kdate(range.end)}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink9,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: AppColors.ink4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StepperRow(
            value: travelerCount,
            onChanged: (v) => setSheetState(() => travelerCount = v),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(
                _TripCreateSelection(
                    dateRange: range, travelerCount: travelerCount),
              ),
              child: const Text('내 여행에 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Future<T?> _showSheet<T>({
    required Widget Function(BuildContext, StateSetter) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 4,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
        ),
        child: StatefulBuilder(
          builder: (c, setSheetState) => builder(c, setSheetState),
        ),
      ),
    );
  }
}

/// 여행 진행 단계(목록 카드 표시용) — 기존 날짜 기반 로직 유지.
class _TripStage {
  const _TripStage(this.label, this.tone, this.dday, this.cta);
  final String label;
  final PillTone tone;
  final String dday;
  final String cta;

  static _TripStage of(TripSummary t) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(t.startDate);
    final end = DateUtils.dateOnly(t.endDate);
    if (today.isBefore(start)) {
      final d = start.difference(today).inDays;
      return _TripStage('여행 전', PillTone.sky, '출발 D-$d', '출발 전 준비하기');
    }
    if (!today.isAfter(end)) {
      final dayNo = today.difference(start).inDays + 1;
      final total = end.difference(start).inDays + 1;
      return _TripStage(
          '여행 중', PillTone.success, 'Day $dayNo / $total', '인증 · 영수증 기록하기');
    }
    return const _TripStage('정산 신청', PillTone.warning, '여행 종료', '증빙 패키지 만들기');
  }

  bool get showSpending => label != '여행 전';
}

class _PageHead extends StatelessWidget {
  const _PageHead({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('내 여행', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        Material(
          color: AppColors.p500,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onAdd,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text('여행 추가',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.ink9,
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});
  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = _TripStage.of(trip);
    final nights = trip.endDate.difference(trip.startDate).inDays;
    final days = nights + 1;
    final spent = trip.totalSpentAmount;
    final goal = trip.refundConditionAmount;
    final ratio = goal > 0 ? (spent / goal).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(stage.label, tone: stage.tone),
              const Spacer(),
              Text(stage.dday,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink5,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const _TripAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${trip.regionName} $nights박$days일',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('M.d').format(trip.startDate)} ~ ${DateFormat('M.d').format(trip.endDate)} · ${trip.travelerCount}명',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: AppColors.ink5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stage.showSpending && goal > 0) ...[
            const SizedBox(height: 16),
            _ProgressRow(
              label: '누적 소비',
              valueText: '${_man(spent)} / ${_man(goal)}',
              ratio: ratio,
            ),
          ],
          const SizedBox(height: 16),
          _NextActionBar(label: stage.cta),
        ],
      ),
    );
  }
}

class _PastTripCard extends StatelessWidget {
  const _PastTripCard({required this.trip, required this.onTap});
  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nights = trip.endDate.difference(trip.startDate).inDays;
    final days = nights + 1;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _TripAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trip.regionName} $nights박$days일',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('M.d').format(trip.startDate)} ~ ${DateFormat('M.d').format(trip.endDate)} · ${trip.travelerCount}명',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: AppColors.ink5,
                  ),
                ),
              ],
            ),
          ),
          const Pill('환급 완료', tone: PillTone.gold),
        ],
      ),
    );
  }
}

class _TripAvatar extends StatelessWidget {
  const _TripAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.p50,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.luggage_rounded, color: AppColors.p500, size: 22),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.valueText,
    required this.ratio,
  });

  final String label;
  final String valueText;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink7,
                )),
            const Spacer(),
            Text(valueText,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9,
                )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.track,
            valueColor: const AlwaysStoppedAnimation(AppColors.p500),
          ),
        ),
      ],
    );
  }
}

class _NextActionBar extends StatelessWidget {
  const _NextActionBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.p50,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.p700,
                )),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.p600),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.p600),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink9,
              )),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink5,
              )),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('아직 등록한 여행이 없어요',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            '반값여행 신청을 마쳤다면 일정·인원을 등록해 인증·정산까지 관리해 보세요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              height: 1.5,
              color: AppColors.ink5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAdd, child: const Text('여행 추가')),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          const Text('여행 인원',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink9,
              )),
          const Spacer(),
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 52,
            child: Text('$value명',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9,
                )),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: value < 10 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 18, color: onTap == null ? AppColors.ink4 : AppColors.p600),
        ),
      ),
    );
  }
}

/// 여행 추가 시트의 지역 선택 카드 — 선택 시 스카이 테두리·배경으로 강조.
class _RegionPickRow extends StatelessWidget {
  const _RegionPickRow({
    required this.region,
    required this.selected,
    required this.onTap,
  });

  final RegionSummary region;
  final bool selected;
  final VoidCallback onTap;

  PillTone get _statusTone => switch (region.statusCode.toUpperCase()) {
        'APPLYING' => PillTone.success,
        'CLOSED' => PillTone.gray,
        _ => PillTone.gold,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.p50 : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(
              color: selected ? AppColors.p500 : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.p100 : AppColors.surf,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.place_rounded,
                    size: 20,
                    color: selected ? AppColors.p600 : AppColors.ink4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${region.name} · ${region.province}',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink9,
                            )),
                        const SizedBox(width: 8),
                        Pill(region.statusLabel, tone: _statusTone),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      region.refundConditionAmount > 0
                          ? '최소 소비 ${_man(region.refundConditionAmount)}'
                          : '반값여행 대상 지역',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 22,
                color: selected ? AppColors.p500 : AppColors.ink4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCreateSelection {
  const _TripCreateSelection({
    required this.dateRange,
    required this.travelerCount,
  });

  final DateTimeRange dateRange;
  final int travelerCount;
}

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// "6.14(토)" — intl 로케일 초기화 없이 한글 요일 표기.
String _kdate(DateTime d) =>
    '${d.month}.${d.day}(${_weekdayKo[d.weekday - 1]})';

String _man(int won) {
  if (won >= 10000) {
    final man = won / 10000;
    final text = man == man.roundToDouble()
        ? man.toStringAsFixed(0)
        : man.toStringAsFixed(1);
    return '$text만';
  }
  return '${NumberFormat('#,###').format(won)}원';
}
