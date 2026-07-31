import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/screens/youtube_travel_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile planner renders a spreadsheet and opens row editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: YoutubeTravelPlanScreen(job: _sampleJob()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('여행 계획표'), findsOneWidget);
    expect(find.text('시트 내보내기'), findsOneWidget);
    expect(find.text('도톤보리'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('travel-plan-horizontal-scroll')),
      const Offset(-360, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('travel-plan-row-planner-design-test-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('행 편집'), findsOneWidget);
    expect(find.text('행 삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

YoutubeCourseJobItem _sampleJob() {
  return YoutubeCourseJobItem(
    jobId: 'planner-design-test',
    userId: 1,
    tripId: null,
    regionId: 1,
    regionName: '오사카',
    youtubeUrl: 'https://www.youtube.com/watch?v=test',
    status: 'COMPLETED',
    result: YoutubeCourseJobResult(
      title: '오사카 2박 3일 여행 계획표',
      summary: '영상에서 추출한 오사카 여행 일정',
      stops: [
        YoutubeCourseJobStop.fromJson({
          'order': 1,
          'placeName': '도톤보리',
          'address': '일본 오사카부 오사카시 주오구',
          'latitude': 34.6687,
          'longitude': 135.5013,
          'category': '관광지',
          'source': 'youtube_description',
          'reason': '영상에서 방문 장소로 확인됨',
        }),
      ],
    ),
    errorMessage: null,
    createdAt: DateTime(2026, 7, 28),
    updatedAt: DateTime(2026, 7, 28),
  );
}
