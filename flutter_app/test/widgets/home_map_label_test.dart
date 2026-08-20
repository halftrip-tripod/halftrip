import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/core/app_scope.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/mock_ui/screens/home_tab.dart';
import 'package:travel_support_mvp/mock_ui/theme/app_colors.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';

RegionSummary _region({
  required int id,
  required String name,
  required String statusCode,
  required double top,
  required double left,
}) {
  return RegionSummary(
    id: id,
    name: name,
    province: '전라남도',
    refundConditionAmount: 100000,
    mockBudgetRemaining: 50,
    halfPriceApplyUrl: '',
    digitalTourCardApplyUrl: '',
    dataSourceNote: 'TEST',
    statusCode: statusCode,
    displayOrder: id,
    mapTopPercent: top,
    mapLeftPercent: left,
    matchedByResidence: true,
  );
}

/// 핀이 같은 자리에 겹치는 지역 셋 — 우선순위 라벨만 남는지 검증용.
class _CollidingRegionsRepo extends MockTravelRepository {
  @override
  Future<List<RegionSummary>> getRegions({String? residence}) async => [
        // 같은 좌표에 접수중 vs 마감 — 접수중 라벨만 보여야 한다.
        _region(id: 901, name: '가상접수중', statusCode: 'APPLYING', top: 50, left: 50),
        _region(id: 902, name: '가상마감', statusCode: 'CLOSED', top: 51, left: 50),
        // 멀리 떨어진 지역 — 겹치지 않으니 라벨이 보여야 한다.
        _region(id: 903, name: '가상외딴곳', statusCode: 'CLOSED', top: 20, left: 80),
        // 오픈예정 — 핀 색 상태 분기 검증용.
        _region(id: 904, name: '가상오픈예정', statusCode: 'PREPARING', top: 70, left: 20),
      ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 테스트 환경에서 FCM 초기화를 타지 않게 안드로이드가 아닌 플랫폼으로.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('겹치는 핀은 우선순위 높은 라벨만 남는다', (tester) async {
    final controller = AppController(repository: _CollidingRegionsRepo());
    await controller.loginWithCredentials(loginId: 'sample', password: '1234');
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: HomeTab())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // 접수중 라벨은 보이고, 같은 자리 마감 라벨은 숨는다.
    expect(find.text('가상접수중'), findsOneWidget);
    expect(find.text('가상마감'), findsNothing);
    // 겹치지 않는 지역 라벨은 상태와 무관하게 보인다.
    expect(find.text('가상외딴곳'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // testWidgets는 본문 종료 시 foundation 변수 원복을 검사한다.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('핀 색이 상태별로 갈린다 — 접수중 p500·오픈예정 p300·마감 gray', (tester) async {
    final controller = AppController(repository: _CollidingRegionsRepo());
    await controller.loginWithCredentials(loginId: 'sample', password: '1234');
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: HomeTab())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final dotColors = tester
        .widgetList(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MapDot'))
        .map((w) => (w as dynamic).color as Color)
        .toSet();
    expect(dotColors, contains(AppColors.p500));
    expect(dotColors, contains(AppColors.p300));
    expect(dotColors, contains(AppColors.gray));
    // 마감 핀이 예전 하늘색으로 남아 있으면 회귀.
    expect(dotColors, isNot(contains(const Color(0xFF5CC4EE))));
    debugDefaultTargetPlatformOverride = null;
  });
}
