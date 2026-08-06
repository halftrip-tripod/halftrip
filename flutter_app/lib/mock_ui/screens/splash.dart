import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 시작 스플래시 — 하늘 그라데이션 위에 3D 로고.
/// 루트 게이트(_RootGate)가 잠깐 보여준 뒤 로그인/홈으로 페이드 전환한다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // 아주 연한 하늘 (거의 흰색 → 옅은 하늘) — 로고가 잘 보이게.
          colors: [AppColors.p50, AppColors.p100, AppColors.p200],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Center(
        child: Image(
          image: AssetImage('assets/logo/logo-3d.png'),
          width: 300,
        ),
      ),
    );
  }
}
