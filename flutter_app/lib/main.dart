import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_config.dart';
import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'repositories/api_travel_repository.dart';
import 'repositories/mock_travel_repository.dart';
import 'repositories/travel_repository.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
  final config = AppConfig.fromEnvironment();
  final repository = _buildRepository(config);
  final controller = AppController(repository: repository);
  await controller.initializePushNotifications();
  runApp(TravelSupportApp(config: config, repository: repository, controller: controller));
}

TravelRepository _buildRepository(AppConfig config) {
  if (config.useMockApi) {
    return MockTravelRepository();
  }
  return ApiTravelRepository(config);
}

class TravelSupportApp extends StatelessWidget {
  const TravelSupportApp({
    super.key,
    required this.config,
    required this.repository,
    required this.controller,
  });

  final AppConfig config;
  final TravelRepository repository;
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
        title: '반값여행',
        theme: buildHalftripTheme(),
        home: const _RootPage(),
        builder: (context, child) {
          if (child == null) {
            return const SizedBox.shrink();
          }
          return _MobilePrototypeViewport(child: child);
        },
      ),
    );
  }
}

class _RootPage extends StatelessWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isLoggedIn) {
          return const LoginScreen();
        }
        return const MainNavigationScreen();
      },
    );
  }
}

class _MobilePrototypeViewport extends StatelessWidget {
  const _MobilePrototypeViewport({required this.child});

  final Widget child;

  static const double _mobileCanvasWidth = 430;
  static const double _desktopPreviewScale = 0.88;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final useDesktopFrame = screenWidth > _mobileCanvasWidth + 48;

    if (!useDesktopFrame) {
      return child;
    }

    return ColoredBox(
      color: const Color(0xFFE9EEF3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _mobileCanvasWidth,
          ),
          child: SizedBox(
            height: mediaQuery.size.height,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.scale(
                    scale: _desktopPreviewScale,
                    alignment: Alignment.topCenter,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
