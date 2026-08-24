// 웹 세션 유지 검증 — 실제 Chrome + 실제 secure storage(web) + 실서버 로그인.
// 실행: flutter test --platform chrome --dart-define=API_BASE_URL=http://localhost:8080/api \
//        --dart-define=USE_MOCK_API=false test/web/session_restore_web_test.dart
// 새 AppController/Repository로 restoreSession 하는 것 = 새로고침과 동일 경로
// (localStorage에 남은 토큰·암호화 키를 다시 읽어 복호화).
@TestOn('browser')
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_config.dart';
import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/repositories/api_travel_repository.dart';

void main() {
  test('로그인 → 세션 저장 → 새 컨트롤러 복원 (새로고침 시뮬레이션)', () async {
    // flutter test 환경에선 플러그인 자동 등록이 없어 웹 구현을 직접 꽂는다.
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWeb();
    SharedPreferences.setMockInitialValues({});

    final config = AppConfig.fromEnvironment();
    expect(config.useMockApi, isFalse, reason: 'dart-define으로 실서버 모드를 켜야 한다');

    // 1) 로그인 — 앱과 동일 경로.
    final first = AppController(repository: ApiTravelRepository(config));
    await first.loginWithCredentials(loginId: 'sample', password: '1234');
    expect(first.isLoggedIn, isTrue, reason: '로그인 실패: ${first.errorMessage}');

    // 2) 토큰이 실제로 기기 저장소에 남았는지.
    const storage = FlutterSecureStorage();
    final savedToken = await storage.read(key: 'session_auth_token_v1');
    expect(savedToken, isNotNull, reason: '로그인 후 토큰이 저장되지 않았다');
    expect(savedToken, isNotEmpty);

    // 3) 새로고침 시뮬레이션 — 완전히 새로운 컨트롤러·리포지토리로 복원.
    final second = AppController(repository: ApiTravelRepository(config));
    final restored = await second.restoreSession();
    expect(restored, isTrue, reason: '세션 복원 실패');
    expect(second.currentUser?.id, first.currentUser?.id);
    expect(second.trips, isNotEmpty, reason: '복원 후 여행 목록도 같이 로드돼야 한다');
  });
}
