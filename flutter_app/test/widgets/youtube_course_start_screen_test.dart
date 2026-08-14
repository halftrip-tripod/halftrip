import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/core/app_scope.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';
import 'package:travel_support_mvp/screens/youtube_course_start_screen.dart';

Future<TripDetail> _tripDetail(MockTravelRepository repo) =>
    repo.getTripDetail(1);

Future<void> _pumpScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = MockTravelRepository();
  final controller = AppController(repository: repo);
  final detail = await _tripDetail(repo);

  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(home: YoutubeCourseStartScreen(tripDetail: detail)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('좁은 화면에서도 넘침 없이 뜬다', (tester) async {
    await _pumpScreen(tester, const Size(360, 780));

    expect(tester.takeException(), isNull);
    expect(find.text('유튜브 코스 생성'), findsOneWidget);
    expect(find.text('분석하기'), findsOneWidget);
  });

  testWidgets('넓은 화면에서도 넘침 없이 뜬다', (tester) async {
    await _pumpScreen(tester, const Size(1100, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('유튜브 코스 생성'), findsOneWidget);
  });

  testWidgets('링크를 넣기 전에는 미리보기가 자리를 차지하지 않는다', (tester) async {
    await _pumpScreen(tester, const Size(390, 840));

    expect(find.text('영상을 찾았어요'), findsNothing);
    // 시안의 고리 아이콘이 붙여넣기 버튼 역할을 한다.
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/watch?v=-c_KCDjGOe0',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('영상을 찾았어요'), findsOneWidget);
  });

  testWidgets('최근 분석 목록은 두지 않는다 (코스함과 중복)', (tester) async {
    await _pumpScreen(tester, const Size(390, 840));

    // 분석 결과는 코스함에 쌓이므로 이 화면에 별도 목록을 두지 않기로 했다.
    expect(find.text('최근 분석'), findsNothing);
    expect(find.text('전체 보기'), findsNothing);
  });

  testWidgets('잘못된 링크면 오류 문구를 보여준다', (tester) async {
    await _pumpScreen(tester, const Size(390, 840));

    await tester.enterText(find.byType(TextField), 'https://example.com/hello');
    await tester.pump();
    await tester.tap(find.text('분석하기'));
    await tester.pump();

    expect(find.text('올바른 유튜브 영상 링크를 입력해 주세요.'), findsOneWidget);
  });
}
