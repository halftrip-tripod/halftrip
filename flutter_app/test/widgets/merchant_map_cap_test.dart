import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/core/app_scope.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';
import 'package:travel_support_mvp/screens/merchant_map_screen.dart';
import 'package:travel_support_mvp/widgets/place_map_view.dart';

/// 완도 실데이터(5,339개) 규모를 재현해 가맹점 지도의 마커 캡·대분류 칩을 검증한다.
class _BigMerchantRepo extends MockTravelRepository {
  static const _rawCategories = [
    '한식 음식점업',
    '커피 전문점',
    '육상 운송 및 파이프라인 운송업',
    '기타 개인 서비스업',
    '숙박시설 운영업',
    '슈퍼마켓',
    '두발 미용업',
  ];

  @override
  Future<RegionDetail> getRegionDetail(
    int regionId, {
    String? residence,
    bool includeMerchants = true,
  }) async {
    final base = await super.getRegionDetail(regionId, residence: residence);
    final merchants = List<MerchantItem>.generate(5000, (i) {
      return MerchantItem(
        id: 100000 + i,
        name: '가맹점 $i',
        address: '전라남도 완도군 어딘가 $i',
        category: _rawCategories[i % _rawCategories.length],
        // 완도 인근에 넓게 흩뿌림 (±0.5도) — 뷰포트 없는 초기 상태 기준 중심 정렬 확인용.
        latitude: 34.31 + (i % 100 - 50) * 0.01,
        longitude: 126.75 + (i ~/ 100 - 25) * 0.01,
        kakaoPlaceName: '',
        kakaoPhoneNumber: '',
        kakaoRoadAddress: '',
        kakaoCategoryName: '',
        kakaoPlaceUrl: '',
      );
    });
    return RegionDetail(
      region: base.region,
      halfPricePlaces: base.halfPricePlaces,
      digitalTourCardPlaces: base.digitalTourCardPlaces,
      merchants: merchants,
      onlineMalls: base.onlineMalls,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final controller = AppController(repository: _BigMerchantRepo());
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(
          home: MerchantMapScreen(regionId: 2, regionName: '강진'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('가맹점 5,000개여도 지도 마커는 최대 250개만 렌더한다', (tester) async {
    await pumpScreen(tester);
    final mapView = tester.widget<PlaceMapView>(find.byType(PlaceMapView));
    expect(mapView.markers.length, 250);
  });

  testWidgets('카테고리 칩은 통계청 원문 대신 대분류로 묶인다', (tester) async {
    await pumpScreen(tester);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('음식점'), findsWidgets);
    expect(find.text('기타'), findsWidgets);
    // 통계청 원문이 칩으로 나열되면 안 된다.
    expect(find.text('육상 운송 및 파이프라인 운송업'), findsNothing);
    expect(find.text('한식 음식점업'), findsNothing);
  });

  testWidgets('카테고리 칩을 고르면 그 대분류 마커만 남는다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('음식점').first);
    await tester.pump(const Duration(milliseconds: 300));
    final mapView = tester.widget<PlaceMapView>(find.byType(PlaceMapView));
    expect(mapView.markers, isNotEmpty);
    expect(
      mapView.markers.every((m) => m.regionLabel == '음식점'),
      isTrue,
    );
  });
}
