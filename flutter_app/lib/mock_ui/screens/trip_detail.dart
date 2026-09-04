import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/auth_photo_upload_screen.dart';
import '../../screens/youtube_course_start_screen.dart';
import '../../screens/youtube_travel_plan_screen.dart';
import '../../screens/lodging_form_screen.dart';
import '../../screens/receipt_evidence_screen.dart';
import '../../screens/settlement_screen.dart';
import '../../screens/submission_package_screen.dart';
import '../data/models.dart' as mock;
import '../state/app_state.dart' as mock;
import '../theme/app_colors.dart';
import 'community.dart';
import 'course_flow.dart';
import '../widgets/region_art.dart';
import '../widgets/ui.dart';
import 'my_trips_tab.dart'
    show TripStageView, dateRangeOf, durationLabelOf, regionEmojiOf,
        settlementExpired, stageOf;

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
      final items = await AppScope.of(
        context,
      ).repository.getTripChecklist(widget.tripId);
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
    AppScope.of(context).repository
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _reload());
  }

  /// 유튜브 실분석 — 링크 입력 시트 → 실서버 잡 생성·진행 화면(여행 연결 유지).
  Future<void> _openYoutubeAnalysis(TripDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: kCourseCreationFlowRoute),
        builder: (_) => YoutubeCourseStartScreen(tripDetail: detail),
      ),
    );
    await _reload();
  }

  /// 코스 상세 보기 — 코스함 상세와 완전히 같은 화면(지도+DAY+번호 리스트).
  /// 수정은 우측 상단 연필(통일된 CourseEditScreen), ⋯에는 등록취소·삭제만.
  void _openCourseView(TripDetail detail, SavedCourse course) {
    final c = _asViewCourse(course);
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CourseViewScreen(
            course: c,
            startDate: detail.trip.startDate,
            // 편집 저장 후 실스토어(코스함)에 반영 — 여행 코스도 원본은 코스함.
            // 플래너·지도는 여행 장소(selectedPlaces)를 읽으므로 스톱도 함께 동기화한다
            // (안 하면 코스만 바뀌고 일정·지도는 옛 장소로 남는다).
            onEdited: () async {
              final controller = AppScope.of(context);
              final stops = savedStopsFromCourse(c.stops);
              await controller.saveCourse(SavedCourse(
                id: course.id,
                regionId: course.regionId,
                regionName: course.regionName,
                title: c.title,
                preferences: course.preferences,
                stops: stops,
                createdAt: course.createdAt,
              ));
              try {
                await controller.repository.replaceTripPlaces(detail.trip.id, [
                  for (var i = 0; i < stops.length; i++)
                    TripPlaceItem(
                      id: 0,
                      placeType: PlaceCategory.halfPrice,
                      referencePlaceId: stops[i].placeId,
                      placeName: stops[i].name,
                      address: stops[i].address,
                      visitOrder: i + 1,
                      latitude: stops[i].latitude,
                      longitude: stops[i].longitude,
                      checked: false,
                    ),
                ]);
              } catch (_) {}
            },
            onMore: () async {
              final action = await _openCourseActions(detail, course);
              // 등록취소·삭제됐으면 이 코스 상세는 더 보여줄 게 없다 — 여행 상세로 복귀.
              if ((action == 'unlink' || action == 'delete') && mounted) {
                Navigator.of(context).pop();
              }
            },
            // 상세 계획표 — 코스 스톱을 날짜·시간표로.
            onOpenPlan: () => _push(YoutubeTravelPlanScreen(
                course: course, tripDetail: detail)),
          ),
        ))
        .then((_) => _reload());
  }

  /// SavedCourse(실모델) → 표시용 Course — 코스함과 같은 변환기 사용 (DAY·시간 보존).
  mock.Course _asViewCourse(SavedCourse course) => courseFromSaved(course);

  Future<String?> _openCourseActions(TripDetail detail, SavedCourse course) async {
    final action = await showAppSheet<String>(
      context,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(course.title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9)),
          ),
        ),
        // 코스 수정은 상세 화면 우측 상단 연필로 — 이 시트에는 등록취소/삭제만.
        ListTile(
          leading: const Icon(Icons.link_off_rounded,
              size: 20, color: AppColors.ink7),
          title: const Text('여행 코스 등록 취소',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: const Text('코스는 코스함에 남아요',
              style: TextStyle(fontSize: 12, color: AppColors.ink4)),
          onTap: () => Navigator.of(context).pop('unlink'),
        ),
        ListTile(
          leading:
              const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
          title: const Text('코스함에서 삭제',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger)),
          subtitle: const Text('여행 등록도 함께 취소돼요',
              style: TextStyle(fontSize: 12, color: AppColors.ink4)),
          onTap: () => Navigator.of(context).pop('delete'),
        ),
        const SizedBox(height: 10),
      ]),
    );
    if (!mounted || action == null) return null;
    final controller = AppScope.of(context);
    switch (action) {
      case 'unlink':
        final ok = await showConfirmDialog(
          context,
          title: '여행 코스 등록을 취소할까요?',
          message: '이 여행에서만 빠지고, 코스는 코스함에 그대로 남아요.',
          confirmLabel: '등록 취소',
        );
        if (!ok || !mounted) return null;
        await controller.unselectCourseForTrip(detail.trip.id);
        if (mounted) {
          setState(() {});
          showToast(context, '여행 코스 등록을 취소했어요. 코스는 코스함에 있어요.');
        }
      case 'delete':
        final ok = await showConfirmDialog(
          context,
          title: '코스를 삭제할까요?',
          message: '여행 등록도 함께 취소되고 코스함에서 사라져요. 되돌릴 수 없어요.',
          confirmLabel: '삭제',
          danger: true,
        );
        if (!ok || !mounted) return null;
        await controller.deleteSavedCourse(course.id);
        if (mounted) {
          setState(() {});
          showToast(context, '코스를 코스함에서 삭제했어요.');
        }
    }
    return action;
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
      backendId: trip.id,
      startDate: trip.startDate,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: kCourseCreationFlowRoute),
        builder:
            (builderContext) => CourseCreateScreen(
              forTrip: proxy,
              onYoutubeForTrip: () => _openYoutubeAnalysis(detail),
            ),
      ),
    );
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
            placeId: stop.placeId ?? 0,
            name: stop.name,
            address: stop.address ?? '',
            latitude: stop.latitude ?? 0,
            longitude: stop.longitude ?? 0,
            sourceType: 'MANUAL',
            // DAY·시간을 보존해야 코스함/여행 코스 보기에서 일차별 일정이 산다.
            day: stop.day,
            time: stop.time,
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
            referencePlaceId: course.stops[i].placeId ?? 0,
            placeName: course.stops[i].name,
            address: course.stops[i].address ?? '',
            visitOrder: i + 1,
            latitude: course.stops[i].latitude,
            longitude: course.stops[i].longitude,
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
                child: Text(
                  '여행 정보를 불러오지 못했어요.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('여행 상세')),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.p500),
            ),
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
      _DCard(
        title: '여행 코스',
        children: [
          if (course != null)
            // 코스가 있으면 새로 만들기 동선은 숨긴다. 탭하면 수정·등록취소·삭제.
            SurfRow(
              icon: Icons.route_outlined,
              title: course.title,
              subtitle: '${course.regionName} · ${course.stops.length}곳',
              tinted: true,
              onTap: () => _openCourseView(detail, course),
            )
          else ...[
            OutlineButton(
              '코스 추가하기',
              icon: Icons.add_rounded,
              onTap: () => _openCourseCreate(detail),
            ),
            // 이 지역에 참고할 코스(코스 글 또는 코스가 첨부된 후기 등)가 있을 때만
            // 노출 — 눌렀는데 빈 피드가 나오지 않게.
            if (mock.AppState.I.posts.any((p) =>
                !p.private &&
                p.region == detail.trip.regionName &&
                (p.tag == mock.PostTag.course || p.courseName != null)))
              OutlineButton(
                '${detail.trip.regionName} 인기 코스 보러 가기',
                icon: Icons.chat_bubble_outline_rounded,
                trailingIcon: Icons.chevron_right_rounded,
                // 탭 전환 대신 "이 지역 인기 코스 모음"을 push — 뒤로가기로
                // 여행 상세에 그대로 복귀한다. 코스 글·코스 첨부 글만 인기순.
                onTap: () => _push(CommunityFeedScreen(
                  region: detail.trip.regionName,
                  courseOnly: true,
                )),
              ),
          ],
        ],
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '출발 준비 체크리스트',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9,
                    letterSpacing: -.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_checklist.where((c) => c.checked).length}/${_checklist.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.p600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _checklist.length; i++)
              InkWell(
                onTap: () => _toggleChecklist(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      AppCheckbox(checked: _checklist[i].checked),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _checklist[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                _checklist[i].checked
                                    ? AppColors.ink5
                                    : AppColors.ink9,
                            decoration:
                                _checklist[i].checked
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      _DCard(
        title: '여행 중 · 후 할 일',
        sub: '여행일이 다가오면 순서대로 열려요. 눌러서 준비 방법을 미리 확인해두세요.',
        children: [
          for (var i = 0; i < _taskGuides.length; i++)
            _UpRow(
              icon: _taskGuides[i].$1,
              label: _taskGuides[i].$2,
              when: _taskGuides[i].$3,
              onTap: () => _showTaskGuide(i, detail),
            ),
        ],
      ),
    ];
  }

  // ───────────────────── 여행 중
  List<Widget> _during(TripDetail detail) {
    final controller = AppScope.of(context);
    final course = controller.selectedCourseForTrip(detail.trip.id);
    final authCertified =
        detail.trip.authCertifiedCount ??
        detail.uploadedFiles
            .where((f) => f.fileCategory == FileCategory.authPhoto)
            .length;
    final authRequired = detail.trip.authRequiredCount ?? 2;
    final spent = detail.trip.totalSpentAmount;
    final goal = detail.trip.refundConditionAmount;
    final lodgingDone =
        detail.uploadedFiles.any(
          (f) => f.fileCategory == FileCategory.lodgingConfirmation,
        ) ||
        detail.lodgingInfo?.uploadedFileId != null;

    return [
      _TripHeader(detail: detail, stage: TripStageView.during),
      const _StageBar(current: 1),
      _DCard(
        title: '관광지 인증',
        children: [
          ProgressGauge(
            label: '관광지 인증샷',
            value: '${authCertified.clamp(0, authRequired)} / $authRequired곳',
            progress: (authCertified / authRequired).clamp(0.0, 1.0),
            green: true,
          ),
          _NextLink(
            '인증샷 추가하기',
            onTap: () => _push(AuthPhotoUploadScreen(tripId: widget.tripId)),
          ),
        ],
      ),
      _DCard(
        title: '소비 기록',
        children: [
          ProgressGauge(
            label: goal > 0 ? '누적 소비 (조건 ${_man(goal)})' : '누적 소비',
            value: goal > 0 ? '${_man(spent)} / ${_man(goal)}' : _man(spent),
            progress: goal > 0 ? (spent / goal).clamp(0.0, 1.0) : 0.0,
          ),
          _NextLink(
            '영수증 추가하기',
            onTap: () => _push(ReceiptEvidenceScreen(tripId: widget.tripId)),
          ),
        ],
      ),
      _DCard(
        title: '숙박확인서',
        sub: '체크아웃 때 사장님 서명을 받아 작성하면 정산이 편해져요.',
        children: [
          _NextLink(
            lodgingDone ? '숙박확인서 확인하기' : '숙박확인서 작성하기',
            onTap: () => _push(LodgingFormScreen(tripId: widget.tripId)),
          ),
        ],
      ),
      if (course != null)
        _DCard(
          titleWidget: Row(
            children: [
              const Text(
                '오늘 동선',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openCourseView(detail, course),
                child: const Text(
                  '코스 전체 보기 ›',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.p600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            SurfRow(
              icon: Icons.route_outlined,
              title: course.title,
              subtitle: '${course.regionName} · ${course.stops.length}곳',
              tinted: true,
              onTap: () => _openCourseView(detail, course),
            ),
          ],
        )
      else
        _DCard(
          title: '여행 코스',
          children: [
            OutlineButton(
              '코스 추가하기',
              icon: Icons.add_rounded,
              onTap: () => _openCourseCreate(detail),
            ),
          ],
        ),
    ];
  }

  // ───────────────────── 정산
  List<Widget> _settle(TripDetail detail) {
    final authCount =
        detail.trip.authCertifiedCount ??
        detail.uploadedFiles
            .where((f) => f.fileCategory == FileCategory.authPhoto)
            .length;
    final authRequired = detail.trip.authRequiredCount ?? 2;
    final lodgingDone =
        detail.uploadedFiles.any(
          (f) => f.fileCategory == FileCategory.lodgingConfirmation,
        ) ||
        detail.lodgingInfo?.uploadedFileId != null;
    final spentOk =
        detail.trip.refundConditionAmount <= 0 ||
        detail.trip.totalSpentAmount >= detail.trip.refundConditionAmount;

    final expired = settlementExpired(detail.trip);
    final course = AppScope.of(context).selectedCourseForTrip(detail.trip.id);

    return [
      _TripHeader(detail: detail, stage: TripStageView.settle),
      const _StageBar(current: 2),
      // 다녀온 코스 — 여행 전·중과 같은 통일 코스 상세(지도+DAY+번호)로 연다.
      if (course != null) _courseCard(detail, course),
      // 마감 지난 여행 — 목록 카드("정산 마감 지남")와 같은 말을 하도록 상세에도 알린다.
      if (expired)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '정산 신청 마감이 지났어요. 추가 접수 가능 여부는 지자체에 문의해 주세요.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink7,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      _DCard(
        title: '증빙 자료 준비',
        sub: expired
            ? '정산 마감이 지난 여행이에요. 올린 증빙은 열람용으로 남아 있어요.'
            : '여행이 끝나도 정산 전까지 자유롭게 추가·수정할 수 있어요.',
        children: [
          _CheckLine(
            '관광지 인증샷 ${authCount.clamp(0, authRequired)}/$authRequired',
            done: authCount >= authRequired,
            onTap: () => _push(AuthPhotoUploadScreen(tripId: widget.tripId)),
          ),
          _CheckLine(
            '영수증 · 소비 ${_man(detail.trip.totalSpentAmount)}${spentOk ? ' (조건 충족)' : ''}',
            done: detail.receipts.isNotEmpty && spentOk,
            onTap: () => _push(ReceiptEvidenceScreen(tripId: widget.tripId)),
          ),
          _CheckLine(
            '숙박확인서 ${lodgingDone ? '서명 완료' : '미작성'}',
            done: lodgingDone,
            onTap: () => _push(LodgingFormScreen(tripId: widget.tripId)),
          ),
        ],
      ),
      _DCard(
        title: '증빙 패키지',
        sub: '인증샷 + 영수증 + 숙박확인서를 종류별 zip으로 정리해드려요.',
        children: [
          _NextLink(
            '증빙 패키지 만들기',
            onTap:
                () => _push(
                  SubmissionPackageScreen(
                    tripId: widget.tripId,
                    detail: detail,
                    showSettlementButton: false,
                  ),
                ),
          ),
        ],
      ),
      // 마감 지난 여행에는 정산 권유 카드를 내리지 않는다 (QA 8/26 #2).
      if (!expired)
        _DCard(
          title: '정산 신청',
          sub: '증빙 패키지를 지자체 정산 페이지에 제출하세요.',
          children: [
            _NextLink(
              '정산 신청하러 가기',
              onTap: () => _push(SettlementScreen(tripId: widget.tripId)),
            ),
          ],
        ),
      // 마감 전에 지자체에서 이미 신청한 사람의 기록용 — 정산 화면 하단과 같은 링크.
      if (expired)
        Center(
          child: GestureDetector(
            onTap: () => _markSettledExternally(detail),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '이미 신청했어요 · ',
                      style: TextStyle(color: AppColors.ink5)),
                  TextSpan(
                      text: '완료로 표시',
                      style: TextStyle(
                          color: AppColors.p600,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.p600)),
                ]),
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
    ];
  }

  /// 지자체에서 이미 신청을 마친 여행을 앱에도 완료로 기록한다 (별도 정보 수집 없음).
  Future<void> _markSettledExternally(TripDetail detail) async {
    final controller = AppScope.of(context);
    await controller.runTask(() => controller.repository.applySettlement(
          widget.tripId,
          applicantName: detail.trip.applicantName,
          phoneNumber: '',
        ));
    // repository 직접 호출이라 컨트롤러 캐시(trips)가 낡은 채로 남는다 —
    // 홈의 방문 지역 표시·온라인몰 사용처가 반영되도록 함께 갱신한다.
    await controller.refreshTrips();
    await _reload();
    if (mounted) showMock(context, '정산 신청 완료로 표시했어요.');
  }

  // ───────────────────── 정산 신청 완료 (환급은 외부에서 진행)
  List<Widget> _review(TripDetail detail) {
    final course = AppScope.of(context).selectedCourseForTrip(detail.trip.id);
    return [
      _TripHeader(detail: detail, stage: TripStageView.review),
      const _StageBar(current: 3),
      if (course != null) _courseCard(detail, course),
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
          _NextLink(
            '후기 올리기',
            onTap: () {
              // 이 여행을 명시적으로 실어 후기 작성 화면을 연다. 지역만 넘기면
              // 같은 지역 여행이 여러 개일 때 인증 배지가 엉뚱한 여행을 가리킨다.
              _push(CommunityWriteScreen(
                tripId: detail.trip.id,
                regionName: detail.trip.regionName,
              ));
            },
          ),
        ],
      ),
      _DCard(
        title: '다음 여행',
        children: [
          SurfRow(
            icon: Icons.route_outlined,
            title: '다음 반값여행 찾기',
            subtitle: '접수중인 다른 지역 보기',
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    ];
  }

  /// 다녀온/확정 코스 카드 — 정산·후기 단계용. 탭하면 통일 코스 상세(_openCourseView).
  Widget _courseCard(TripDetail detail, SavedCourse course) {
    return _DCard(
      title: '다녀온 코스',
      children: [
        SurfRow(
          icon: Icons.route_outlined,
          title: course.title,
          subtitle: '${course.regionName} · ${course.stops.length}곳',
          tinted: true,
          onTap: () => _openCourseView(detail, course),
        ),
      ],
    );
  }

  // ───────────────────── 여행 전 할 일 가이드

  static const _taskGuides = [
    (
      Icons.photo_camera_outlined,
      '관광지 인증샷 (EXIF)',
      '여행 중',
      [
        '지정관광지 {n}곳 이상에서 인증샷을 찍어야 해요.',
        '기본 카메라로 촬영해 위치·시간(GPS·EXIF) 정보가 남아야 자동 인증돼요.',
        '신청 대표자와 일행 얼굴, 배경이 함께 나오게 찍어주세요.',
        '캡처·SNS 저장본은 촬영 정보가 지워져 인증이 어려워요.',
      ],
    ),
    (
      Icons.credit_card_rounded,
      '영수증 OCR · 소비 추적',
      '여행 중',
      [
        '인정 결제수단: 지역화폐 · 신청 대표자 명의 카드 · 현금영수증.',
        '최소 소비 조건은 {amount}이에요.',
        '영수증 사진을 올리면 상호·금액·결제수단을 자동으로 인식해 누적 소비로 관리해줘요.',
        '간이영수증·계좌이체는 인정되지 않을 수 있어요.',
      ],
    ),
    (
      Icons.bed_outlined,
      '숙박확인서 작성·서명',
      '여행 중',
      [
        '반값여행은 1박 숙박이 필수예요.',
        '숙소명·대표자·일정·금액을 적고 체크아웃 때 숙소 대표자 서명을 받아요.',
        '선결제한 경우 숙소 이용 완료 내역서와 결제 영수증을 함께 준비하세요.',
      ],
    ),
    (
      Icons.description_outlined,
      '증빙 패키지 · 정산 신청',
      '여행 후',
      [
        '여행이 끝나면 인증샷 + 영수증 + 숙박확인서를 종류별로 정리해 zip으로 묶어드려요.',
        '정산 신청은 {deadline}, 지자체 정산 페이지에서 해요.',
        '제출 후 심사를 거쳐 보통 1~2개월 뒤 지역화폐로 환급돼요.',
      ],
    ),
  ];

  void _showTaskGuide(int index, TripDetail detail) {
    final (icon, title, timing, rawBullets) = _taskGuides[index];
    // 안내문 골격은 고정이고, 지역마다 다른 값만 서버(여행) 데이터로 치환한다:
    //   {n}        인증 요구 개소 (게이지와 같은 폴백 2)
    //   {amount}   최소 소비 조건 금액 (지역 공고값, 없으면 '지역 공고 기준')
    //   {deadline} 정산 신청 기한 (여행 종료 다음날 기준 D일, 서버 기한 없으면 '지역 공고 기준')
    final trip = detail.trip;
    final authRequired = trip.authRequiredCount ?? 2;
    final amount = trip.refundConditionAmount > 0
        ? '${_man(trip.refundConditionAmount)} 이상 (지역 공고 기준)'
        : '지역 공고 기준';
    final due = trip.settlementDeadline;
    final String deadline;
    if (due == null) {
      deadline = '여행 종료 후 지역 공고 기한 안에';
    } else {
      final days = due.difference(trip.endDate).inDays;
      deadline = days > 0
          ? '여행 종료 다음날부터 $days일 이내(${due.month}/${due.day}까지)'
          : '${due.month}/${due.day}까지';
    }
    final bullets = [
      for (final b in rawBullets)
        b
            .replaceAll('{n}', '$authRequired')
            .replaceAll('{amount}', amount)
            .replaceAll('{deadline}', deadline),
    ];
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: AppColors.p600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                Pill(
                  timing,
                  tone: timing == '여행 중' ? PillTone.sky : PillTone.gray,
                ),
              ],
            ),
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
                        color: AppColors.p400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink7,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const NoteRow('여행이 시작되면 이 화면에서 바로 등록할 수 있어요.'),
            const SizedBox(height: 18),
            Row(
              children: [
                PrimaryButton(
                  '확인했어요',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _man(int amount) =>
      amount >= 10000 ? '${amount ~/ 10000}만원' : '$amount원';
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
      TripStageView.review => ('정산 신청 완료', PillTone.gray),
    };
    final dday = switch (stage) {
      TripStageView.before => '출발 D-${start.difference(today).inDays}',
      TripStageView.during =>
        'Day ${today.difference(start).inDays + 1} / $totalDays',
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

  // 앱이 아는 마지막 상태는 '정산 신청 완료'다. 환급 완료는 외부(지자체)에서 일어나고
  // 앱이 추적하지 않으므로, 마지막 단계를 '환급'으로 부르지 않는다.
  static const _labels = ['여행 전', '여행 중', '정산', '신청 완료'];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              // 단계 원 사이 점선 커넥터 — 지나온 구간은 파란색.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 13, left: 3, right: 3),
                  child: CustomPaint(
                    size: const Size(double.infinity, 2),
                    painter: _DashPainter(
                      color: i <= current ? AppColors.p500 : AppColors.track,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 62,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          i < current
                              ? AppColors.p100
                              : (i == current
                                  ? AppColors.p500
                                  : AppColors.track),
                      shape: BoxShape.circle,
                    ),
                    child:
                        i < current
                            ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: AppColors.p600,
                            )
                            : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color:
                                    i == current
                                        ? Colors.white
                                        : AppColors.ink4,
                              ),
                            ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: i <= current ? AppColors.ink9 : AppColors.ink4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 가로 점선 페인터 — 단계 커넥터용.
class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

class _DCard extends StatelessWidget {
  const _DCard({
    this.title,
    this.titleWidget,
    this.sub,
    required this.children,
  });
  final String? title;
  final Widget? titleWidget;
  final String? sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ??
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -.3,
                ),
              ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink5,
                height: 1.45,
              ),
            ),
          ],
          for (final child in children) ...[const SizedBox(height: 13), child],
        ],
      ),
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
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.p600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.p600,
          ),
        ],
      ),
    );
  }
}

class _UpRow extends StatelessWidget {
  const _UpRow({
    required this.icon,
    required this.label,
    required this.when,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.p600),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink9,
              ),
            ),
          ),
          Text(
            when,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text, {this.done = true, this.onTap});
  final String text;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        AppCheckbox(checked: done),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: done ? AppColors.ink9 : AppColors.ink5,
            ),
          ),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink4),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}
