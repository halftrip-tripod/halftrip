import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppController selected course per trip', () {
    test('stores and returns selected course for a trip', () async {
      final controller = AppController(repository: MockTravelRepository());
      final course = _sampleCourse('course-1');

      await controller.saveCourse(course);
      await controller.selectCourseForTrip(tripId: 101, courseId: course.id);

      expect(controller.selectedCourseIdForTrip(101), 'course-1');
      expect(controller.selectedCourseForTrip(101)?.id, 'course-1');
    });

    test('persists selected course per trip in shared preferences', () async {
      final controller = AppController(repository: MockTravelRepository());
      final course = _sampleCourse('course-3');

      await controller.saveCourse(course);
      await controller.selectCourseForTrip(tripId: 202, courseId: course.id);
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('selected_course_ids_by_trip_v1');

      expect(raw, isNotNull);
      expect(raw, contains('"202":"course-3"'));
    });

    test('clears selected course when selected course is deleted', () async {
      final controller = AppController(repository: MockTravelRepository());
      final course = _sampleCourse('course-2');

      await controller.saveCourse(course);
      await controller.selectCourseForTrip(tripId: 101, courseId: course.id);
      await controller.deleteCourse(course.id);

      expect(controller.selectedCourseIdForTrip(101), isNull);
      expect(controller.selectedCourseForTrip(101), isNull);
    });

    test('tracks pending youtube jobs per trip', () async {
      final controller = AppController(repository: MockTravelRepository());
      final pending = PendingYoutubeCourseJob(
        jobId: 'job-1',
        tripId: 101,
        regionId: 1,
        regionName: 'Wando',
        youtubeUrl: 'https://youtu.be/test',
        createdAt: DateTime(2026, 6, 12, 11),
      );

      await controller.trackPendingYoutubeCourseJob(pending);

      expect(controller.pendingYoutubeJobsForTrip(101), hasLength(1));
      expect(controller.pendingYoutubeJobsForTrip(101).first.jobId, 'job-1');
    });

    test('moves completed pending youtube job into saved courses', () async {
      final repository = _CompletedJobRepository();
      final controller = AppController(repository: repository);
      final pending = PendingYoutubeCourseJob(
        jobId: 'job-complete',
        tripId: 101,
        regionId: 1,
        regionName: 'Wando',
        youtubeUrl: 'https://youtu.be/test',
        createdAt: DateTime(2026, 6, 12, 11),
      );

      await controller.trackPendingYoutubeCourseJob(pending);
      await controller.syncPendingYoutubeCourseJobsForTrip(101);

      expect(controller.pendingYoutubeJobsForTrip(101), isEmpty);
      expect(controller.savedCourses.any((item) => item.id == 'job-complete'), isTrue);
    });
  });
}

SavedCourse _sampleCourse(String id) {
  return SavedCourse(
    id: id,
    regionId: 1,
    regionName: 'Wando',
    title: 'Sample Course',
    preferences: const [],
    stops: const [
      SavedCourseStop(
        placeId: 1,
        name: 'Wando Tower',
        address: 'Wando address',
        latitude: 34.31,
        longitude: 126.75,
        sourceType: 'HALF_PRICE',
      ),
      SavedCourseStop(
        placeId: 2,
        name: 'Cheonghaejin Site',
        address: 'Wando address',
        latitude: 34.32,
        longitude: 126.76,
        sourceType: 'HALF_PRICE',
      ),
    ],
    createdAt: DateTime(2026, 6, 12, 10),
  );
}

class _CompletedJobRepository extends MockTravelRepository {
  @override
  Future<YoutubeCourseJobItem> getYoutubeCourseJob(String jobId) async {
    return YoutubeCourseJobItem(
      jobId: 'job-complete',
      userId: 1,
      tripId: 101,
      regionId: 1,
      regionName: 'Wando',
      youtubeUrl: 'https://youtu.be/test',
      status: 'COMPLETED',
      result: const YoutubeCourseJobResult(
        title: 'Completed Course',
        summary: 'done',
        stops: [
          YoutubeCourseJobStop(
            order: 1,
            placeName: 'Wando Tower',
            address: 'Wando address',
            latitude: 34.31,
            longitude: 126.75,
            category: '관광지',
            source: 'youtube_transcript',
            reason: 'done',
          ),
        ],
      ),
      errorMessage: null,
      createdAt: DateTime(2026, 6, 12, 11),
      updatedAt: DateTime(2026, 6, 12, 11, 5),
    );
  }
}
