import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/region_art.dart';
import '../widgets/ui.dart';
import 'my_trips_tab.dart'
    show TripStageView, dateRangeOf, durationLabelOf, stageOf;

/// 코스를 연결할 여행 선택 시트.
/// 저장 코스함처럼 여행 컨텍스트 없이 들어온 흐름에서 쓴다 — 실서버 코스 플로우는
/// TripDetail이 있어야 잡·저장코스를 여행에 묶을 수 있기 때문.
/// 반환: 선택한 여행(취소 시 null).
Future<TripSummary?> pickTripSheet(
  BuildContext context, {
  required List<TripSummary> trips,
  String title = '어느 여행에 연결할까요?',
  String description = '만든 코스는 선택한 여행의 코스로 연결돼요',
}) {
  return showAppSheet<TripSummary>(
    context,
    scrollable: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9,
                    letterSpacing: -.4),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (c, i) => _TripPickRow(
              trip: trips[i],
              onTap: () => Navigator.of(c).pop(trips[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

class _TripPickRow extends StatelessWidget {
  const _TripPickRow({required this.trip, required this.onTap});

  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (stageLabel, stageTone) = switch (stageOf(trip)) {
      TripStageView.before => ('여행 전', AppColors.p600),
      TripStageView.during => ('여행 중', AppColors.mintDeep),
      TripStageView.settle => ('정산 준비', AppColors.warning),
      TripStageView.review => ('정산 신청', AppColors.ink5),
    };
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        RegionArt(trip.regionName, size: 44, fontSize: 22, radius: 13),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  '${trip.regionName} ${durationLabelOf(trip)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -.3),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stageTone.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stageLabel,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: stageTone),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              '${dateRangeOf(trip)} · ${trip.travelerCount}명',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink5),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
      ]),
    );
  }
}
