import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../features/youtube_travel_plan/travel_plan_models.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';
import 'youtube_travel_plan_screen.dart';

/// 저장 코스함 (S1-7) — 디자인: halftrip-design/course-saved.html
/// 여행에 연결할 코스 선택 + 삭제 + 유튜브 분석 대기 잡 표시.
class SavedCourseListScreen extends StatefulWidget {
  const SavedCourseListScreen({super.key, required this.tripDetail});

  final TripDetail tripDetail;

  @override
  State<SavedCourseListScreen> createState() => _SavedCourseListScreenState();
}

class _SavedCourseListScreenState extends State<SavedCourseListScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending();
    });
  }

  Future<void> _syncPending() async {
    if (_syncing || !mounted) return;
    setState(() {
      _syncing = true;
    });
    try {
      await AppScope.of(
        context,
      ).syncPendingYoutubeCourseJobsForTrip(widget.tripDetail.trip.id);
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _selectCourse(SavedCourse course) async {
    final controller = AppScope.of(context);
    final payload =
        course.stops.asMap().entries.map((item) {
          final stop = item.value;
          final sourceType = stop.sourceType.toUpperCase();
          final placeType =
              sourceType == PlaceCategory.digitalTourCard.wireName
                  ? PlaceCategory.digitalTourCard
                  : sourceType == PlaceCategory.merchant.wireName
                  ? PlaceCategory.merchant
                  : PlaceCategory.halfPrice;
          return TripPlaceItem(
            id: 0,
            placeType: placeType,
            referencePlaceId: stop.placeId,
            placeName: stop.name,
            address: stop.address,
            visitOrder: item.key + 1,
            latitude: stop.latitude,
            longitude: stop.longitude,
            checked: true,
          );
        }).toList();
    await controller.runTask(
      () => controller.repository.replaceTripPlaces(
        widget.tripDetail.trip.id,
        payload,
      ),
    );
    await controller.selectCourseForTrip(
      tripId: widget.tripDetail.trip.id,
      courseId: course.id,
    );
    await controller.refreshTrips();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openCourse(SavedCourse course) async {
    final now = DateTime.now();
    final job = YoutubeCourseJobItem(
      jobId: course.id,
      userId: 0,
      tripId: widget.tripDetail.trip.id,
      regionId: course.regionId,
      regionName: course.regionName,
      youtubeUrl: '',
      status: 'COMPLETED',
      result: YoutubeCourseJobResult(
        title: course.title,
        summary: '',
        stops:
            course.stops.asMap().entries.map((entry) {
              final stop = entry.value;
              return YoutubeCourseJobStop.fromJson({
                'order': entry.key + 1,
                'placeName': stop.name,
                'address': stop.address,
                'latitude': stop.latitude,
                'longitude': stop.longitude,
                'category': '장소',
                'source': stop.sourceType,
              });
            }).toList(),
      ),
      errorMessage: null,
      createdAt: course.createdAt,
      updatedAt: now,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => YoutubeTravelPlanScreen(
              job: job,
              tripDetail: widget.tripDetail,
              onDocumentSaved:
                  (document) => _saveEditedCourse(course, document),
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _saveEditedCourse(
    SavedCourse original,
    TravelPlanDocument document,
  ) async {
    final items =
        document.items
            .where(
              (item) =>
                  item.verificationStatus !=
                  TravelPlanVerificationStatus.excluded,
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final stops =
        items.map((item) {
          SavedCourseStop? existing;
          for (final stop in original.stops) {
            if (stop.name == item.placeName &&
                stop.address == (item.address ?? '')) {
              existing = stop;
              break;
            }
          }
          return SavedCourseStop(
            placeId: int.tryParse(item.placeId ?? '') ?? existing?.placeId ?? 0,
            name: item.placeName,
            address: item.address ?? '',
            latitude: item.latitude ?? 0,
            longitude: item.longitude ?? 0,
            sourceType:
                existing?.sourceType ?? item.sourceType.name.toUpperCase(),
          );
        }).toList();

    await AppScope.of(context).saveCourse(
      SavedCourse(
        id: original.id,
        regionId: original.regionId,
        regionName: original.regionName,
        title:
            document.title.trim().isEmpty
                ? original.title
                : document.title.trim(),
        preferences: original.preferences,
        stops: stops,
        createdAt: original.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final savedCourses =
        controller.savedCourses
            .where(
              (course) => course.regionId == widget.tripDetail.trip.regionId,
            )
            .toList();
    final pendingJobs = controller.pendingYoutubeJobsForTrip(
      widget.tripDetail.trip.id,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('저장 코스함')),
      body: RefreshIndicator(
        onRefresh: _syncPending,
        child:
            savedCourses.isEmpty && pendingJobs.isEmpty
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '저장된 코스가 없어요.\n코스 만들기나 AI 코스 생성 후 다시 확인해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5,
                        height: 1.6,
                      ),
                    ),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_syncing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.p500,
                          backgroundColor: AppColors.track,
                        ),
                      ),
                    for (final job in pendingJobs) ...[
                      _PendingJobCard(job: job),
                      const SizedBox(height: 14),
                    ],
                    for (final course in savedCourses) ...[
                      _CourseCard(
                        course: course,
                        selected:
                            controller.selectedCourseIdForTrip(
                              widget.tripDetail.trip.id,
                            ) ==
                            course.id,
                        onOpen: () => _openCourse(course),
                        onSelect: () => _selectCourse(course),
                        onDelete: () async {
                          await controller.deleteCourse(course.id);
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
      ),
    );
  }
}

/// 유튜브 분석 대기 카드 (디자인 bgnote 톤).
class _PendingJobCard extends StatelessWidget {
  const _PendingJobCard({required this.job});

  final PendingYoutubeCourseJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.p500,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${job.regionName} 유튜브 코스 생성 중',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            job.youtubeUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: const Text(
              '영상을 분석하고 있어요. 완료되면 알림을 보내드리고, 이 목록에서 바로 선택할 수 있어요.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.p700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 저장 코스 카드 (디자인 .scard).
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.selected,
    required this.onOpen,
    required this.onSelect,
    required this.onDelete,
  });

  final SavedCourse course;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isYoutube =
        course.preferences.any((p) => p.contains('유튜브')) ||
        course.title.contains('유튜브');

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                isYoutube ? '유튜브' : 'AI 추천',
                tone: isYoutube ? PillTone.danger : PillTone.sky,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  course.regionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink4,
                  ),
                ),
              ),
              if (selected) const Pill('선택됨', tone: PillTone.success),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${course.stops.length}곳 · ${course.stops.map((stop) => stop.name).join(' → ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink5,
              height: 1.5,
            ),
          ),
          const Divider(height: 26, color: AppColors.line),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                side: const BorderSide(color: AppColors.p200),
                foregroundColor: AppColors.p600,
              ),
              icon: const Icon(Icons.map_outlined, size: 19),
              label: const Text('지도·일정 보기/수정'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: selected ? null : onSelect,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: Text(selected ? '선택됨' : '이 코스 선택'),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.ink5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
