import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'core/app_config.dart';
import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'mock_ui/screens/onboarding.dart';
import 'mock_ui/screens/shell.dart';
import 'mock_ui/screens/splash.dart';
import 'mock_ui/theme/app_theme.dart';
import 'repositories/api_travel_repository.dart';
import 'repositories/mock_travel_repository.dart';
import 'repositories/travel_repository.dart';
import 'theme/app_colors.dart';

/// 하프트립 — UI는 목업(halftrip-mockup 1:1) 화면, 데이터는 AppController/Repository.
/// USE_MOCK_API 플래그로 mock ↔ 실서버 전환.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    // 세로 전용 — 화면이 폰 목업 프레임 기준이라 가로로 돌리면 레이아웃이 깨진다.
    // (manifest의 screenOrientation과 이중 잠금)
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase 설정(google-services.json)이 없거나 잘못돼도 앱은 뜨게 한다.
    }
  }
  final config = AppConfig.fromEnvironment();
  if (config.kakaoLoginConfigured) {
    // 카카오 로그인 SDK — 키는 --dart-define(KAKAO_NATIVE_APP_KEY 등)으로 주입, 미설정이면 스킵.
    kakao.KakaoSdk.init(
      nativeAppKey: config.kakaoNativeAppKey,
      javaScriptAppKey: config.kakaoJavaScriptKey,
    );
  }
  final repository = _buildRepository(config);
  final controller = AppController(repository: repository);
  try {
    await controller.initializePushNotifications();
  } catch (_) {
    // FCM 초기화 실패는 무시(푸시만 비활성, UI는 정상).
  }
  runApp(HalftripApp(controller: controller));
}

TravelRepository _buildRepository(AppConfig config) {
  if (config.useMockApi) {
    return MockTravelRepository();
  }
  return ApiTravelRepository(config);
}

class HalftripApp extends StatelessWidget {
  const HalftripApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        navigatorKey: controller.navigatorKey,
        scaffoldMessengerKey: controller.scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        title: '하프트립',
        theme: buildAppTheme(),
        home: const _RootGate(),
        builder: (context, child) => _PhoneFrame(child: child!),
      ),
    );
  }
}

/// 스플래시 → 로그인 → 거주지 설정 → 메인 셸 게이트.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _splashDone = false;
  bool _restoreSettled = false;

  @override
  void initState() {
    super.initState();
    // 스플래시 노출 후 실제 첫 화면으로 페이드 전환.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _splashDone = true);
    });
    // 스플래시 동안 저장된 세션으로 자동 로그인 시도. 서버가 느리면(콜드 스타트)
    // 8초까지만 스플래시를 잡아두고 로그인 화면을 먼저 연다 — 복원이 뒤늦게
    // 성공하면 컨트롤러 알림으로 메인에 자동 진입한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context)
          .restoreSession()
          .timeout(const Duration(seconds: 8), onTimeout: () => false)
          .whenComplete(() {
        if (mounted) setState(() => _restoreSettled = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: !_splashDone || !_restoreSettled
          ? const SplashScreen()
          : KeyedSubtree(
              key: const ValueKey('root'),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  if (!controller.isLoggedIn) {
                    return const LoginScreen();
                  }
                  if (controller.needsResidenceSetup) {
                    return const ResidenceScreen();
                  }
                  return const MainShell();
                },
              ),
            ),
    );
  }
}

/// 데스크톱 브라우저에서는 390×844 폰 목업 프레임 안에 렌더링.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 모바일 기기·좁은 창에서는 프레임 없이 그대로.
      if (constraints.maxWidth <= 500) return child;

      const bezel = 12.0;
      final height = math.min(constraints.maxHeight - 56, 852.0);
      return ColoredBox(
        color: const Color(0xFFE9EEF3),
        child: Center(
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: -3,
              top: height * .22,
              child: _sideButton(height: 34),
            ),
            Positioned(
              left: -3,
              top: height * .22 + 46,
              child: _sideButton(height: 58),
            ),
            Positioned(
              right: -3,
              top: height * .28,
              child: _sideButton(height: 76),
            ),
            Container(
              width: 390 + bezel * 2,
              height: height,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A4557), Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(54),
                boxShadow: const [
                  BoxShadow(color: Color(0x4D0F172A), blurRadius: 70, offset: Offset(0, 30)),
                  BoxShadow(color: Color(0x260F172A), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(42),
                child: Stack(children: [
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 38),
                      viewPadding: const EdgeInsets.only(top: 38),
                    ),
                    child: ColoredBox(color: AppColors.bg, child: child),
                  ),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 108,
                        height: 27,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _sideButton({required double height}) => Container(
        width: 3.5,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF25324A),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
