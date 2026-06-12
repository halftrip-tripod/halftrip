import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';

class SavedCourseListScreen extends StatefulWidget {
  const SavedCourseListScreen({
    super.key,
    required this.tripDetail,
  });

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
      await AppScope.of(context).syncPendingYoutubeCourseJobsForTrip(
        widget.tripDetail.trip.id,
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final savedCourses = controller.savedCourses
        .where((course) => course.regionId == widget.tripDetail.trip.regionId)
        .toList();
    final pendingJobs =
        controller.pendingYoutubeJobsForTrip(widget.tripDetail.trip.id);

    return AppShell(
      title: '코스 불러오기',
      modeName: controller.modeName,
      child: RefreshIndicator(
        onRefresh: _syncPending,
        child: savedCourses.isEmpty && pendingJobs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '저장된 코스가 없습니다. 코스 만들기나 AI 코스 생성 후 다시 확인해 주세요.',
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_syncing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  ...pendingJobs.map(
                    (job) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SectionCard(
                        title: 'AI 코스 생성 중',
                        subtitle: job.regionName,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.youtubeUrl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text(
                                '영상 분석 중입니다. 완료되면 이 목록에서 편집하거나 선택할 수 있습니다.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...savedCourses.asMap().entries.map((entry) {
                    final course = entry.value;
                    final isSelected =
                        controller.selectedCourseIdForTrip(widget.tripDetail.trip.id) ==
                            course.id;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == savedCourses.length - 1 ? 0 : 12,
                      ),
                      child: SectionCard(
                        title: course.title,
                        subtitle: '${course.stops.length}개 장소 · ${course.regionName}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.stops.map((stop) => stop.name).join(' → '),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF64748B),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      final payload =
                                          course.stops.asMap().entries.map((item) {
                                        final stop = item.value;
                                        final sourceType =
                                            stop.sourceType.toUpperCase();
                                        final placeType = sourceType ==
                                                PlaceCategory.digitalTourCard.wireName
                                            ? PlaceCategory.digitalTourCard
                                            : sourceType ==
                                                    PlaceCategory.merchant.wireName
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
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: Text(isSelected ? '선택됨' : '이 코스 선택'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    await controller.deleteCourse(course.id);
                                    if (context.mounted) {
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
