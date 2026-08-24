import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/core/app_scope.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';
import 'package:travel_support_mvp/screens/region_course_builder_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('코스 빌더가 mock 지역으로 예외 없이 뜬다', (tester) async {
    final repo = MockTravelRepository();
    final controller = AppController(repository: repo);
    final regions = await repo.getRegions(residence: '');
    final region = regions.first;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: RegionCourseBuilderScreen(
            regionId: region.id,
            regionName: region.name,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('나만의 코스'), findsOneWidget);
  });
}
