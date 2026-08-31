import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/favorite_regions_screen.dart';
import '../../screens/past_trip_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/trip_calendar_sheet.dart';
import '../widgets/region_art.dart';
import '../widgets/ui.dart';
import 'course_flow.dart';
import 'trip_detail.dart';

/// 내 여행 목록 (S2-1) — 목업 UI + AppController 실데이터.
/// 진행 중(여행 전/중/정산) ↔ 지난 여행(정산 신청 완료)으로 나눠 보여준다.
class MyTripsTab extends StatefulWidget {
  const MyTripsTab({super.key});

  @override
  State<MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends State<MyTripsTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AppScope.of(context).refreshTrips();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final trips = controller.trips;
    // 진행 중 = 정산 신청 전 전부(여행 전·중·종료 대기). 배지가 단계를 말해주므로
    // 섹션을 쪼개지 않되, 정산 신청을 마쳤거나 마감이 지난 여행은 지난 여행으로 내린다.
    final active = trips
        .where((t) => !t.settlementApplied && !settlementExpired(t))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = trips
        .where((t) => t.settlementApplied || settlementExpired(t))
        .toList()
      ..sort((a, b) => b.endDate.compareTo(a.endDate));
    final favCount = controller.currentUser?.favoriteRegions.length ?? 0;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          Row(children: [
            const Text('내 여행',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
            const Spacer(),
            GestureDetector(
              onTap: () => showTripAddSheet(context).then((_) {
                if (mounted) setState(() {});
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.p500,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [BoxShadow(color: Color(0x400EA5E9), blurRadius: 12, offset: Offset(0, 5))],
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, size: 17, color: Colors.white),
                  SizedBox(width: 4),
                  Text('여행 추가',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          const SectionTitle('진행 중인 여행'),
          const SizedBox(height: 12),
          if (_loading && trips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.p500)),
            )
          else if (active.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(18)),
              child: const Text('진행 중인 여행이 없어요. 우측 상단에서 신청 완료한 여행을 추가해보세요.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5)),
            )
          else
            for (final trip in active) ...[
              // 상세에서 체크리스트·증빙을 바꾸고 돌아오면 서버 값으로 다시 그린다.
              TripCard(trip: trip, onChanged: _refresh),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 8),
          const SectionTitle('보관함'),
          const SizedBox(height: 12),
          MenuGroup(children: [
            MenuRow(
              icon: Icons.bookmark_outline_rounded,
              label: '저장 코스',
              value: '${controller.savedCourses.length}개',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CourseSavedScreen())),
            ),
            MenuRow(
              icon: Icons.star_outline_rounded,
              label: '관심 지역',
              value: '$favCount개',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FavoriteRegionsScreen()))
                  .then((_) => setState(() {})),
            ),
          ]),
          // 지난 여행이 없으면 섹션 자체를 숨긴다.
          if (past.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionTitle('지난 여행'),
            const SizedBox(height: 12),
            for (final trip in past) ...[
              AppCard(
                // 신청 완료 여행은 지난 여행 화면, 마감 지남 여행은 상세(마감 안내)로.
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => trip.settlementApplied
                        ? PastTripScreen(tripId: trip.id)
                        : TripDetailScreen(tripId: trip.id))),
                child: Row(children: [
                  RegionArt(trip.regionName, size: 48, fontSize: 24, radius: 15),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${trip.regionName} ${durationLabelOf(trip)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                      const SizedBox(height: 3),
                      Text('${dateRangeOf(trip)} · ${trip.travelerCount}명',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                    ]),
                  ),
                  // 마감이 지나 내려온 여행은 완료가 아니라 마감 지남으로 정직하게.
                  trip.settlementApplied
                      ? const Pill('정산 신청 완료', tone: PillTone.gold)
                      : const Pill('정산 마감 지남', tone: PillTone.gray),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── 표시 유틸

String dateRangeOf(TripSummary t) =>
    '${t.startDate.month}.${t.startDate.day} ~ ${t.endDate.month}.${t.endDate.day}';

String durationLabelOf(TripSummary t) {
  final nights = t.endDate.difference(t.startDate).inDays;
  return nights <= 0 ? '당일치기' : '$nights박${nights + 1}일';
}

/// 여행 단계 — 정산 신청 완료면 review, 아니면 날짜 기준.
/// 여행 단계 판정 — 계약 0-2: 백엔드가 KST로 계산한 status를 신뢰한다.
/// (기기 시계·타임존 오차 방지) 서버 값이 없거나 모르는 값이면 날짜 계산 폴백.
/// 정산 마감 표기 — 음수 D-day("D--87")를 만들지 않는다.
String _settlementDdayLabel(DateTime? deadline, DateTime today) {
  if (deadline == null) return '여행 종료';
  final left = DateUtils.dateOnly(deadline).difference(today).inDays;
  if (left < 0) return '정산 마감 지남';
  if (left == 0) return '정산 마감 오늘';
  return '정산 마감 D-$left';
}

TripStageView stageOf(TripSummary t) {
  switch (t.status.toUpperCase()) {
    case 'BEFORE':
      return TripStageView.before;
    case 'ONGOING':
      return TripStageView.during;
    case 'ENDED':
      return TripStageView.settle;
    case 'SETTLEMENT_REQUESTED':
      return TripStageView.review;
  }
  // mock·구버전 응답 폴백
  if (t.settlementApplied) return TripStageView.review;
  final today = DateUtils.dateOnly(DateTime.now());
  final start = DateUtils.dateOnly(t.startDate);
  final end = DateUtils.dateOnly(t.endDate);
  if (today.isBefore(start)) return TripStageView.before;
  if (!today.isAfter(end)) return TripStageView.during;
  return TripStageView.settle;
}

enum TripStageView { before, during, settle, review }

/// 정산 마감이 지났는데 신청도 안 한 여행 — 목록에선 지난 여행으로 내리고,
/// 상세에선 정산 권유를 멈춘다 (QA 8/26 #2·#3).
bool settlementExpired(TripSummary t) {
  if (t.settlementApplied) return false;
  if (stageOf(t) != TripStageView.settle) return false;
  final deadline = t.settlementDeadline;
  if (deadline == null) return false;
  return DateUtils.dateOnly(deadline)
      .isBefore(DateUtils.dateOnly(DateTime.now()));
}

String regionEmojiOf(String regionName) {
  const map = <String, String>{
    '평창': '🏔️', '횡성': '🥩', '영월': '🌊', '제천': '⛰️',
    '거창': '🌿', '고창': '🏛️', '합천': '🌄', '영광': '🐟',
    '밀양': '🏞️', '영암': '🏎️', '하동': '🍃', '강진': '🍲',
    '남해': '🌴', '해남': '🌾', '고흥': '🚀', '완도': '🏝️',
    // 신규·예정 지역 임시 이모지 (일러 나오면 교체)
    '화천': '🎣', '영천': '🔭', '함양': '🌱', '산청': '🍵',
    '고성': '🦕', '안동': '🎭', '서천': '🐦', '태안': '🌅',
    '장흥': '🌲',
  };
  return map[regionName] ?? '📍';
}

/// 진행 중 여행 카드 (목업 tripcard) — 실데이터.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onChanged});

  final TripSummary trip;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final stage = stageOf(trip);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(trip.startDate);
    final totalDays = trip.endDate.difference(trip.startDate).inDays + 1;

    final (pill, tone) = switch (stage) {
      TripStageView.before => ('여행 전', PillTone.sky),
      TripStageView.during => ('여행 중', PillTone.live),
      _ => ('정산 신청', PillTone.warn),
    };
    final deadline = trip.settlementDeadline;
    final dday = switch (stage) {
      TripStageView.before => '출발 D-${start.difference(today).inDays}',
      TripStageView.during => 'Day ${today.difference(start).inDays + 1} / $totalDays',
      _ => _settlementDdayLabel(deadline, today),
    };
    final next = switch (stage) {
      TripStageView.before => '출발 전 준비하기',
      TripStageView.during => '인증 · 영수증 기록하기',
      _ => '증빙 패키지 만들기',
    };

    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)))
          .then((_) => onChanged()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(pill, tone: tone),
          const Spacer(),
          Text(dday,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          RegionArt(trip.regionName, size: 48, fontSize: 24, radius: 15),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${trip.regionName} ${durationLabelOf(trip)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
              const SizedBox(height: 3),
              Text('${dateRangeOf(trip)} · ${trip.travelerCount}명',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ]),
          ),
        ]),
        if (stage == TripStageView.before &&
            trip.checklistDoneCount != null &&
            (trip.checklistTotal ?? 0) > 0) ...[
          const SizedBox(height: 14),
          ProgressGauge(
            label: '출발 체크리스트',
            value: '${trip.checklistDoneCount} / ${trip.checklistTotal}',
            progress:
                (trip.checklistDoneCount! / trip.checklistTotal!).clamp(0.0, 1.0),
          ),
        ],
        if (stage == TripStageView.during &&
            trip.authCertifiedCount != null &&
            (trip.authRequiredCount ?? 0) > 0) ...[
          const SizedBox(height: 14),
          ProgressGauge(
            label: '관광지 인증',
            value: '${trip.authCertifiedCount} / ${trip.authRequiredCount}곳',
            progress: (trip.authCertifiedCount! / trip.authRequiredCount!)
                .clamp(0.0, 1.0),
          ),
        ],
        if (stage == TripStageView.during && trip.refundConditionAmount > 0) ...[
          const SizedBox(height: 14),
          ProgressGauge(
            label: '누적 소비',
            value: '${_man(trip.totalSpentAmount)} / ${_man(trip.refundConditionAmount)}',
            progress: (trip.totalSpentAmount / trip.refundConditionAmount).clamp(0.0, 1.0),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Text(next,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.p600)),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.p600),
        ]),
      ]),
    );
  }

  String _man(int amount) => amount >= 10000 ? '${amount ~/ 10000}만원' : '$amount원';
}

// ───────────────────────── S2-2 여행 추가 (2단계 시트, 실 API)

Future<void> showTripAddSheet(BuildContext context) async {
  final region = await _showRegionApplicationSheet(context);
  if (region == null || !context.mounted) return;
  await _showTripInfoSheet(context, region);
}

/// ① "반값여행 신청하셨나요?" — 접수중 지역 검색·선택.
Future<RegionSummary?> _showRegionApplicationSheet(BuildContext context) async {
  final controller = AppScope.of(context);
  final List<RegionSummary> regions;
  try {
    final all = await controller.repository
        .getRegions(residence: controller.currentUser?.residence ?? '');
    regions = all.where((r) => r.statusCode.toUpperCase() == 'APPLYING').toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  } catch (_) {
    if (context.mounted) showMock(context, '지역 목록을 불러오지 못했어요.');
    return null;
  }
  if (!context.mounted) return null;
  if (regions.isEmpty) {
    showMock(context, '지금 접수 중인 지역이 없어요.');
    return null;
  }

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
      builder: (ctx, setSheet) {
        final q = query.trim();
        final filtered = q.isEmpty
            ? regions
            : regions.where((r) => r.name.contains(q) || r.province.contains(q)).toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.82,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('반값여행 신청하셨나요?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink9, letterSpacing: -.5)),
                  const SizedBox(height: 8),
                  const Text(
                    '먼저 여행할 지역을 고른 뒤 신청하러 가거나, 이미 신청을 마쳤다면 다음 단계에서 일정·인원을 등록해 주세요.',
                    style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: AppColors.ink5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setSheet(() => query = v),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9),
                    decoration: InputDecoration(
                      hintText: '지역 · 도 이름 검색',
                      hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink4),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.ink4),
                      filled: true,
                      fillColor: AppColors.surf,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('검색 결과가 없어요',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _RegionPickRow(
                          region: filtered[index],
                          selected: filtered[index].id == selected.id,
                          onTap: () => setSheet(() => selected = filtered[index]),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('선택한 지역  ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                    Text('${selected.name} · ${selected.province}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    SecondaryButton('신청하러 가기', onTap: () async {
                      final url = selected.halfPriceApplyUrl.trim();
                      if (url.isNotEmpty) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                      if (!ctx.mounted) return;
                      showMock(ctx, '${selected.name} 신청 페이지로 이동했어요. 신청 완료 후 다시 추가해 주세요.');
                      Navigator.of(ctx).pop(null);
                    }),
                    const SizedBox(width: 12),
                    PrimaryButton('신청 완료', onTap: () => Navigator.of(ctx).pop(selected)),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    ),
  );
}

/// ② "{지역} 여행 추가" — 일정(캘린더)·인원 → createTrip.
Future<void> _showTripInfoSheet(BuildContext context, RegionSummary region) {
  var people = 2;
  // 회차 여행기간이 미래에 시작하면 초기 선택을 그 시작일로 — 대부분 그 기간에 갈 거라서.
  final periodStart = region.travelPeriodStart;
  final defaultStart = periodStart != null && periodStart.isAfter(DateTime.now())
      ? periodStart
      : DateTime.now().add(const Duration(days: 7));
  var range = DateTimeRange(
    start: defaultStart,
    end: defaultStart.add(const Duration(days: 1)),
  );
  var saving = false;
  // 캘린더 안내 칩·기간 밖 경고용 — 회차 여행기간(둘 다 있을 때만).
  final allowedRange = region.travelPeriodStart != null && region.travelPeriodEnd != null
      ? DateTimeRange(start: region.travelPeriodStart!, end: region.travelPeriodEnd!)
      : null;
  final allowedLabel =
      '${region.name} ${region.roundLabel != null ? '${region.roundLabel} ' : ''}여행기간';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final nights = range.end.difference(range.start).inDays;
        final durLabel = nights == 0 ? '당일' : '$nights박${nights + 1}일';

        Future<void> submit() async {
          if (saving) return;
          setSheet(() => saving = true);
          final controller = AppScope.of(ctx);
          final user = controller.currentUser;
          if (user == null) return;
          try {
            await controller.runTask(
              () => controller.repository.createTrip(
                userId: user.id,
                regionId: region.id,
                draft: TripDraft(
                  // 실명·전화번호는 여행을 만들 때가 아니라 정산 신청 시점에 받는다.
                  // (개인정보 최소수집 — settlement_screen의 _askApplicantInfo)
                  applicantName: '',
                  phoneNumber: '',
                  residence: user.residence,
                  startDate: range.start,
                  endDate: range.end,
                  travelerCount: people,
                ),
              ),
            );
            await controller.refreshTrips();
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            showMock(ctx, '${region.name} $durLabel 여행을 추가했어요.');
          } catch (_) {
            if (!ctx.mounted) return;
            setSheet(() => saving = false);
            showMock(ctx, '여행 추가에 실패했어요. 잠시 후 다시 시도해주세요.');
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${region.name} 여행 추가',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink9, letterSpacing: -.5)),
            const SizedBox(height: 8),
            const Text('신청을 완료한 여행만 일정·인원을 등록할 수 있어요.',
                style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            const SizedBox(height: 20),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final picked = await showTripCalendarSheet(
                  ctx,
                  initial: range,
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  allowedRange: allowedRange,
                  allowedLabel: allowedLabel,
                );
                if (picked != null) setSheet(() => range = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.ink5),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${kdate(range.start)} ~ ${kdate(range.end)} · $durLabel',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
                  ),
                  const Icon(Icons.expand_more_rounded, color: AppColors.ink4),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Text('여행 인원',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9)),
                const Spacer(),
                _CntBtn('−', () => setSheet(() => people = (people - 1).clamp(1, 8))),
                SizedBox(
                  width: 52,
                  child: Text('$people명',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9)),
                ),
                _CntBtn('+', () => setSheet(() => people = (people + 1).clamp(1, 8))),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              PrimaryButton(saving ? '추가 중…' : '내 여행에 추가', disabled: saving, onTap: submit),
            ]),
          ]),
        );
      },
    ),
  );
}

/// 지역 선택 카드 — 선택 시 스카이 테두리·배경으로 강조.
class _RegionPickRow extends StatelessWidget {
  const _RegionPickRow({required this.region, required this.selected, required this.onTap});
  final RegionSummary region;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.p50 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.p500 : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.p100 : AppColors.surf,
                shape: BoxShape.circle,
              ),
              child: Text(regionEmojiOf(region.name), style: const TextStyle(fontSize: 19)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text('${region.name} · ${region.province}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  ),
                  const SizedBox(width: 8),
                  const Pill('접수중', tone: PillTone.sky),
                ]),
                const SizedBox(height: 3),
                Text(
                  region.refundConditionAmount > 0
                      ? '최소 소비 ${region.refundConditionAmount ~/ 10000}만원'
                      : '반값여행 대상 지역',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 22,
              color: selected ? AppColors.p500 : AppColors.ink4,
            ),
          ]),
        ),
      ),
    );
  }
}

class _CntBtn extends StatelessWidget {
  const _CntBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: AppShadows.soft),
        child: Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.p600, height: 1)),
      ),
    );
  }
}
