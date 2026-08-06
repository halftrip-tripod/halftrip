import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';
import 'auth_photo_upload_screen.dart';
import 'lodging_form_screen.dart';
import 'course_create_screen.dart';
import 'main_navigation_screen.dart';
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
        regionName: detail.trip.regionName,
        onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
        onAdd: () => _push(CourseCreateScreen(tripDetail: detail)),
        onCommunity: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const MainNavigationScreen(initialIndex: 3)),
          (route) => false,
        ),
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
      _SectionCard(
        title: '여행 중 · 후 할 일',
        subtitle: '출발하면 순서대로 열려요. 눌러서 준비 방법을 미리 확인해두세요.',
        child: Column(children: [
          for (var i = 0; i < _taskGuides.length; i++)
            _UpcomingRow(
              icon: _taskGuides[i].$1,
              label: _taskGuides[i].$2,
              when: _taskGuides[i].$3,
              onTap: () => _showTaskGuide(i),
            ),
        ]),
      ),
    ];
  }

  /// 여행 전 할 일 준비 가이드 — 등록 화면은 여행이 시작되면 열린다.
  /// 디자인: 목업 여행 상세 가이드 시트.
  static const _taskGuides = [
    (Icons.photo_camera_outlined, '관광지 인증샷 (EXIF)', '여행 중', [
      '지정관광지 2곳 이상에서 인증샷을 찍어야 해요.',
      '기본 카메라로 촬영해 위치·시간(GPS·EXIF) 정보가 남아야 자동 인증돼요.',
      '신청 대표자와 일행 얼굴, 배경이 함께 나오게 찍어주세요.',
      '캡처·SNS 저장본은 촬영 정보가 지워져 인증이 어려워요.',
    ]),
    (Icons.receipt_long_outlined, '영수증 OCR · 소비 추적', '여행 중', [
      '인정 결제수단: 지역화폐 · 신청 대표자 명의 카드 · 현금영수증.',
      '최소 소비 조건은 지역 공고 기준이에요 (예: 개인 3만원 / 팀 5만원 이상).',
      '영수증 사진을 올리면 상호·금액·결제수단을 자동으로 인식해 누적 소비로 관리해줘요.',
      '간이영수증·계좌이체는 인정되지 않을 수 있어요.',
    ]),
    (Icons.hotel_outlined, '숙박확인서 작성·서명', '여행 중', [
      '반값여행은 1박 숙박이 필수예요.',
      '숙소명·대표자·일정·금액을 적고 체크아웃 때 숙소 대표자 서명을 받아요.',
      '선결제한 경우 숙소 이용 완료 내역서와 결제 영수증을 함께 준비하세요.',
    ]),
    (Icons.description_outlined, '증빙 패키지 · 정산 신청', '여행 후', [
      '여행이 끝나면 인증샷 + 영수증 + 숙박확인서를 제출 규격 PDF로 자동으로 묶어드려요.',
      '정산 신청은 여행 종료 다음날부터 7일 이내, 지자체 정산 페이지에서 해요.',
      '제출 후 심사를 거쳐 보통 1~2개월 뒤 지역화폐로 환급돼요.',
    ]),
  ];

  void _showTaskGuide(int index) {
    final (icon, title, timing, bullets) = _taskGuides[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(icon, size: 22, color: AppColors.p600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink9,
                          letterSpacing: -0.5)),
                ),
                Pill(timing,
                    tone: timing == '여행 중' ? PillTone.sky : PillTone.gray),
              ]),
              const SizedBox(height: 18),
              for (final bullet in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                            color: AppColors.p400, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(bullet,
                            style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink7,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              const Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.p600),
                SizedBox(width: 6),
                Expanded(
                  child: Text('여행이 시작되면 이 화면에서 바로 등록할 수 있어요.',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink5)),
                ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('확인했어요'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        regionName: detail.trip.regionName,
        onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
        onAdd: () => _push(CourseCreateScreen(tripDetail: detail)),
        onCommunity: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const MainNavigationScreen(initialIndex: 3)),
          (route) => false,
        ),
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
  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onAdd,
    required this.onCommunity,
    required this.regionName,
  });

  final SavedCourse? course;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onCommunity;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '여행 코스',
      child: course == null
          // 코스가 없으면: 만들기 + 커뮤니티 인기 코스 구경 (목업 UX)
          ? Column(children: [
              _CourseActionButton(
                icon: Icons.add_rounded,
                label: '코스 추가하기',
                onTap: onAdd,
              ),
              const SizedBox(height: 10),
              _CourseActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: '$regionName 인기 코스 보러 가기',
                trailing: Icons.chevron_right_rounded,
                onTap: onCommunity,
              ),
            ])
          : Material(
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
                          Text(course!.title,
                              style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink9)),
                          const SizedBox(height: 2),
                          Text(
                              '${course!.regionName} · ${course!.stops.length}곳',
                              style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  color: AppColors.ink5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.p600),
                  ]),
                ),
              ),
            ),
    );
  }
}

/// 코스 빈 상태 액션 버튼 (surf 배경 아웃라인 톤).
class _CourseActionButton extends StatelessWidget {
  const _CourseActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.p600),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink7)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 15, color: AppColors.ink4),
            ],
          ],
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
      {required this.icon, required this.label, required this.when, this.onTap});
  final IconData icon;
  final String label;
  final String when;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
      ),
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
