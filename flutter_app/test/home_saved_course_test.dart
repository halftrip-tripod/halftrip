import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/core/app_scope.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';
import 'package:travel_support_mvp/screens/home_screen.dart';
import 'package:travel_support_mvp/screens/region_course_builder_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('홈 저장 코스 탭 → 코스 빌더가 열린다', (tester) async {
    final repo = MockTravelRepository();
    final controller = AppController(repository: repo);
    controller.currentUser = await repo.mockLogin(LoginProvider.kakao);
    await controller.saveCourse(SavedCourse(
      id: 'demo_gangjin_course',
      regionId: 2,
      regionName: '강진',
      title: '강진 미식 1박2일 코스',
      preferences: const ['맛집'],
      stops: const [
        SavedCourseStop(
            placeId: 2,
            name: '강진만 생태공원',
            address: '전남 강진군',
            latitude: 34.5,
            longitude: 126.7,
            sourceType: 'PLACE'),
      ],
      createdAt: DateTime(2026, 7, 6),
    ));

    await tester.pumpWidget(AppScope(
      controller: controller,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump(); // postFrame → future 시작
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    final row = find.text('강진 미식 1박2일 코스');
    expect(row, findsOneWidget, reason: '홈 저장 코스 행이 보여야 한다');

    await tester.ensureVisible(row);
    await tester.tap(row, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.byType(RegionCourseBuilderScreen), findsOneWidget,
        reason: '탭하면 코스 빌더가 열려야 한다');
  });
}
