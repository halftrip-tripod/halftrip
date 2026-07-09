import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/trip_calendar_sheet.dart';
import '../widgets/ui.dart';
import 'course_flow.dart';
import 'mypage.dart';
import 'past_trip.dart';
import 'trip_detail.dart';

/// S2-1 내 여행 목록.
class MyTripsTab extends StatelessWidget {
  const MyTripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final active = s.trips.where((t) => t.stage != TripStage.done).toList();
    final past = s.trips.where((t) => t.stage == TripStage.done).toList();
    final favCount = s.regions.where((r) => r.favorite.value).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: [
        Row(children: [
          const Text('내 여행',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
          const Spacer(),
          GestureDetector(
            onTap: () => showTripAddSheet(context),
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
        for (final t in active) ...[TripCard(trip: t), const SizedBox(height: 14)],
        const SizedBox(height: 8),
        const SectionTitle('보관함'),
        const SizedBox(height: 12),
        MenuGroup(children: [
          MenuRow(
            icon: Icons.bookmark_outline_rounded,
            label: '저장 코스',
            value: '${s.courses.length}개',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CourseSavedScreen())),
          ),
          MenuRow(
            icon: Icons.star_outline_rounded,
            label: '관심 지역',
            value: '$favCount개',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FavoriteRegionsScreen())),
          ),
        ]),
        const SizedBox(height: 22),
        const SectionTitle('지난 여행'),
        const SizedBox(height: 12),
        for (final t in past)
          AppCard(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => PastTripScreen(trip: t))),
            child: Row(children: [
              EmojiBox(t.emoji, size: 48, fontSize: 24, radius: 15),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                  const SizedBox(height: 3),
                  Text(t.dateLabel,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                ]),
              ),
              const Pill('환급 완료', tone: PillTone.gold),
            ]),
          ),
      ],
    );
  }
}

/// 진행 중 여행 카드 (상태별 구성).
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final (pill, tone) = switch (trip.stage) {
      TripStage.before => ('여행 전', PillTone.sky),
      TripStage.during => ('여행 중', PillTone.live),
      TripStage.settle => ('정산 신청', PillTone.warn),
      TripStage.review => ('정산 완료', PillTone.gray),
      TripStage.done => ('환급 완료', PillTone.gold),
    };
    final next = switch (trip.stage) {
      TripStage.before => '출발 전 준비하기',
      TripStage.during => '인증 · 영수증 기록하기',
      TripStage.settle => '증빙 패키지 만들기',
      _ => '여행 요약 보기',
    };
    final s = AppState.I;

    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(pill, tone: tone),
          const Spacer(),
          Text(trip.ddayLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          EmojiBox(trip.emoji, size: 48, fontSize: 24, radius: 15),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
              const SizedBox(height: 3),
              Text(trip.dateLabel,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ]),
          ),
        ]),
        if (trip.stage == TripStage.before) ...[
          const SizedBox(height: 14),
          ProgressGauge(
            label: '출발 준비 체크리스트',
            value: '${s.checklistDone.length}/4',
            progress: s.checklistDone.length / 4,
          ),
        ],
        if (trip.stage == TripStage.during) ...[
          const SizedBox(height: 14),
          ProgressGauge(
            label: '관광지 인증',
            value: '${s.authPhotoDone} / 2곳',
            progress: s.authPhotoDone / 2,
            green: true,
          ),
          const SizedBox(height: 12),
          ProgressGauge(
            label: '누적 소비',
            value: '${s.spentAmount ~/ 10000}만 / 20만원',
            progress: (s.spentAmount / 200000).clamp(0, 1),
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
}

/// S2-2 여행 추가 — 앱과 동일한 2단계 플로우.
/// ① 지역 선택(검색·신청하러 가기/신청 완료) → ② 일정(캘린더)·인원 등록.
Future<void> showTripAddSheet(BuildContext context) async {
  final region = await _showRegionApplicationSheet(context);
  if (region == null || !context.mounted) return;
  await _showTripInfoSheet(context, region);
}

/// ① "반값여행 신청하셨나요?" — 지역 검색·선택 시트.
/// 오픈예정·마감 지역은 신청 자체가 불가능하므로 접수중만 노출.
Future<Region?> _showRegionApplicationSheet(BuildContext context) {
  final regions =
      AppState.I.regions.where((r) => r.status == RegionStatus.open).toList();
  Region selected = regions.first;
  String query = '';

  return showModalBottomSheet<Region>(
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
                          selected: filtered[index] == selected,
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
                    SecondaryButton('신청하러 가기', onTap: () {
                      showMock(ctx, '${selected.name} 신청 페이지로 이동했어요. 신청 완료 후 다시 추가해 주세요. (외부 링크 · 목업)');
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

/// ② "{지역} 여행 추가" — 일정(캘린더)·인원 등록 시트.
Future<void> _showTripInfoSheet(BuildContext context, Region region) {
  var people = 2;
  var range = DateTimeRange(
    start: DateTime.now().add(const Duration(days: 7)),
    end: DateTime.now().add(const Duration(days: 8)),
  );

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
              PrimaryButton('내 여행에 추가', onTap: () {
                final start = DateUtils.dateOnly(range.start);
                final dday = start.difference(DateUtils.dateOnly(DateTime.now())).inDays;
                final t = Trip(
                  emoji: region.emoji,
                  name: '${region.name} $durLabel',
                  region: region.name,
                  dateLabel: '${kdate(range.start)} ~ ${kdate(range.end)} · $people명',
                  people: people,
                  stage: TripStage.before,
                  ddayLabel: dday <= 0 ? '출발 D-DAY' : '출발 D-$dday',
                  nights: nights,
                );
                AppState.I.addTrip(t);
                Navigator.of(ctx).pop();
                AppState.I.tabRequest.value = 1; // 내 여행 탭으로
                showMock(context, '${t.name} 여행을 추가했어요.');
              }),
            ]),
          ]),
        );
      },
    ),
  );
}

/// 지역 선택 카드 — 선택 시 스카이 테두리·배경으로 강조 (앱 _RegionPickRow 이식).
class _RegionPickRow extends StatelessWidget {
  const _RegionPickRow({required this.region, required this.selected, required this.onTap});
  final Region region;
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
              child: Text(region.emoji, style: const TextStyle(fontSize: 19)),
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
                  Pill(
                    region.status == RegionStatus.open ? '접수중' : '오픈예정',
                    tone: region.status == RegionStatus.open ? PillTone.success : PillTone.gold,
                  ),
                ]),
                const SizedBox(height: 3),
                Text(region.condition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
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
