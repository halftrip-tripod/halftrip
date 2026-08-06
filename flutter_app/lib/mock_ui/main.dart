import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() => runApp(const HalftripMockupApp());

class HalftripMockupApp extends StatelessWidget {
  const HalftripMockupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하프트립 목업',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 데스크톱 브라우저에서는 390×844 폰 프레임 안에 렌더링 (proto.html 뷰어와 동일 컨셉).
      builder: (context, child) => _PhoneFrame(child: child!),
      home: ListenableBuilder(
        listenable: AppState.I,
        builder: (_, _) =>
            AppState.I.loggedIn ? const MainShell() : const LoginScreen(),
      ),
    );
  }
}

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
            // 사이드 버튼 (좌: 볼륨 / 우: 전원)
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
            // 본체
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
                  // 상태바 높이(아일랜드 영역)만큼 SafeArea 확보
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 38),
                      viewPadding: const EdgeInsets.only(top: 38),
                    ),
                    child: child,
                  ),
                  // 다이나믹 아일랜드
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
