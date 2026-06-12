import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';

class SavedCourseListScreen extends StatelessWidget {
  const SavedCourseListScreen({
    super.key,
    required this.tripDetail,
  });

  final TripDetail tripDetail;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final savedCourses = controller.savedCourses
        .where((course) => course.regionId == tripDetail.trip.regionId)
        .toList();

    return AppShell(
      title: '코스 불러오기',
      modeName: controller.modeName,
      child: savedCourses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('저장된 코스가 없습니다. 코스 만들기나 AI 코스 생성 후 다시 확인해 주세요.'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: savedCourses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = savedCourses[index];
                final isSelected =
                    controller.selectedCourseIdForTrip(tripDetail.trip.id) == course.id;
                return SectionCard(
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
                                    course.stops.asMap().entries.map((entry) {
                                  final stop = entry.value;
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
                                    visitOrder: entry.key + 1,
                                    latitude: stop.latitude,
                                    longitude: stop.longitude,
                                    checked: true,
                                  );
                                }).toList();
                                await controller.runTask(
                                  () => controller.repository.replaceTripPlaces(
                                    tripDetail.trip.id,
                                    payload,
                                  ),
                                );
                                await controller.selectCourseForTrip(
                                  tripId: tripDetail.trip.id,
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
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SavedCourseListScreen(tripDetail: tripDetail),
                                  ),
                                );
                              }
                            },
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
