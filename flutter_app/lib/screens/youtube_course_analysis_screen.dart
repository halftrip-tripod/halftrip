import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/place_map_view.dart';

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
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _boot();
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

    try {
      final response = await controller.runTask(
        () => controller.repository.createYoutubeCourseJob(
          userId: userId,
          tripId: widget.tripDetail!.trip.id,
          regionId: widget.tripDetail!.trip.regionId,
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
          tripId: widget.tripDetail!.trip.id,
          regionId: widget.tripDetail!.trip.regionId,
          regionName: widget.tripDetail!.trip.regionName,
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
        await controller.saveCompletedYoutubeCourse(
          job,
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 코스 장소가 충분하지 않습니다.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = result.stops.asMap().entries.map((entry) {
        final stop = entry.value;
        final syntheticReferenceId =
            (stop.placeName.hashCode.abs() + stop.address.hashCode.abs() + entry.key + 1) *
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('플래너 적용에 실패했습니다.\n$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final result = job?.result;
    final markers = result == null ? const <PlaceMapMarkerData>[] : _buildMarkers(result);
    final routePoints = result == null ? const <PlaceMapRoutePoint>[] : _buildRoutePoints(result);
    final pending = _creating || job == null || job.isPending || job.isProcessing;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('유튜브로 코스 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _VideoCard(youtubeUrl: widget.youtubeUrl.isEmpty ? (job?.youtubeUrl ?? '') : widget.youtubeUrl),
          const SizedBox(height: 16),
          if (pending) _AnalyzingCard(processing: job?.isProcessing ?? false),
          if (_errorMessage != null && job == null) ...[
            const SizedBox(height: 12),
            _FailedCard(message: _errorMessage!),
          ],
          if (job != null && job.isFailed) _FailedCard(message: job.errorMessage ?? '알 수 없는 오류'),
          if (result != null) ...[
            _SavedLine(count: result.stops.length),
            const SizedBox(height: 14),
            _DCard(
              title: result.title.isEmpty ? '생성된 코스' : result.title,
              children: [
                if (result.summary.trim().isNotEmpty)
                  Text(
                    result.summary,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink5,
                      height: 1.5,
                    ),
                  ),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink9,
                  ),
                  decoration: InputDecoration(
                    hintText: result.title.isEmpty ? '코스 이름' : result.title,
                    hintStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink4,
                    ),
                    filled: true,
                    fillColor: AppColors.surf,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(8),
              radius: 20,
              child: PlaceMapView(
                markers: markers,
                routeMarkers: routePoints,
                connectSequentially: true,
                emptyMessage: '생성된 지도 마커가 없습니다.',
                kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                height: 380,
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                '상세 일정',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            for (final stop in result.stops) _StopRow(stop: stop),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _saveToPlanner,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(_saving ? '적용 중...' : '이 코스를 플래너에 적용'),
            ),
          ],
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
              Icon(Icons.play_circle_fill_rounded, size: 19, color: Color(0xFFE0322B)),
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
              Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.p600),
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
                  padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 14),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index < current
                              ? AppColors.p100
                              : (index == current ? AppColors.p500 : AppColors.track),
                          shape: BoxShape.circle,
                        ),
                        child: index < current
                            ? const Icon(Icons.check_rounded, size: 14, color: AppColors.p600)
                            : (index == current
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white),
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
                            color: index < current
                                ? AppColors.ink9
                                : (index == current ? AppColors.p700 : AppColors.ink4),
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
            child: const Icon(Icons.error_outline_rounded, size: 30, color: AppColors.coralDeep),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
