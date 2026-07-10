import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/repositories/mock_travel_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 테스트 환경은 android로 잡혀 FCM 경로를 타므로 iOS로 우회.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('로컬 로그인(sample/1234) 성공 → 유저·여행 로드', () async {
    final controller = AppController(repository: MockTravelRepository());
    await controller.loginWithCredentials(loginId: 'sample', password: '1234');

    expect(controller.isLoggedIn, isTrue);
    expect(controller.currentUser?.name, isNotEmpty);
    expect(controller.trips, isNotEmpty);
  });

  test('로컬 로그인 실패 시 예외', () async {
    final controller = AppController(repository: MockTravelRepository());
    await expectLater(
      controller.loginWithCredentials(loginId: 'sample', password: 'wrong'),
      throwsA(anything),
    );
    expect(controller.isLoggedIn, isFalse);
  });
}
