import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';
import 'auth_photo_upload_screen.dart';
import 'lodging_form_screen.dart';
import 'planner_screen.dart';
import 'receipt_card_screen.dart';
import 'receipt_evidence_screen.dart';
import 'settlement_screen.dart';
import 'submission_package_screen.dart';

/// 여행 상세 — 4단계 컨트롤 센터 (여행 전 → 중 → 정산 → 환급).
/// 디자인: halftrip-design/my-trip-detail.html
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

enum _Stage { before, during, settle, review }

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  final Set<int> _checkedPrep = {0, 1}; // 출발 준비 체크리스트 (로컬 — 모델 미보유)

  static const _prepItems = [
    '지역화폐(Chak) 앱 설치',
    '결제수단(인정 카드) 확인',
    '인증사진 가이드 확인',
    '숙소 예약 확인',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _loadDetail();
  }

  Future<TripDetail> _loadDetail() async {
    final controller = AppScope.of(context);
    final detail = await controller.repository.getTripDetail(widget.tripId);
    await controller.syncPendingYoutubeCourseJobsForTrip(detail.trip.id);
    if (controller.selectedCourseForTrip(detail.trip.id) == null &&
        detail.selectedPlaces.isNotEmpty) {
      await controller.syncTripPlacesToSelectedCourse(
        tripId: detail.trip.id,
        regionId: detail.trip.regionId,
        regionName: detail.trip.regionName,
        places: detail.selectedPlaces,
      );
    }
    return detail;
  }

  Future<void> _reload() async {
    setState(() => _future = _loadDetail());
    await AppScope.of(context).refreshTrips();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    await _reload();
  }

  _Stage _stageOf(TripSummary t) {
    if (t.settlementApplied) return _Stage.review;
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(t.startDate);
    final end = DateUtils.dateOnly(t.endDate);
    if (today.isBefore(start)) return _Stage.before;
    if (!today.isAfter(end)) return _Stage.during;
    return _Stage.settle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('여행 상세')),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('여행 정보를 불러오지 못했어요.\n${snapshot.error ?? ''}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final detail = snapshot.data!;
          final stage = _stageOf(detail.trip);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _HeaderCard(trip: detail.trip, stage: stage),
              const SizedBox(height: 14),
              _StageBar(stage: stage),
              const SizedBox(height: 16),
              ..._stageBody(detail, stage),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _stageBody(TripDetail detail, _Stage stage) => switch (stage) {
        _Stage.before => _beforeBody(detail),
        _Stage.during => _duringBody(detail),
        _Stage.settle => _settleBody(detail),
        _Stage.review => _reviewBody(detail),
      };

  // ---------- 여행 전 ----------
  List<Widget> _beforeBody(TripDetail detail) {
    final course = AppScope.of(context).selectedCourseForTrip(detail.trip.id);
    return [
      _CourseCard(
        course: course,
        onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '출발 준비 체크리스트',
        trailing: '${_checkedPrep.length}/${_prepItems.length}',
        child: Column(
          children: [
            for (var i = 0; i < _prepItems.length; i++)
              _CheckRow(
                label: _prepItems[i],
                checked: _checkedPrep.contains(i),
                onTap: () => setState(() {
                  _checkedPrep.contains(i)
                      ? _checkedPrep.remove(i)
                      : _checkedPrep.add(i);
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const _SectionCard(
        title: '여행 중 · 후 할 일',
        subtitle: '출발하면 순서대로 열려요.',
        child: Column(children: [
          _UpcomingRow(
              icon: Icons.photo_camera_outlined,
              label: '관광지 인증샷 (EXIF)',
              when: '여행 중'),
          _UpcomingRow(
              icon: Icons.receipt_long_outlined,
              label: '영수증 OCR · 소비 추적',
              when: '여행 중'),
          _UpcomingRow(
              icon: Icons.hotel_outlined,
              label: '숙박확인서 작성·서명',
              when: '여행 중'),
          _UpcomingRow(
              icon: Icons.description_outlined,
              label: '증빙 패키지 · 정산 신청',
              when: '여행 후'),
        ]),
      ),
    ];
  }

  // ---------- 여행 중 ----------
  List<Widget> _duringBody(TripDetail detail) {
    final authCount = detail.uploadedFiles
        .where((f) => f.fileCategory == FileCategory.authPhoto)
        .length;
    final spent = detail.trip.totalSpentAmount;
    final goal = detail.trip.refundConditionAmount;
    final course = AppScope.of(context).selectedCourseForTrip(detail.trip.id);
    return [
      _SectionCard(
        title: '관광지 인증',
        child: Column(children: [
          _GaugeRow(
              label: '관광지 인증샷',
              valueText: '${authCount.clamp(0, 2)} / 2곳',
              ratio: (authCount / 2).clamp(0.0, 1.0),
              green: true),
          const SizedBox(height: 14),
          _NextBar(
              label: '인증샷 추가하기',
              onTap: () => _push(AuthPhotoUploadScreen(tripId: widget.tripId))),
        ]),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '소비 기록',
        child: Column(children: [
          _GaugeRow(
              label: '누적 소비 (조건 ${_man(goal)})',
              valueText: '${_man(spent)} / ${_man(goal)}',
              ratio: goal > 0 ? (spent / goal).clamp(0.0, 1.0) : 0.0),
          const SizedBox(height: 14),
          _NextBar(
              label: '영수증 추가하기',
              onTap: () =>
                  _push(ReceiptEvidenceScreen(tripId: widget.tripId))),
        ]),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '숙박확인서',
        subtitle: '체크아웃 때 사장님 서명을 받아 작성하면 정산이 편해져요.',
        child: _NextBar(
            label: '숙박확인서 작성하기',
            onTap: () => _push(LodgingFormScreen(tripId: widget.tripId))),
      ),
      const SizedBox(height: 14),
      _CourseCard(
        course: course,
        onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
      ),
    ];
  }

  // ---------- 정산 ----------
  List<Widget> _settleBody(TripDetail detail) {
    final authCount = detail.uploadedFiles
        .where((f) => f.fileCategory == FileCategory.authPhoto)
        .length;
    final approvedReceipt = detail.receipts
        .any((r) => r.reviewStatus == ReceiptReviewStatus.approved);
    final hasLodging = detail.uploadedFiles
            .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;
    return [
      _SectionCard(
        title: '증빙 자료 준비',
        child: Column(children: [
          _CheckRow(
              label: '관광지 인증샷 $authCount/2 · EXIF 검증',
              checked: authCount >= 2,
              onTap: () => _push(AuthPhotoUploadScreen(tripId: widget.tripId))),
          _CheckRow(
              label: '영수증 OCR · 소비 ${_man(detail.trip.totalSpentAmount)}',
              checked: approvedReceipt,
              onTap: () =>
                  _push(ReceiptEvidenceScreen(tripId: widget.tripId))),
          _CheckRow(
              label: '숙박확인서 서명',
              checked: hasLodging,
              onTap: () => _push(LodgingFormScreen(tripId: widget.tripId))),
        ]),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '증빙 패키지',
        subtitle: '인증샷 + 영수증 + 숙박확인서를 제출 규격 PDF로 자동 병합해요.',
        child: _NextBar(
            label: '증빙 패키지 만들기',
            onTap: () => _openSubmission(detail)),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '정산 신청',
        subtitle: '증빙 패키지를 지자체 정산 페이지에 제출하세요.',
        child: Column(children: [
          _NextBar(
              label: '정산 신청하러 가기',
              onTap: () => _push(SettlementScreen(tripId: widget.tripId))),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () => _markSettled(detail.trip.id),
              child: const Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '이미 신청했어요 · ',
                      style: TextStyle(color: AppColors.ink5)),
                  TextSpan(
                      text: '완료로 표시',
                      style: TextStyle(
                          color: AppColors.p600,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline)),
                ]),
                style: TextStyle(fontFamily: 'Pretendard', fontSize: 13),
              ),
            ),
          ),
        ]),
      ),
    ];
  }

  // ---------- 환급 (정산 완료) ----------
  List<Widget> _reviewBody(TripDetail detail) {
    return [
      AppCard(
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppColors.p50, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                color: AppColors.p600, size: 28),
          ),
          const SizedBox(height: 10),
          Text('정산 신청 완료',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            '수고하셨어요! 환급은 보통 1~2개월 뒤 지자체에서 개별 안내돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink5),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '환급금, 어디서 쓸까?',
        subtitle: '환급받은 지역화폐 사용처를 미리 둘러보세요.',
        child: _LinkRow(
            icon: Icons.storefront_outlined,
            title: '지역화폐 사용처 보기',
            subtitle: '온라인몰 · 가맹점 지도',
            onTap: () => _todo('온라인몰 탭에서 확인할 수 있어요.')),
      ),
      const SizedBox(height: 14),
      _SectionCard(
        title: '이번 여행 후기 남기기',
        subtitle: '영수증 카드로 이번 여행을 커뮤니티에 공유해보세요 (금액 비공개).',
        child: _NextBar(
            label: '후기 올리기',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReceiptCardScreen(tripId: detail.trip.id)))),
      ),
    ];
  }

  Future<void> _openSubmission(TripDetail detail) async {
    final hasEvidence = detail.uploadedFiles.any((f) =>
            f.fileCategory == FileCategory.authPhoto ||
            f.fileCategory == FileCategory.receiptImage ||
            f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;
    if (!hasEvidence) {
      _todo('제출할 증빙이 아직 없어요.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            SubmissionPackageScreen(tripId: widget.tripId, detail: detail)));
    await _reload();
  }

  Future<void> _markSettled(int tripId) async {
    await AppScope.of(context).setTripApplicationStatus(tripId, true);
    await _reload();
  }

  void _todo(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ===== 헤더 카드 =====
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.trip, required this.stage});
  final TripSummary trip;
  final _Stage stage;

  (String, PillTone, String) _meta() {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(trip.startDate);
    final end = DateUtils.dateOnly(trip.endDate);
    return switch (stage) {
      _Stage.before => (
          '여행 전',
          PillTone.sky,
          '출발 D-${start.difference(today).inDays}'
        ),
      _Stage.during => (
          '여행 중',
          PillTone.success,
          'Day ${today.difference(start).inDays + 1} / ${end.difference(start).inDays + 1}'
        ),
      _Stage.settle => ('정산 신청', PillTone.warning, '여행 종료'),
      _Stage.review => ('정산 완료', PillTone.gray, '여행 종료'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone, dday) = _meta();
    final nights = trip.endDate.difference(trip.startDate).inDays;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill(label, tone: tone),
            const Spacer(),
            Text(dday,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink5)),
          ]),
          const SizedBox(height: 14),
          Text('${trip.regionName} $nights박${nights + 1}일',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            '${_d(trip.startDate)} ~ ${_d(trip.endDate)} · ${trip.travelerCount}명',
            style: const TextStyle(
                fontFamily: 'Pretendard', fontSize: 13, color: AppColors.ink5),
          ),
        ],
      ),
    );
  }
}

// ===== 단계 바 =====
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    const labels = ['여행 전', '여행 중', '정산', '환급'];
    final current = _Stage.values.indexOf(stage);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < current
                      ? AppColors.p500
                      : (i == current ? AppColors.p500 : AppColors.track),
                  shape: BoxShape.circle,
                ),
                child: i < current
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Text('${i + 1}',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: i == current
                                ? Colors.white
                                : AppColors.ink4)),
              ),
              const SizedBox(height: 5),
              Text(labels[i],
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: i <= current ? AppColors.ink7 : AppColors.ink4)),
            ]),
          ),
          if (i < labels.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                  width: 16,
                  height: 2,
                  color: i < current ? AppColors.p300 : AppColors.line),
            ),
        ],
      ],
    );
  }
}

// ===== 섹션 카드 =====
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final Widget child;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (trailing != null) ...[
              const Spacer(),
              Text(trailing!,
                  style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.p600)),
            ],
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.ink5)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final SavedCourse? course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '확정 코스',
      child: Material(
        color: AppColors.p50,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.field),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.white, shape: BoxShape.circle),
                child: const Icon(Icons.route_rounded,
                    color: AppColors.p600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course?.title ?? '코스를 정해보세요',
                        style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink9)),
                    const SizedBox(height: 2),
                    Text(
                        course == null
                            ? '아직 확정 코스가 없어요'
                            : '${course!.regionName} · ${course!.stops.length}곳',
                        style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            color: AppColors.ink5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.p600),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({
    required this.label,
    required this.valueText,
    required this.ratio,
    this.green = false,
  });
  final String label;
  final String valueText;
  final double ratio;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink7)),
          const Spacer(),
          Text(valueText,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.track,
            valueColor: AlwaysStoppedAnimation(
                green ? AppColors.success : AppColors.p500),
          ),
        ),
      ],
    );
  }
}

class _NextBar extends StatelessWidget {
  const _NextBar({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.p50,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.p700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.p600),
          ]),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(
      {required this.label, required this.checked, required this.onTap});
  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? AppColors.p500 : AppColors.white,
              shape: BoxShape.circle,
              border: checked
                  ? null
                  : Border.all(color: AppColors.gray, width: 1.6),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: checked ? AppColors.ink5 : AppColors.ink9)),
          ),
        ]),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow(
      {required this.icon, required this.label, required this.when});
  final IconData icon;
  final String label;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.ink4),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink7)),
        ),
        Text(when,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink4)),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surf,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: AppColors.white, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.ink7, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink9)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: AppColors.ink5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
          ]),
        ),
      ),
    );
  }
}

String _d(DateTime d) => '${d.month}.${d.day}';

String _man(int won) {
  if (won >= 10000) {
    final man = won / 10000;
    final t =
        man == man.roundToDouble() ? man.toStringAsFixed(0) : man.toStringAsFixed(1);
    return '$t만';
  }
  return '$won원';
}
