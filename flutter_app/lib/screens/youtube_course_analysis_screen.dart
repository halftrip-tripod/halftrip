import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
import '../widgets/place_map_view.dart';

class YoutubeCourseAnalysisScreen extends StatefulWidget {
  const YoutubeCourseAnalysisScreen({
    super.key,
    this.tripDetail,
    this.youtubeUrl = '',
    this.themes = const [],
    this.jobId,
  });

  final TripDetail? tripDetail;
  final String youtubeUrl;
  final List<String> themes;
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
      final job = await AppScope.of(context).repository.getYoutubeCourseJob(jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _errorMessage = null;
      });
      if (job.result != null && _titleController.text.trim().isEmpty) {
        _titleController.text = job.result!.title;
      }
      if (widget.tripDetail == null && job.tripId != null) {
        await AppScope.of(context).repository.getTripDetail(job.tripId!);
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
      final regionName = widget.tripDetail?.trip.regionName ?? _job?.regionName ?? '유튜브 코스';
      await controller.saveCourse(
        SavedCourse(
          id: _job!.jobId,
          regionId: _job!.regionId,
          regionName: regionName,
          title: _titleController.text.trim().isEmpty
              ? (result.title.isEmpty ? '$regionName 추천 코스' : result.title)
              : _titleController.text.trim(),
          preferences: widget.themes,
          stops: result.stops
              .map(
                (stop) => SavedCourseStop(
                  placeId: stop.order,
                  name: stop.placeName,
                  address: stop.address,
                  latitude: stop.latitude,
                  longitude: stop.longitude,
                  sourceType: stop.source,
                ),
              )
              .toList(),
          createdAt: DateTime.now(),
        ),
      );
      final tripId = widget.tripDetail?.trip.id ?? _job?.tripId;
      if (tripId == null) {
        throw Exception('저장할 여행 정보가 없습니다.');
      }
      await controller.runTask(
        () => controller.repository.replaceTripPlaces(tripId, payload),
      );
      await controller.refreshTrips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생성된 코스를 플래너에 저장했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코스 저장에 실패했습니다.\n$error')),
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

    return AppShell(
      title: '영상 분석 코스 생성',
      modeName: AppScope.of(context).modeName,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _JobHeaderCard(
            jobId: _jobId,
            youtubeUrl: widget.youtubeUrl,
            status: job?.status ?? (_creating ? 'PENDING' : 'UNKNOWN'),
            errorMessage: _errorMessage,
          ),
          const SizedBox(height: 16),
          if (_creating || job == null || job.isPending || job.isProcessing)
            const _YoutubeJobPendingCard(),
          if (job != null && job.isFailed)
            _YoutubeJobFailedCard(message: job.errorMessage ?? '알 수 없는 오류'),
          if (result != null) ...[
            _YoutubeJobResultCard(result: result),
            const SizedBox(height: 16),
            SectionCard(
              title: '코스 이름',
              subtitle: '저장할 때 사용할 이름을 직접 정할 수 있습니다.',
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: result.title.isEmpty ? '완도 유튜브 추천 코스' : result.title,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '생성된 코스 지도',
              subtitle: '분석된 장소를 순서대로 지도 마커와 경로로 표시합니다.',
              child: PlaceMapView(
                markers: markers,
                routeMarkers: routePoints,
                connectSequentially: true,
                emptyMessage: '생성된 지도 마커가 없습니다.',
                kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                height: 420,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '생성된 장소 순서',
              subtitle: '저장 시 아래 순서대로 기존 플래너(trip_places)에 저장됩니다.',
              child: Column(
                children: result.stops
                    .map(
                      (stop) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE8F7EE),
                          child: Text(
                            '${stop.order}',
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(stop.placeName),
                        subtitle: Text('${stop.address}\n${stop.reason}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _saveToPlanner,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _saving ? '저장 중...' : '이 코스 저장하기',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobHeaderCard extends StatelessWidget {
  const _JobHeaderCard({
    required this.jobId,
    required this.youtubeUrl,
    required this.status,
    required this.errorMessage,
  });

  final String? jobId;
  final String youtubeUrl;
  final String status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '유튜브 코스 작업',
      subtitle: 'jobId 기준으로 백그라운드 작업 상태를 조회합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('jobId: ${jobId ?? '생성 중'}'),
          const SizedBox(height: 8),
          Text('상태: $status'),
          const SizedBox(height: 8),
          Text(youtubeUrl),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ],
        ],
      ),
    );
  }
}

class _YoutubeJobPendingCard extends StatelessWidget {
  const _YoutubeJobPendingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text(
            '백그라운드에서 분석 중입니다',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '유튜브 자막, 프레임, OCR, 장소 추출을 백그라운드에서 처리하고 있습니다. 다른 화면으로 이동해도 작업은 계속됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _YoutubeJobFailedCard extends StatelessWidget {
  const _YoutubeJobFailedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '분석 실패',
      subtitle: '백그라운드 작업이 실패했습니다.',
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFB91C1C)),
      ),
    );
  }
}

class _YoutubeJobResultCard extends StatelessWidget {
  const _YoutubeJobResultCard({required this.result});

  final YoutubeCourseJobResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: result.title,
      subtitle: result.summary,
      child: Text(
        '총 ${result.stops.length}개의 장소를 생성했습니다.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
