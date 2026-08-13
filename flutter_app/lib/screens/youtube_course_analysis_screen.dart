import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/place_map_view.dart';
import 'youtube_travel_plan_screen.dart';

class YoutubeCourseAnalysisScreen extends StatefulWidget {
  const YoutubeCourseAnalysisScreen({
    super.key,
    this.tripDetail,
    this.youtubeUrl = '',
    this.jobId,
  });

  final TripDetail? tripDetail;
  final String youtubeUrl;
  final String? jobId;

  @override
  State<YoutubeCourseAnalysisScreen> createState() =>
      _YoutubeCourseAnalysisScreenState();
}

class _YoutubeCourseAnalysisScreenState
    extends State<YoutubeCourseAnalysisScreen> {
  String? _jobId;
  YoutubeCourseJobItem? _job;
  String? _errorMessage;
  bool _creating = true;
  Timer? _pollingTimer;
  bool _saving = false;
  int? _selectedStopOrder;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _boot();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      _jobId = widget.jobId;
      setState(() {
        _creating = false;
      });
      await _refreshJob();
      _startPollingIfNeeded();
      return;
    }

    final controller = AppScope.of(context);
    final userId = controller.currentUser?.id;
    if (userId == null) {
      setState(() {
        _creating = false;
        _errorMessage = '로그인 정보가 없어 작업을 시작할 수 없습니다.';
      });
      return;
    }

    final tripDetail = widget.tripDetail;
    if (tripDetail == null) {
      setState(() {
        _creating = false;
        _errorMessage = '여행 정보가 없어 유튜브 코스 작업을 시작하지 못했습니다.';
      });
      return;
    }

    try {
      final response = await controller.runTask(
        () => controller.repository.createYoutubeCourseJob(
          userId: userId,
          tripId: tripDetail.trip.id,
          regionId: tripDetail.trip.regionId,
          youtubeUrl: widget.youtubeUrl,
        ),
      );
      if (!mounted) return;
      setState(() {
        _jobId = response.jobId;
        _creating = false;
      });
      await controller.trackPendingYoutubeCourseJob(
        PendingYoutubeCourseJob(
          jobId: response.jobId,
          tripId: tripDetail.trip.id,
          regionId: tripDetail.trip.regionId,
          regionName: tripDetail.trip.regionName,
          youtubeUrl: widget.youtubeUrl,
          createdAt: DateTime.now(),
        ),
      );
      await _refreshJob();
      _startPollingIfNeeded();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _errorMessage = '유튜브 코스 작업을 시작하지 못했습니다.\n$error';
      });
    }
  }

  void _startPollingIfNeeded() {
    _pollingTimer?.cancel();
    if (_job == null || _job!.isCompleted || _job!.isFailed) {
      return;
    }
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshJob();
    });
  }

  Future<void> _refreshJob() async {
    final jobId = _jobId;
    if (jobId == null || jobId.isEmpty) {
      return;
    }
    try {
      final controller = AppScope.of(context);
      final job = await controller.repository.getYoutubeCourseJob(jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _errorMessage = null;
      });
      if (job.result != null && _titleController.text.trim().isEmpty) {
        _titleController.text = job.result!.title;
      }
      if (job.tripId != null && (job.isPending || job.isProcessing)) {
        await controller.trackPendingYoutubeCourseJob(
          PendingYoutubeCourseJob(
            jobId: job.jobId,
            tripId: job.tripId!,
            regionId: job.regionId,
            regionName: job.regionName,
            youtubeUrl: job.youtubeUrl,
            createdAt: job.createdAt ?? DateTime.now(),
          ),
        );
      }
      if (job.isCompleted && job.result != null) {
        await controller.saveCompletedYoutubeCourse(job);
      }
      if (widget.tripDetail == null && job.tripId != null) {
        await controller.repository.getTripDetail(job.tripId!);
      }
      if (job.isCompleted || job.isFailed) {
        _pollingTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '작업 상태를 불러오지 못했습니다.\n$error';
      });
    }
  }

  List<PlaceMapMarkerData> _buildMarkers(YoutubeCourseJobResult result) {
    return result.stops
        .map(
          (stop) => PlaceMapMarkerData(
            id: stop.order,
            name: stop.placeName,
            address: stop.address,
            latitude: stop.latitude,
            longitude: stop.longitude,
            selected: true,
            regionLabel: stop.category,
            phoneNumber: stop.phoneNumber,
            categoryName: stop.category,
            placeUrl: stop.placeUrl,
            websiteUri: stop.websiteUri,
            internationalPhoneNumber: stop.internationalPhoneNumber,
            rating: stop.rating,
            userRatingCount: stop.userRatingCount,
            businessStatus: stop.businessStatus,
            priceLevel: stop.priceLevel,
            types: stop.types,
            openingHours: stop.openingHours,
            editorialSummary: stop.editorialSummary,
            googlePlaceDetails: stop.googlePlaceDetails,
          ),
        )
        .toList();
  }

  List<PlaceMapRoutePoint> _buildRoutePoints(YoutubeCourseJobResult result) {
    return result.stops
        .map(
          (stop) => PlaceMapRoutePoint(
            id: stop.order,
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
        )
        .toList();
  }



  Future<PlaceMapMarkerData?> _loadGoogleMarkerDetails(
    PlaceMapMarkerData marker,
  ) async {
    try {
      final controller = AppScope.of(context);
      final detail = await controller.repository.searchGooglePlaceDetail(
        placeName: marker.name,
        address: marker.address,
        latitude: marker.latitude,
        longitude: marker.longitude,
      );
      if (detail == null) {
        return null;
      }
      return PlaceMapMarkerData(
        id: marker.id,
        name: detail.placeName.isNotEmpty ? detail.placeName : marker.name,
        address: detail.address.isNotEmpty ? detail.address : marker.address,
        latitude: detail.latitude == 0 ? marker.latitude : detail.latitude,
        longitude: detail.longitude == 0 ? marker.longitude : detail.longitude,
        selected: marker.selected,
        regionLabel:
            detail.category.isNotEmpty ? detail.category : marker.regionLabel,
        imageAssetPath: marker.imageAssetPath,
        actionLabel: marker.actionLabel,
        phoneNumber:
            detail.phoneNumber.isNotEmpty
                ? detail.phoneNumber
                : marker.phoneNumber,
        roadAddress:
            detail.address.isNotEmpty ? detail.address : marker.roadAddress,
        categoryName:
            detail.category.isNotEmpty ? detail.category : marker.categoryName,
        placeUrl:
            detail.placeUrl.isNotEmpty ? detail.placeUrl : marker.placeUrl,
        websiteUri:
            detail.websiteUri.isNotEmpty
                ? detail.websiteUri
                : marker.websiteUri,
        internationalPhoneNumber:
            detail.internationalPhoneNumber.isNotEmpty
                ? detail.internationalPhoneNumber
                : marker.internationalPhoneNumber,
        rating: detail.rating ?? marker.rating,
        userRatingCount:
            detail.userRatingCount == 0
                ? marker.userRatingCount
                : detail.userRatingCount,
        businessStatus:
            detail.businessStatus.isNotEmpty
                ? detail.businessStatus
                : marker.businessStatus,
        priceLevel:
            detail.priceLevel.isNotEmpty
                ? detail.priceLevel
                : marker.priceLevel,
        types: detail.types.isNotEmpty ? detail.types : marker.types,
        openingHours:
            detail.openingHours.isNotEmpty
                ? detail.openingHours
                : marker.openingHours,
        editorialSummary:
            detail.editorialSummary.isNotEmpty
                ? detail.editorialSummary
                : marker.editorialSummary,
        googlePlaceDetails:
            detail.googlePlaceDetails.isNotEmpty
                ? detail.googlePlaceDetails
                : marker.googlePlaceDetails,
      );
    } catch (_) {
      return null;
    }
  }

  PlaceCategory _resolvePlaceCategory(YoutubeCourseJobStop stop) {
    final category = stop.category.toLowerCase();
    if (category.contains('식당') ||
        category.contains('카페') ||
        category.contains('음식') ||
        category.contains('디저트')) {
      return PlaceCategory.merchant;
    }
    return PlaceCategory.halfPrice;
  }

  Future<void> _saveToPlanner() async {
    if (_saving || _job?.result == null) return;
    final result = _job!.result!;
    if (result.stops.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장할 코스 장소가 충분하지 않습니다.')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload =
          result.stops.asMap().entries.map((entry) {
            final stop = entry.value;
            final syntheticReferenceId =
                (stop.placeName.hashCode.abs() +
                    stop.address.hashCode.abs() +
                    entry.key +
                    1) *
                -1;
            return TripPlaceItem(
              id: 0,
              placeType: _resolvePlaceCategory(stop),
              referencePlaceId: syntheticReferenceId,
              placeName: stop.placeName,
              address: stop.address,
              visitOrder: entry.key + 1,
              latitude: stop.latitude,
              longitude: stop.longitude,
              checked: true,
            );
          }).toList();

      final controller = AppScope.of(context);
      await controller.saveCompletedYoutubeCourse(
        _job!,
        preferredTitle: _titleController.text.trim(),
      );
      final savedCourse = controller.findSavedCourse(_job!.jobId);
      final tripId = widget.tripDetail?.trip.id ?? _job?.tripId;
      if (tripId == null) {
        throw Exception('저장할 여행 정보가 없습니다.');
      }
      await controller.runTask(
        () => controller.repository.replaceTripPlaces(tripId, payload),
      );
      if (savedCourse != null) {
        await controller.selectCourseForTrip(
          tripId: tripId,
          courseId: savedCourse.id,
        );
      }
      await controller.refreshTrips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생성된 코스를 현재 여행 플래너에 적용했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('플래너 적용에 실패했습니다.\n$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _openTravelPlan() {
    final job = _job;
    if (job == null || job.result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => YoutubeTravelPlanScreen(
              job: job,
              tripDetail: widget.tripDetail,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final result = job?.result;
    final markers =
        result == null ? const <PlaceMapMarkerData>[] : _buildMarkers(result);
    final routePoints =
        result == null
            ? const <PlaceMapRoutePoint>[]
            : _buildRoutePoints(result);
    final pending =
        _creating || job == null || job.isPending || job.isProcessing;

    // 처음엔 아무것도 선택하지 않는다 — 일정·핀을 탭했을 때만 포커스.
    final selectedStop =
        result == null || result.stops.isEmpty || _selectedStopOrder == null
            ? null
            : result.stops.firstWhere(
              (stop) => stop.order == _selectedStopOrder,
              orElse: () => result.stops.first,
            );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          result == null
              ? '유튜브로 코스 만들기'
              : '${job?.regionName ?? ''} 유튜브 코스'.trim(),
        ),
        actions: [
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${result.stops.length}개 장소',
                    style: const TextStyle(
                      color: AppColors.p500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // AI 코스 결과와 동일한 CTA 구성 — 상세 계획표 / 저장.
      // (다시 생성은 유튜브 분석에선 의미가 없어 두지 않는다. 8/14 규희)
      bottomNavigationBar: result == null
          ? null
          : Container(
              // AI 결과 CtaBar와 동일한 페이드 배경 — 콘텐츠가 버튼 뒤로
              // 자연스럽게 사라지는 그라데이션.
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00F7FAFD), AppColors.bg],
                  stops: [0, .4],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.p500),
                        SizedBox(width: 5),
                        Text(
                          '저장하면 내 코스함에서 자유롭게 수정할 수 있어요',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink5),
                        ),
                      ],
                    ),
                  ),
                  Row(children: [
                  Expanded(
                    // AI 결과의 "다시 생성"과 같은 톤 — 흰 배경 + 파란 글씨.
                    child: FilledButton.icon(
                      onPressed: _openTravelPlan,
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('상세 계획표'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.p600,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle:
                            const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveToPlanner,
                      icon: const Icon(Icons.bookmark_rounded, size: 18),
                      label: Text(_saving ? '저장 중...' : '내 코스함에 저장'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.p500,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle:
                            const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                    ]),
                  ]),
                ),
              ),
            ),
      body:
          result != null
              ? _CompletedItineraryView(
                result: result,
                markers: markers,
                routePoints: routePoints,
                selectedStop: selectedStop,
                onSelectStop: (stop) {
                  setState(() => _selectedStopOrder = stop.order);
                },
                onMarkerDetailsRequested: _loadGoogleMarkerDetails,
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                children: [
                  _VideoCard(
                    youtubeUrl:
                        widget.youtubeUrl.isEmpty
                            ? (job?.youtubeUrl ?? '')
                            : widget.youtubeUrl,
                  ),
                  const SizedBox(height: 16),
                  if (pending)
                    _AnalyzingCard(processing: job?.isProcessing ?? false),
                  if (_errorMessage != null && job == null) ...[
                    const SizedBox(height: 12),
                    _FailedCard(message: _errorMessage!),
                  ],
                  if (job != null && job.isFailed)
                    _FailedCard(message: job.errorMessage ?? '알 수 없는 오류'),
                ],
              ),
    );
  }
}

/// 완료 화면 — AI 코스 결과와 동일한 구성: 지도(탭한 장소 포커스) + 상세 일정.
class _CompletedItineraryView extends StatelessWidget {
  const _CompletedItineraryView({
    required this.result,
    required this.markers,
    required this.routePoints,
    required this.selectedStop,
    required this.onSelectStop,
    required this.onMarkerDetailsRequested,
  });

  final YoutubeCourseJobResult result;
  final List<PlaceMapMarkerData> markers;
  final List<PlaceMapRoutePoint> routePoints;
  final YoutubeCourseJobStop? selectedStop;
  final ValueChanged<YoutubeCourseJobStop> onSelectStop;
  final Future<PlaceMapMarkerData?> Function(PlaceMapMarkerData marker)
  onMarkerDetailsRequested;

  @override
  Widget build(BuildContext context) {
    final focus = selectedStop;
    final hasFocusGeo =
        focus != null && focus.latitude != 0 && focus.longitude != 0;
    return ListView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: PlaceMapView(
            // 일정 탭으로 포커스가 바뀌면 지도를 그 핀 중심으로 다시 그린다.
            key: ValueKey('yt-course-map-${focus?.order}'),
            markers: markers,
            routeMarkers: routePoints,
            connectSequentially: true,
            highlightedMarkerId: focus?.order,
            initialCenterLatitude: hasFocusGeo ? focus.latitude : null,
            initialCenterLongitude: hasFocusGeo ? focus.longitude : null,
            emptyMessage: '생성된 지도 마커가 없습니다.',
            kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
            onMarkerTap: (markerId) {
              for (final stop in result.stops) {
                if (stop.order == markerId) {
                  onSelectStop(stop);
                  break;
                }
              }
            },
            onMarkerDetailsRequested: onMarkerDetailsRequested,
            height: 280,
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            '상세 일정',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -.3,
            ),
          ),
        ),
        _RouteTimeline(
          stops: result.stops,
          selectedOrder: selectedStop?.order,
          onSelect: onSelectStop,
        ),
      ],
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.stops,
    required this.selectedOrder,
    required this.onSelect,
  });

  final List<YoutubeCourseJobStop> stops;
  final int? selectedOrder;
  final ValueChanged<YoutubeCourseJobStop> onSelect;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const Center(child: Text('표시할 일정이 없습니다.'));
    }
    return Column(
      children: [
        for (var index = 0; index < stops.length; index++)
          _TimelineStopTile(
            stop: stops[index],
            selected: stops[index].order == selectedOrder,
            first: index == 0,
            last: index == stops.length - 1,
            onTap: () => onSelect(stops[index]),
          ),
      ],
    );
  }
}

class _TimelineStopTile extends StatelessWidget {
  const _TimelineStopTile({
    required this.stop,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final YoutubeCourseJobStop stop;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.p500;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!first)
                    const Positioned(
                      top: 0,
                      bottom: 20,
                      child: VerticalDivider(
                        width: 2,
                        thickness: 2,
                        color: AppColors.p200,
                      ),
                    ),
                  if (!last)
                    const Positioned(
                      top: 20,
                      bottom: 0,
                      child: VerticalDivider(
                        width: 2,
                        thickness: 2,
                        color: AppColors.p200,
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${stop.order}',
                      style: TextStyle(
                        color: selected ? Colors.white : primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.p50 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? primary : const Color(0xFFE8EAF0),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // AI 코스 타임라인과 동일한 뱃지 — 카테고리 + 환급 인정.
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _badge(
                          stop.category.isEmpty ? '관광지' : stop.category,
                          _isFoodCategory(stop.category)
                              ? const Color(0xFFFFF1E0)
                              : AppColors.p100,
                          _isFoodCategory(stop.category)
                              ? const Color(0xFFB8731B)
                              : AppColors.p700,
                        ),
                        if (!_isFoodCategory(stop.category))
                          _badge('환급 인정', AppColors.mintTint,
                              AppColors.mintDeep),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 저장 규칙(app_controller)과 동일 — 식당·카페 계열은 가맹점, 나머지는 환급 인정.
  static bool _isFoodCategory(String category) {
    final c = category.toLowerCase();
    return c.contains('식당') ||
        c.contains('카페') ||
        c.contains('음식') ||
        c.contains('주점') ||
        c.contains('미용');
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      );
}


/// 영상 링크 카드 (디자인 ytinput).
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.youtubeUrl});

  final String youtubeUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 19,
                color: Color(0xFFE0322B),
              ),
              SizedBox(width: 8),
              Text(
                '유튜브 영상 링크',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 18, color: AppColors.ink4),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    youtubeUrl.isEmpty ? '링크 확인 중' : youtubeUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 분석 진행 카드 (디자인 ytanalyze + bgnote).
class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard({required this.processing});

  final bool processing;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, int)>[
      ('영상 정보 불러오기', 0),
      ('자막·화면에서 장소 추출', 1),
      ('환급 인정 관광지와 매칭', 2),
      ('동선 짜고 코스 완성', 3),
    ];
    final current = processing ? 1 : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.p50,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppColors.p600,
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다른 화면을 둘러봐도 괜찮아요',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.p700,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '코스는 백그라운드에서 계속 만들어지고, 완료되면 알림으로 알려드려요.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          radius: 20,
          child: Column(
            children: [
              for (final (label, index) in steps)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == steps.length - 1 ? 0 : 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              index < current
                                  ? AppColors.p100
                                  : (index == current
                                      ? AppColors.p500
                                      : AppColors.track),
                          shape: BoxShape.circle,
                        ),
                        child:
                            index < current
                                ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: AppColors.p600,
                                )
                                : (index == current
                                    ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                    : null),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color:
                                index < current
                                    ? AppColors.ink9
                                    : (index == current
                                        ? AppColors.p700
                                        : AppColors.ink4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 분석 실패 카드 (디자인 failbox).
class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.coralTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 30,
              color: AppColors.coralDeep,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '코스를 만들지 못했어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// 코스함 저장 안내 라인 (디자인 savedline).
// Kept for compatibility with pending design variants.
// ignore: unused_element
class _SavedLine extends StatelessWidget {
  const _SavedLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.p50,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.p600),
          const SizedBox(width: 7),
          Text(
            '영상 속 $count곳으로 코스를 만들어 코스함에 저장했어요',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.p700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 카드 공통 틀.
// Kept for compatibility with pending design variants.
// ignore: unused_element
class _DCard extends StatelessWidget {
  const _DCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -0.3,
            ),
          ),
          for (final child in children) ...[const SizedBox(height: 13), child],
        ],
      ),
    );
  }
}

/// 생성된 장소 행 (디자인 stopcard).
// Kept for compatibility with pending design variants.
// ignore: unused_element
class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});

  final YoutubeCourseJobStop stop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.p500,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${stop.order}',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stop.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.p100,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        stop.category,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.p700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink5,
                  ),
                ),
                if (stop.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    stop.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink4,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
