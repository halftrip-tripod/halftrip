import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppController.saveCompletedYoutubeCourse', () {
    test('stores a completed youtube job result as a saved course', () async {
      final controller = AppController(repository: MockTravelRepository());
      final job = _completedJob(
        jobId: 'job-1',
        title: 'Wando YouTube Course',
      );

      final saved = await controller.saveCompletedYoutubeCourse(job);

      expect(saved, isTrue);
      expect(controller.savedCourses, hasLength(1));
      expect(controller.savedCourses.first.id, 'job-1');
      expect(controller.savedCourses.first.title, 'Wando YouTube Course');
      expect(controller.savedCourses.first.regionId, 1);
      expect(controller.savedCourses.first.stops, hasLength(2));
      expect(
        controller.savedCourses.first.stops.first.sourceType,
        PlaceCategory.halfPrice.wireName,
      );
    });

    test('does not store incomplete jobs', () async {
      final controller = AppController(repository: MockTravelRepository());
      final job = YoutubeCourseJobItem(
        jobId: 'job-pending',
        userId: 1,
        tripId: 10,
        regionId: 1,
        regionName: 'Wando',
        youtubeUrl: 'https://www.youtube.com/watch?v=test',
        status: 'PROCESSING',
        result: null,
        errorMessage: null,
        createdAt: DateTime(2026, 6, 11, 10),
        updatedAt: DateTime(2026, 6, 11, 10, 5),
      );

      final saved = await controller.saveCompletedYoutubeCourse(job);

      expect(saved, isFalse);
      expect(controller.savedCourses, isEmpty);
    });

    test('keeps an existing custom title when same job is synced again', () async {
      final controller = AppController(repository: MockTravelRepository());
      final original = _completedJob(jobId: 'job-2', title: 'First Title');
      final updated = _completedJob(jobId: 'job-2', title: 'Server Updated Title');

      await controller.saveCompletedYoutubeCourse(original);
      await controller.saveCourse(
        SavedCourse(
          id: 'job-2',
          regionId: 1,
          regionName: 'Wando',
          title: 'My Custom Title',
          preferences: const ['food'],
          stops: controller.savedCourses.first.stops,
          createdAt: controller.savedCourses.first.createdAt,
        ),
      );

      final saved = await controller.saveCompletedYoutubeCourse(updated);

      expect(saved, isTrue);
      expect(controller.savedCourses, hasLength(1));
      expect(controller.savedCourses.first.title, 'My Custom Title');
      expect(controller.savedCourses.first.preferences, ['food']);
      expect(controller.savedCourses.first.id, 'job-2');
    });

    test('stores merchant-like stops with merchant source type', () async {
      final controller = AppController(repository: MockTravelRepository());
      final job = YoutubeCourseJobItem(
        jobId: 'job-merchant',
        userId: 1,
        tripId: 10,
        regionId: 1,
        regionName: 'Wando',
        youtubeUrl: 'https://www.youtube.com/watch?v=test',
        status: 'COMPLETED',
        result: const YoutubeCourseJobResult(
          title: 'Restaurant Course',
          summary: 'Restaurant focused course',
          stops: [
            YoutubeCourseJobStop(
              order: 1,
              placeName: 'Ocean Restaurant',
              address: 'Wando address',
              latitude: 34.3,
              longitude: 126.7,
              category: '식당',
              source: 'youtube_frame_or_transcript',
              reason: 'Detected from video',
            ),
          ],
        ),
        errorMessage: null,
        createdAt: DateTime(2026, 6, 11, 10),
        updatedAt: DateTime(2026, 6, 11, 10, 5),
      );

      final saved = await controller.saveCompletedYoutubeCourse(job);

      expect(saved, isTrue);
      expect(
        controller.savedCourses.first.stops.single.sourceType,
        PlaceCategory.merchant.wireName,
      );
    });
  });
}

YoutubeCourseJobItem _completedJob({
  required String jobId,
  required String title,
}) {
  return YoutubeCourseJobItem(
    jobId: jobId,
    userId: 1,
    tripId: 10,
    regionId: 1,
    regionName: 'Wando',
    youtubeUrl: 'https://www.youtube.com/watch?v=test',
    status: 'COMPLETED',
    result: const YoutubeCourseJobResult(
      title: '',
      summary: 'Generated from YouTube analysis',
      stops: [
        YoutubeCourseJobStop(
          order: 1,
          placeName: 'Wando Tower',
          address: 'Wando address',
          latitude: 34.31,
          longitude: 126.75,
          category: '관광지',
          source: 'youtube_frame_or_transcript',
          reason: 'Detected from video',
        ),
        YoutubeCourseJobStop(
          order: 2,
          placeName: 'Cheonghaejin Site',
          address: 'Wando address',
          latitude: 34.32,
          longitude: 126.76,
          category: '관광지',
          source: 'youtube_transcript',
          reason: 'Mentioned in transcript',
        ),
      ],
    ),
    errorMessage: null,
    createdAt: DateTime(2026, 6, 11, 10),
    updatedAt: DateTime(2026, 6, 11, 10, 5),
  ).copyWithResultTitle(title);
}

extension on YoutubeCourseJobItem {
  YoutubeCourseJobItem copyWithResultTitle(String title) {
    final current = result;
    return YoutubeCourseJobItem(
      jobId: jobId,
      userId: userId,
      tripId: tripId,
      regionId: regionId,
      regionName: regionName,
      youtubeUrl: youtubeUrl,
      status: status,
      result: current == null
          ? null
          : YoutubeCourseJobResult(
              title: title,
              summary: current.summary,
              stops: current.stops,
            ),
      errorMessage: errorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
