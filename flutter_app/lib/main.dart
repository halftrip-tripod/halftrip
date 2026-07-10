import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_config.dart';
import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'mock_ui/screens/onboarding.dart';
import 'mock_ui/screens/shell.dart';
import 'mock_ui/theme/app_theme.dart';
import 'repositories/api_travel_repository.dart';
import 'repositories/mock_travel_repository.dart';
import 'repositories/travel_repository.dart';
import 'theme/app_colors.dart';

/// 하프트립 — UI는 목업(halftrip-mockup 1:1) 화면, 데이터는 AppController/Repository.
/// USE_MOCK_API 플래그로 mock ↔ 실서버 전환.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
  final config = AppConfig.fromEnvironment();
  final repository = _buildRepository(config);
  final controller = AppController(repository: repository);
  await controller.initializePushNotifications();
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

/// 로그인 → 거주지 설정 → 메인 셸 게이트.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
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
