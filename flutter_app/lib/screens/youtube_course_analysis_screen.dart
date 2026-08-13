import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _customOrder = false;
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

  YoutubeCourseJobStop _copyStopWithOrder(
    YoutubeCourseJobStop stop,
    int order,
  ) {
    return YoutubeCourseJobStop(
      order: order,
      placeName: stop.placeName,
      address: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
      category: stop.category,
      phoneNumber: stop.phoneNumber,
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
      source: stop.source,
      reason: stop.reason,
    );
  }

  YoutubeCourseJobItem _copyJobWithStops(
    YoutubeCourseJobItem job,
    List<YoutubeCourseJobStop> stops,
  ) {
    final result = job.result!;
    return YoutubeCourseJobItem(
      jobId: job.jobId,
      userId: job.userId,
      tripId: job.tripId,
      regionId: job.regionId,
      regionName: job.regionName,
      youtubeUrl: job.youtubeUrl,
      status: job.status,
      result: YoutubeCourseJobResult(
        title: result.title,
        summary: result.summary,
        stops: stops,
      ),
      errorMessage: job.errorMessage,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    );
  }

  Future<void> _openStopReorderSheet() async {
    final job = _job;
    final result = job?.result;
    if (job == null || result == null || result.stops.length < 2) return;

    final draftStops = List<YoutubeCourseJobStop>.from(result.stops);
    final reorderedStops = await showModalBottomSheet<
      List<YoutubeCourseJobStop>
    >(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.78,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DCE5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '장소 순서 재배열',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink9,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '오른쪽 손잡이를 끌어 방문 순서를 바꿔보세요.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.ink5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        buildDefaultDragHandles: false,
                        itemCount: draftStops.length,
                        onReorder: (oldIndex, newIndex) {
                          setSheetState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = draftStops.removeAt(oldIndex);
                            draftStops.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final stop = draftStops[index];
                          return Container(
                            key: ValueKey(
                              '${stop.order}-${stop.placeName}-${stop.latitude}-${stop.longitude}',
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8FC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E4EC),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.p500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop.placeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.ink9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (stop.category.isNotEmpty ||
                                          stop.address.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          stop.category.isNotEmpty
                                              ? stop.category
                                              : stop.address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.ink5,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: AppColors.ink5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => Navigator.of(sheetContext).pop(),
                                child: const Text('취소'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    () => Navigator.of(sheetContext).pop([
                                      for (
                                        var index = 0;
                                        index < draftStops.length;
                                        index++
                                      )
                                        _copyStopWithOrder(
                                          draftStops[index],
                                          index + 1,
                                        ),
                                    ]),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.p500,
                                ),
                                child: const Text('순서 적용'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || reorderedStops == null) return;
    final updatedJob = _copyJobWithStops(job, reorderedStops);
    setState(() {
      _job = updatedJob;
      _customOrder = true;
      _selectedStopOrder = reorderedStops.first.order;
    });

    try {
      await AppScope.of(context).saveCompletedYoutubeCourse(
        updatedJob,
        preferredTitle: _titleController.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('순서는 적용됐지만 코스함 저장에 실패했습니다.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('방문 순서를 변경했습니다.')));
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

  Future<void> _openDirections(YoutubeCourseJobStop stop) async {
    final placeUrl = stop.placeUrl.trim();
    final uri =
        placeUrl.isNotEmpty
            ? Uri.tryParse(placeUrl)
            : Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query':
                  stop.latitude != 0 && stop.longitude != 0
                      ? '${stop.latitude},${stop.longitude}'
                      : '${stop.placeName} ${stop.address}',
            });
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('길찾기 화면을 열지 못했습니다.')));
    }
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

    final selectedStop =
        result == null || result.stops.isEmpty
            ? null
            : result.stops.firstWhere(
              (stop) => stop.order == _selectedStopOrder,
              orElse: () => result.stops.first,
            );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(result == null ? '유튜브로 코스 만들기' : '일정 + 지도'),
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
      body:
          result != null
              ? _CompletedItineraryView(
                result: result,
                markers: markers,
                routePoints: routePoints,
                selectedStop: selectedStop,
                saving: _saving,
                customOrder: _customOrder,
                onSelectStop: (stop) {
                  setState(() => _selectedStopOrder = stop.order);
                },
                onMarkerDetailsRequested: _loadGoogleMarkerDetails,
                onReorder: _openStopReorderSheet,
                onRecompose: _saving ? null : _saveToPlanner,
                onEdit: _openTravelPlan,
                onDirections:
                    selectedStop == null
                        ? null
                        : () => _openDirections(selectedStop),
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

class _CompletedItineraryView extends StatelessWidget {
  const _CompletedItineraryView({
    required this.result,
    required this.markers,
    required this.routePoints,
    required this.selectedStop,
    required this.saving,
    required this.customOrder,
    required this.onSelectStop,
    required this.onMarkerDetailsRequested,
    required this.onReorder,
    required this.onRecompose,
    required this.onEdit,
    required this.onDirections,
  });

  final YoutubeCourseJobResult result;
  final List<PlaceMapMarkerData> markers;
  final List<PlaceMapRoutePoint> routePoints;
  final YoutubeCourseJobStop? selectedStop;
  final bool saving;
  final bool customOrder;
  final ValueChanged<YoutubeCourseJobStop> onSelectStop;
  final Future<PlaceMapMarkerData?> Function(PlaceMapMarkerData marker)
  onMarkerDetailsRequested;
  final VoidCallback onReorder;
  final VoidCallback? onRecompose;
  final VoidCallback onEdit;
  final VoidCallback? onDirections;

  static const _primary = AppColors.p500;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 760 ? 28.0 : 20.0;
        return ListView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            28,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    icon: Icons.swap_vert_rounded,
                    label: '순서 재배열',
                    active: false,
                    onTap: onReorder,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeButton(
                    icon: Icons.edit_rounded,
                    label: saving ? '적용 중...' : '내 일정으로 재구성',
                    active: true,
                    onTap: onRecompose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: PlaceMapView(
                markers: markers,
                routeMarkers: routePoints,
                connectSequentially: true,
                highlightedMarkerId: selectedStop?.order,
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
                height: constraints.maxWidth >= 760 ? 460 : 340,
              ),
            ),
            Transform.translate(
              // 구글 로고·저작자 표시가 가려지면 약관 위반이라 지도 위 오버랩 금지.
              offset: Offset.zero,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            '영상 코스',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '총 ${result.stops.length}개 장소 · ${customOrder ? '사용자 지정 순서' : '영상 등장 순서 기준'}',
                            style: const TextStyle(
                              color: AppColors.ink5,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (constraints.maxWidth >= 700)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _RouteTimeline(
                              stops: result.stops,
                              selectedOrder: selectedStop?.order,
                              onSelect: onSelectStop,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _SelectedPlaceCard(stop: selectedStop),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _RouteTimeline(
                            stops: result.stops,
                            selectedOrder: selectedStop?.order,
                            onSelect: onSelectStop,
                          ),
                          const SizedBox(height: 14),
                          _SelectedPlaceCard(stop: selectedStop),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.near_me_outlined),
                    label: const Text('길찾기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary, width: 1.4),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.p500,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('계획표 작성하기'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.ink7;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: active ? AppColors.p500 : const Color(0xFFF4F4F8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                    const SizedBox(height: 4),
                    Text(
                      stop.category.isEmpty ? '장소' : stop.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink4,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({required this.stop});

  final YoutubeCourseJobStop? stop;

  String _businessStatus(String value) {
    return switch (value.trim().toUpperCase()) {
      'OPERATIONAL' => '영업 중',
      'CLOSED_TEMPORARILY' => '임시 휴업',
      'CLOSED_PERMANENTLY' => '폐업',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = stop;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final status = _businessStatus(item.businessStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.placeName,
                  style: const TextStyle(
                    color: AppColors.ink9,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              if (item.category.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      color: AppColors.p500,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (item.address.trim().isNotEmpty)
            _PlaceDetailLine(
              icon: Icons.location_on_outlined,
              text: item.address,
            ),
          if (item.phoneNumber.trim().isNotEmpty)
            _PlaceDetailLine(
              icon: Icons.phone_outlined,
              text: item.phoneNumber,
            ),
          if (item.rating != null)
            _PlaceDetailLine(
              icon: Icons.star_rounded,
              text:
                  '${item.rating!.toStringAsFixed(1)}점'
                  '${item.userRatingCount > 0 ? ' · 리뷰 ${item.userRatingCount}개' : ''}',
            ),
          if (status.isNotEmpty)
            _PlaceDetailLine(
              icon: Icons.storefront_outlined,
              text: status,
              accent: status == '영업 중',
            ),
          if (item.editorialSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.editorialSummary,
              style: const TextStyle(
                color: AppColors.ink5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.p500),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '유튜브 영상에서 확인한 추천 방문 장소예요.',
                    style: TextStyle(
                      color: AppColors.p500,
                      fontWeight: FontWeight.w800,
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

class _PlaceDetailLine extends StatelessWidget {
  const _PlaceDetailLine({
    required this.icon,
    required this.text,
    this.accent = false,
  });

  final IconData icon;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.p500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: accent ? const Color(0xFF16A34A) : AppColors.ink5,
                height: 1.4,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
