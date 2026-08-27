import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 여행 일정(기간) 선택 — 커스텀 범위 캘린더 바텀시트.
/// 출발일 → 도착일 순으로 탭. 반환: 선택한 기간(취소 시 null).
/// halftrip-app lib/widgets/trip_calendar_sheet.dart 이식.
Future<DateTimeRange?> showTripCalendarSheet(
  BuildContext context, {
  DateTimeRange? initial,
  DateTime? firstDate,
  DateTime? lastDate,
  bool singleDay = false,
  DateTimeRange? allowedRange,
  String? allowedLabel,
}) {
  final now = DateUtils.dateOnly(DateTime.now());
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TripCalendarSheet(
      initial: initial,
      firstDate: firstDate ?? now,
      lastDate: lastDate ?? DateTime(now.year + 1, now.month, now.day),
      singleDay: singleDay,
      allowedRange: allowedRange == null
          ? null
          : DateTimeRange(
              start: DateUtils.dateOnly(allowedRange.start),
              end: DateUtils.dateOnly(allowedRange.end)),
      allowedLabel: allowedLabel,
    ),
  );
}

String kdate(DateTime d) => '${d.month}.${d.day}(${_weekdayKo[d.weekday - 1]})';
const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

class _TripCalendarSheet extends StatefulWidget {
  const _TripCalendarSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    this.singleDay = false,
    this.allowedRange,
    this.allowedLabel,
  });

  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;

  /// 하루만 고르는 모드 — 탭 즉시 시작=종료로 확정 (행 편집 등 단일 날짜용).
  final bool singleDay;

  /// 회차의 여행 허용 기간 — 있으면 안내 칩을 띄우고, 벗어난 선택은 노란색으로 표시(막지는 않음).
  final DateTimeRange? allowedRange;

  /// 안내 칩 라벨 — "완도 5차 여행기간" 등. 없으면 "여행기간".
  final String? allowedLabel;

  @override
  State<_TripCalendarSheet> createState() => _TripCalendarSheetState();
}

class _TripCalendarSheetState extends State<_TripCalendarSheet> {
  late DateTime _month; // 보이는 달(1일)
  DateTime? _start;
  DateTime? _end;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    // 초기값에 시각이 붙어있으면 자정 기준 셀 비교가 어긋나므로 날짜만 남긴다.
    _start = widget.initial == null ? null : DateUtils.dateOnly(widget.initial!.start);
    _end = widget.initial == null ? null : DateUtils.dateOnly(widget.initial!.end);
    final base = _start ?? DateUtils.dateOnly(DateTime.now());
    _month = DateTime(base.year, base.month);
  }

  bool get _canPrev =>
      _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  bool get _canNext =>
      _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _tapDay(DateTime day) {
    setState(() {
      if (widget.singleDay) {
        _start = day;
        _end = day;
        return;
      }
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  /// 선택한 기간이 회차 여행기간을 벗어났는지 (기간 정보 없으면 항상 false).
  bool get _outOfAllowed {
    final allowed = widget.allowedRange;
    if (allowed == null || _start == null) return false;
    final end = _end ?? _start!;
    return _start!.isBefore(allowed.start) || end.isAfter(allowed.end);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // 그 달 1일의 요일(일=0 기준) → 앞 빈칸 수
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final summary = _summaryText();
    final allowed = widget.allowedRange;
    // 기간 밖 선택은 막지 않는다 — 실제 신청 회차가 다를 수 있어서.
    // 대신 안내 칩이 파랑→노랑으로 바뀌며 알려준다.
    final warned = _outOfAllowed;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 2,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('여행 일정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink9, letterSpacing: -.5)),
          const SizedBox(height: 6),
          Text(summary,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _end != null ? AppColors.p600 : AppColors.ink5,
              )),
          if (allowed != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: warned ? AppColors.warningTint : AppColors.p50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(
                    warned
                        ? Icons.error_outline_rounded
                        : Icons.event_available_rounded,
                    size: 15,
                    color: warned ? const Color(0xFF9A6800) : AppColors.p700),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${widget.allowedLabel ?? '여행기간'} ${kdate(allowed.start)} ~ ${kdate(allowed.end)}'
                    '${warned ? ' · 기간 밖 날짜예요' : ''}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: warned ? const Color(0xFF9A6800) : AppColors.p700),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),

          // 월 네비게이션
          Row(children: [
            _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: _canPrev
                    ? () => setState(() => _month = DateTime(_month.year, _month.month - 1))
                    : null),
            Expanded(
              child: Text('${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            ),
            _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _canNext
                    ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                    : null),
          ]),
          const SizedBox(height: 10),

          // 요일 헤더
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(_weekdays[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: i == 0
                            ? AppColors.coralDeep
                            : (i == 6 ? AppColors.p600 : AppColors.ink4),
                      )),
                ),
              ),
          ]),
          const SizedBox(height: 4),

          // 날짜 그리드 (좌우 스와이프로도 월 이동)
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v > 250 && _canPrev) {
                setState(() => _month = DateTime(_month.year, _month.month - 1));
              } else if (v < -250 && _canNext) {
                setState(() => _month = DateTime(_month.year, _month.month + 1));
              }
            },
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: leading + daysInMonth,
              itemBuilder: (_, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = DateTime(_month.year, _month.month, index - leading + 1);
                return _DayCell(
                  day: day,
                  start: _start,
                  end: _end,
                  disabled: day.isBefore(DateUtils.dateOnly(widget.firstDate)) ||
                      day.isAfter(DateUtils.dateOnly(widget.lastDate)),
                  onTap: () => _tapDay(day),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_start != null && _end != null)
                  ? () => Navigator.of(context)
                      .pop(DateTimeRange(start: _start!, end: _end!))
                  : null,
              child: Text(_end != null ? '이 일정으로 선택' : '도착일을 선택하세요'),
            ),
          ),
        ],
      ),
    );
  }

  String _summaryText() {
    if (_start == null) return '출발일을 선택하세요';
    final s = kdate(_start!);
    if (_end == null) return '$s ~ 도착일 선택';
    final nights = _end!.difference(_start!).inDays;
    final label = nights == 0 ? '당일' : '$nights박${nights + 1}일';
    return '$s ~ ${kdate(_end!)} · $label';
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      icon: Icon(icon, size: 26, color: onTap == null ? AppColors.ink4 : AppColors.ink7),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.start,
    required this.end,
    required this.disabled,
    required this.onTap,
  });

  final DateTime day;
  final DateTime? start;
  final DateTime? end;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isStart = start != null && DateUtils.isSameDay(day, start);
    final isEnd = end != null && DateUtils.isSameDay(day, end);
    final isEndpoint = isStart || isEnd;
    final inRange =
        start != null && end != null && !day.isBefore(start!) && !day.isAfter(end!);
    final single = isStart && isEnd;
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(alignment: Alignment.center, children: [
        // 범위 밴드 — 원 뒤에 깔리는 평평한 연결바(높이=원). 둥근 끝은 끝점 원이 만든다.
        // 시작=오른쪽 반, 끝=왼쪽 반, 중간=꽉 참 → 주중·월말 잘림은 자연히 각지게.
        if (inRange && !single)
          Row(children: [
            Expanded(
              child: Container(height: 38, color: isStart ? Colors.transparent : AppColors.p50),
            ),
            Expanded(
              child: Container(height: 38, color: isEnd ? Colors.transparent : AppColors.p50),
            ),
          ]),
        // 끝점 원
        Container(
          width: 38,
          height: 38,
          decoration: isEndpoint
              ? const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle)
              : null,
          alignment: Alignment.center,
          child: Text('${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEndpoint || isToday ? FontWeight.w800 : FontWeight.w600,
                color: isEndpoint
                    ? Colors.white
                    : disabled
                        ? AppColors.ink4.withValues(alpha: 0.5)
                        : inRange
                            ? AppColors.p700
                            : isToday
                                ? AppColors.p600
                                : AppColors.ink9,
              )),
        ),
      ]),
    );
  }
}
