import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/auth_photo_upload_screen.dart';
import '../../screens/youtube_course_analysis_screen.dart';
import '../../screens/lodging_form_screen.dart';
import '../../screens/planner_screen.dart';
import '../../screens/receipt_evidence_screen.dart';
import '../../screens/settlement_screen.dart';
import '../../screens/submission_package_screen.dart';
import '../data/models.dart' as mock;
import '../state/app_state.dart' as mock;
import '../theme/app_colors.dart';
import 'course_flow.dart';
import '../widgets/region_art.dart';
import '../widgets/ui.dart';
import 'my_trips_tab.dart' show TripStageView, dateRangeOf, durationLabelOf, regionEmojiOf, stageOf;

/// 여행 상세 (S2-3, 4단계 컨트롤 센터) — 목업 UI + TripDetail 실데이터.
/// 기록·증빙·정산은 연동된 기존 화면으로 라우팅한다.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;

  // 출발 준비 체크리스트 — 서버 저장(핸드오프 E). 백엔드 배포 전엔 기본 4항목 폴백.
  List<ChecklistItem> _checklist = ChecklistItem.defaults();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
    _initialized = true;
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    try {
      final items =
          await AppScope.of(context).repository.getTripChecklist(widget.tripId);
      if (!mounted || items.isEmpty) return;
      setState(() => _checklist = items);
    } catch (_) {
      // 체크리스트 API 미배포 — 기본 항목으로 표시.
    }
  }

  void _toggleChecklist(int index) {
    setState(() {
      _checklist = [
        for (var i = 0; i < _checklist.length; i++)
          i == index
              ? _checklist[i].copyWith(checked: !_checklist[i].checked)
              : _checklist[i],
      ];
    });
    // 낙관 갱신 후 서버 저장 — 실패해도 화면 상태 유지.
    AppScope.of(context)
        .repository
        .updateTripChecklist(widget.tripId, _checklist)
        .catchError((_) => _checklist);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
    });
  }

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _reload());
  }

  /// 유튜브 실분석 — 링크 입력 시트 → 실서버 잡 생성·진행 화면(여행 연결 유지).
  Future<void> _openYoutubeAnalysis(TripDetail detail) async {
    final controller = TextEditingController();
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 4, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('유튜브 영상 링크',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
            const SizedBox(height: 8),
            const Text('여행 브이로그 링크를 붙여넣으면 영상 속 장소로 코스를 완성해요. 분석은 백그라운드에서 진행돼요.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://youtu.be/...',
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.ink4),
                filled: true,
                fillColor: AppColors.surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                child: const Text('코스 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => YoutubeCourseAnalysisScreen(
            tripDetail: detail, youtubeUrl: url)));
    await _reload();
  }

  /// 코스 만들기 — 목업 1:1 코스 플로우(course_flow)를 실여행 프록시로 태우고,
  /// 확정 코스가 생기면 saveCourse + selectCourseForTrip으로 실여행에 연결한다.
  Future<void> _openCourseCreate(TripDetail detail) async {
    final trip = detail.trip;
    final proxy = mock.Trip(
      emoji: regionEmojiOf(trip.regionName),
      name: '${trip.regionName} ${durationLabelOf(trip)}',
      region: trip.regionName,
      dateLabel: dateRangeOf(trip),
      people: trip.travelerCount,
      stage: mock.TripStage.before,
      nights: trip.endDate.difference(trip.startDate).inDays,
    );
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (builderContext) => CourseCreateScreen(
              forTrip: proxy,
              onYoutubeForTrip: () => _openYoutubeAnalysis(detail),
            )));
    final course = proxy.course;
    if (course == null || !mounted) return;

    final controller = AppScope.of(context);
    final saved = SavedCourse(
      id: 'trip${trip.id}-${DateTime.now().millisecondsSinceEpoch}',
      regionId: trip.regionId,
      regionName: trip.regionName,
      title: course.title,
      preferences: const [],
      stops: [
        for (final stop in course.stops)
          SavedCourseStop(
            placeId: 0,
            name: stop.name,
            address: '',
            latitude: 0,
            longitude: 0,
            sourceType: 'MANUAL',
          ),
      ],
      createdAt: DateTime.now(),
    );
    await controller.saveCourse(saved);
    await controller.selectCourseForTrip(tripId: trip.id, courseId: saved.id);
    // 플래너·지도는 여행 장소(selectedPlaces)를 읽으므로 코스 스톱을 함께 반영한다.
    try {
      await controller.repository.replaceTripPlaces(trip.id, [
        for (var i = 0; i < course.stops.length; i++)
          TripPlaceItem(
            id: 0,
            placeType: PlaceCategory.halfPrice,
            referencePlaceId: 0,
            placeName: course.stops[i].name,
            address: '',
            visitOrder: i + 1,
            latitude: null,
            longitude: null,
            checked: false,
          ),
      ]);
    } catch (_) {}
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TripDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('여행 상세')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('여행 정보를 불러오지 못했어요.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('여행 상세')),
            body: const Center(
                child: CircularProgressIndicator(color: AppColors.p500)),
          );
        }

        final detail = snapshot.data!;
        final stage = stageOf(detail.trip);
        return DetailScaffold(
          title: '${detail.trip.regionName} ${durationLabelOf(detail.trip)}',
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: switch (stage) {
            TripStageView.before => _before(detail),
            TripStageView.during => _during(detail),
            TripStageView.settle => _settle(detail),
            TripStageView.review => _review(detail),
          },
        );
      },
    );
  }

  // ───────────────────── 여행 전
  List<Widget> _before(TripDetail detail) {
    final controller = AppScope.of(context);
    final course = controller.selectedCourseForTrip(detail.trip.id);
    return [
      _TripHeader(detail: detail, stage: TripStageView.before),
      const _StageBar(current: 0),
      _DCard(title: '여행 코스', children: [
        if (course != null)
          SurfRow(
            icon: Icons.route_outlined,
            title: course.title,
            subtitle: '${course.regionName} · ${course.stops.length}곳',
            tinted: true,
            onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
          )
        else ...[
          OutlineButton('코스 추가하기',
              icon: Icons.add_rounded,
              onTap: () => _openCourseCreate(detail)),
          OutlineButton('${detail.trip.regionName} 인기 코스 보러 가기',
              icon: Icons.chat_bubble_outline_rounded,
              trailingIcon: Icons.chevron_right_rounded,
              onTap: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                mock.AppState.I.communityRegion.value = detail.trip.regionName;
                mock.AppState.I.tabRequest.value = 3;
              }),
        ],
      ]),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('출발 준비 체크리스트',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const Spacer(),
            Text('${_checklist.where((c) => c.checked).length}/${_checklist.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
          ]),
          const SizedBox(height: 10),
          for (var i = 0; i < _checklist.length; i++)
            InkWell(
              onTap: () => _toggleChecklist(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _checklist[i].checked ? AppColors.p500 : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: _checklist[i].checked
                          ? null
                          : Border.all(color: AppColors.line, width: 2),
                    ),
                    child: _checklist[i].checked
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(_checklist[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _checklist[i].checked ? AppColors.ink5 : AppColors.ink9,
                          decoration: _checklist[i].checked
                              ? TextDecoration.lineThrough
                              : null,
                        )),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      _DCard(
        title: '여행 중 · 후 할 일',
        sub: '출발하면 순서대로 열려요. 눌러서 준비 방법을 미리 확인해두세요.',
        children: [
          for (var i = 0; i < _taskGuides.length; i++)
            _UpRow(
              icon: _taskGuides[i].$1,
              label: _taskGuides[i].$2,
              when: _taskGuides[i].$3,
              onTap: () => _showTaskGuide(i),
            ),
        ],
      ),
    ];
  }

  // ───────────────────── 여행 중
  List<Widget> _during(TripDetail detail) {
    final controller = AppScope.of(context);
    final course = controller.selectedCourseForTrip(detail.trip.id);
    final authCertified = detail.trip.authCertifiedCount ??
        detail.uploadedFiles
            .where((f) => f.fileCategory == FileCategory.authPhoto)
            .length;
    final authRequired = detail.trip.authRequiredCount ?? 2;
    final spent = detail.trip.totalSpentAmount;
    final goal = detail.trip.refundConditionAmount;
    final lodgingDone = detail.uploadedFiles
            .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;

    return [
      _TripHeader(detail: detail, stage: TripStageView.during),
      const _StageBar(current: 1),
      _DCard(title: '관광지 인증', children: [
        ProgressGauge(
          label: '관광지 인증샷',
          value: '${authCertified.clamp(0, authRequired)} / $authRequired곳',
          progress: (authCertified / authRequired).clamp(0.0, 1.0),
          green: true,
        ),
        _NextLink('인증샷 추가하기',
            onTap: () => _push(AuthPhotoUploadScreen(tripId: widget.tripId))),
      ]),
      _DCard(title: '소비 기록', children: [
        ProgressGauge(
          label: goal > 0 ? '누적 소비 (조건 ${_man(goal)})' : '누적 소비',
          value: goal > 0 ? '${_man(spent)} / ${_man(goal)}' : _man(spent),
          progress: goal > 0 ? (spent / goal).clamp(0.0, 1.0) : 0.0,
        ),
        _NextLink('영수증 추가하기',
            onTap: () => _push(ReceiptEvidenceScreen(tripId: widget.tripId))),
      ]),
      _DCard(
        title: '숙박확인서',
        sub: '체크아웃 때 사장님 서명을 받아 작성하면 정산이 편해져요.',
        children: [
          _NextLink(lodgingDone ? '숙박확인서 확인하기' : '숙박확인서 작성하기',
              onTap: () => _push(LodgingFormScreen(tripId: widget.tripId))),
        ],
      ),
      if (course != null)
        _DCard(
          titleWidget: Row(children: [
            const Text('오늘 동선',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const Spacer(),
            GestureDetector(
              onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
              child: const Text('코스 전체 보기 ›',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
            ),
          ]),
          children: [
            SurfRow(
              icon: Icons.route_outlined,
              title: course.title,
              subtitle: '${course.regionName} · ${course.stops.length}곳',
              tinted: true,
              onTap: () => _push(PlannerScreen(tripId: widget.tripId)),
            ),
          ],
        )
      else
        _DCard(title: '여행 코스', children: [
          OutlineButton('코스 추가하기',
              icon: Icons.add_rounded,
              onTap: () => _openCourseCreate(detail)),
        ]),
    ];
  }

  // ───────────────────── 정산
  List<Widget> _settle(TripDetail detail) {
    final authCount = detail.trip.authCertifiedCount ??
        detail.uploadedFiles
            .where((f) => f.fileCategory == FileCategory.authPhoto)
            .length;
    final authRequired = detail.trip.authRequiredCount ?? 2;
    final lodgingDone = detail.uploadedFiles
            .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;
    final spentOk = detail.trip.refundConditionAmount <= 0 ||
        detail.trip.totalSpentAmount >= detail.trip.refundConditionAmount;

    return [
      _TripHeader(detail: detail, stage: TripStageView.settle),
      const _StageBar(current: 2),
      _DCard(title: '증빙 자료 준비', children: [
        _CheckLine('관광지 인증샷 ${authCount.clamp(0, authRequired)}/$authRequired',
            done: authCount >= authRequired),
        _CheckLine(
          '영수증 · 소비 ${_man(detail.trip.totalSpentAmount)}${spentOk ? ' (조건 충족)' : ''}',
          done: detail.receipts.isNotEmpty && spentOk,
        ),
        _CheckLine('숙박확인서 ${lodgingDone ? '서명 완료' : '미작성'}', done: lodgingDone),
      ]),
      _DCard(
        title: '증빙 패키지',
        sub: '인증샷 + 영수증 + 숙박확인서를 제출 규격 PDF로 자동 병합해요.',
        children: [
          _NextLink('증빙 패키지 만들기',
              onTap: () => _push(SubmissionPackageScreen(
                    tripId: widget.tripId,
                    detail: detail,
                    showSettlementButton: false,
                  ))),
        ],
      ),
      _DCard(
        title: '정산 신청',
        sub: '증빙 패키지를 지자체 정산 페이지에 제출하세요.',
        children: [
          _NextLink('정산 신청하러 가기',
              onTap: () => _push(SettlementScreen(tripId: widget.tripId))),
        ],
      ),
    ];
  }

  // ───────────────────── 환급 대기
  List<Widget> _review(TripDetail detail) {
    return [
      _TripHeader(detail: detail, stage: TripStageView.review),
      const _StageBar(current: 3),
      AppCard(
        child: Column(children: const [
          SizedBox(height: 4),
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.p50,
            child: Icon(Icons.check_rounded, size: 28, color: AppColors.p600),
          ),
          SizedBox(height: 12),
          Text('정산 신청 완료',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '수고하셨어요! 환급은 '),
              TextSpan(text: '보통 1~2개월 뒤', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
              TextSpan(text: ' 지자체에서 개별 안내돼요.'),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5),
          ),
        ]),
      ),
      _DCard(
        title: '환급금, 어디서 쓸까?',
        sub: '환급받은 지역화폐 사용처를 미리 둘러보세요.',
        children: [
          SurfRow(
            icon: Icons.shopping_bag_outlined,
            title: '지역화폐 사용처 보기',
            subtitle: '${detail.trip.regionName} 온라인몰 · 가맹점 지도',
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              mock.AppState.I.tabRequest.value = 2;
            },
          ),
        ],
      ),
      _DCard(
        title: '이번 여행 후기 남기기',
        sub: '이번 여행을 커뮤니티에 공유해보세요.',
        children: [
          _NextLink('후기 올리기', onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            mock.AppState.I.communityRegion.value = detail.trip.regionName;
            mock.AppState.I.tabRequest.value = 3;
          }),
        ],
      ),
      _DCard(title: '다음 여행', children: [
        SurfRow(
          icon: Icons.route_outlined,
          title: '다음 반값여행 찾기',
          subtitle: '접수중인 다른 지역 보기',
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ]),
    ];
  }

  // ───────────────────── 여행 전 할 일 가이드

  static const _taskGuides = [
    (Icons.photo_camera_outlined, '관광지 인증샷 (EXIF)', '여행 중', [
      '지정관광지 2곳 이상에서 인증샷을 찍어야 해요.',
      '기본 카메라로 촬영해 위치·시간(GPS·EXIF) 정보가 남아야 자동 인증돼요.',
      '신청 대표자와 일행 얼굴, 배경이 함께 나오게 찍어주세요.',
      '캡처·SNS 저장본은 촬영 정보가 지워져 인증이 어려워요.',
    ]),
    (Icons.credit_card_rounded, '영수증 OCR · 소비 추적', '여행 중', [
      '인정 결제수단: 지역화폐 · 신청 대표자 명의 카드 · 현금영수증.',
      '최소 소비 조건은 지역 공고 기준이에요.',
      '영수증 사진을 올리면 상호·금액·결제수단을 자동으로 인식해 누적 소비로 관리해줘요.',
      '간이영수증·계좌이체는 인정되지 않을 수 있어요.',
    ]),
    (Icons.bed_outlined, '숙박확인서 작성·서명', '여행 중', [
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
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 22, color: AppColors.p600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
            ),
            Pill(timing, tone: timing == '여행 중' ? PillTone.sky : PillTone.gray),
          ]),
          const SizedBox(height: 18),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(color: AppColors.p400, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(bullet,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
                ),
              ]),
            ),
          const SizedBox(height: 6),
          const NoteRow('여행이 시작되면 이 화면에서 바로 등록할 수 있어요.'),
          const SizedBox(height: 18),
          Row(children: [
            PrimaryButton('확인했어요', onTap: () => Navigator.of(context).pop()),
          ]),
        ]),
      ),
    );
  }

  String _man(int amount) => amount >= 10000 ? '${amount ~/ 10000}만원' : '$amount원';
}

// ───────────────────── 공용 조각 (목업 스타일)

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.detail, required this.stage});

  final TripDetail detail;
  final TripStageView stage;

  @override
  Widget build(BuildContext context) {
    final trip = detail.trip;
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(trip.startDate);
    final totalDays = trip.endDate.difference(trip.startDate).inDays + 1;

    final (pill, tone) = switch (stage) {
      TripStageView.before => ('여행 전', PillTone.sky),
      TripStageView.during => ('여행 중', PillTone.live),
      TripStageView.settle => ('정산 신청', PillTone.warn),
      TripStageView.review => ('정산 완료', PillTone.gray),
    };
    final dday = switch (stage) {
      TripStageView.before => '출발 D-${start.difference(today).inDays}',
      TripStageView.during => 'Day ${today.difference(start).inDays + 1} / $totalDays',
      TripStageView.settle => '여행 종료',
      TripStageView.review => '여행 종료',
    };

    return AppCard(
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
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${trip.regionName} ${durationLabelOf(trip)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 3),
            Text('${dateRangeOf(trip)} · ${trip.travelerCount}명',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ]),
      ]),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.current});
  final int current;

  static const _labels = ['여행 전', '여행 중', '정산', '환급'];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < current
                      ? AppColors.p100
                      : (i == current ? AppColors.p500 : AppColors.track),
                  shape: BoxShape.circle,
                ),
                child: i < current
                    ? const Icon(Icons.check_rounded, size: 15, color: AppColors.p600)
                    : Text('${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: i == current ? Colors.white : AppColors.ink4,
                        )),
              ),
              const SizedBox(height: 6),
              Text(_labels[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: i <= current ? AppColors.ink9 : AppColors.ink4,
                  )),
            ]),
          ),
      ]),
    );
  }
}

class _DCard extends StatelessWidget {
  const _DCard({this.title, this.titleWidget, this.sub, required this.children});
  final String? title;
  final Widget? titleWidget;
  final String? sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        titleWidget ??
            Text(title!,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
        ],
        for (final child in children) ...[const SizedBox(height: 13), child],
      ]),
    );
  }
}

class _NextLink extends StatelessWidget {
  const _NextLink(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.p600)),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.p600),
      ]),
    );
  }
}

class _UpRow extends StatelessWidget {
  const _UpRow({required this.icon, required this.label, required this.when, required this.onTap});
  final IconData icon;
  final String label;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: AppColors.p600),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
        ),
        Text(when,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
      ]),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text, {this.done = true});
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: done ? AppColors.p500 : AppColors.track,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(Icons.check_rounded, size: 15, color: done ? Colors.white : AppColors.ink4),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.ink9 : AppColors.ink5)),
      ),
    ]);
  }
}
