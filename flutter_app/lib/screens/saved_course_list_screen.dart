import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
import 'region_course_builder_screen.dart';

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
                child: Text('저장된 코스가 없습니다. 유튜브 코스 생성 또는 직접 코스 저장 후 다시 시도해 주세요.'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: savedCourses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = savedCourses[index];
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
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RegionCourseBuilderScreen(
                                      regionId: course.regionId,
                                      regionName: course.regionName,
                                      initialCourse: course,
                                      tripId: tripDetail.trip.id,
                                      initialTripPlaces: tripDetail.selectedPlaces,
                                      initialMode: CourseBuildMode.manual,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('코스 보기/수정'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await controller.deleteCourse(course.id);
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => SavedCourseListScreen(tripDetail: tripDetail),
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
