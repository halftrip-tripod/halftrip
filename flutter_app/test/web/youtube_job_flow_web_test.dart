// 유튜브 잡 생성 플로우 검증 — 실제 Chrome + 실서버(localhost:8080).
// 분석 화면(_boot)과 동일한 순서를 그대로 밟아 어디서 끊기는지 판정한다.
// 실행: flutter test --platform chrome --dart-define=API_BASE_URL=http://localhost:8080/api \
//        --dart-define=USE_MOCK_API=false test/web/youtube_job_flow_web_test.dart
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_support_mvp/core/app_config.dart';
import 'package:travel_support_mvp/core/app_controller.dart';
import 'package:travel_support_mvp/repositories/api_travel_repository.dart';

void main() {
  test('로그인 → 지역 해석 → 잡 생성 → PENDING 확인 (분석 화면과 동일 경로)', () async {
    SharedPreferences.setMockInitialValues({});
    final config = AppConfig.fromEnvironment();
    expect(config.useMockApi, isFalse, reason: '실서버 모드여야 한다');

    final controller = AppController(repository: ApiTravelRepository(config));
    await controller.loginWithCredentials(loginId: 'sample', password: '1234');
    expect(controller.isLoggedIn, isTrue, reason: '로그인 실패: ${controller.errorMessage}');
    final userId = controller.currentUser!.id;

    // 분석 화면 _boot과 동일 — 지역 이름 → id 해석.
    final regions = await controller.repository.getRegions();
    final gangjin = regions.firstWhere((r) => r.name == '강진');

    // 잡 생성 (여행 없이 지역 귀속 — 테스트 전용 URL로 기존 잡 재사용 회피).
    final url =
        'https://www.youtube.com/watch?v=FLOWTEST${DateTime.now().millisecondsSinceEpoch % 100000}';
    final created = await controller.repository.createYoutubeCourseJob(
      userId: userId,
      tripId: null,
      regionId: gangjin.id,
      youtubeUrl: url,
    );
    expect(created.jobId, isNotEmpty, reason: '잡 생성 실패');

    // 서버에 실제로 잡이 존재하고 대기/처리 중이어야 한다 (완료로 점프하면 안 됨).
    final job = await controller.repository.getYoutubeCourseJob(created.jobId);
    expect(job.isCompleted, isFalse,
        reason: '생성 직후 완료 상태면 대기 화면이 스킵된다 — 상태: ${job.status}');
    expect(job.isPending || job.isProcessing, isTrue,
        reason: '예상 밖 상태: ${job.status}');
  });
}
