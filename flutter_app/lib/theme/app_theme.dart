import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 하프트립 앱 테마 (토스풍·하늘색·Pretendard).
/// main.dart 에서 `theme: buildHalftripTheme()` 로 사용.
ThemeData buildHalftripTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.p500,
    primary: AppColors.p500,
    onPrimary: Colors.white,
    secondary: AppColors.mintDeep,
    surface: Colors.white,
    onSurface: AppColors.ink9,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: AppColors.bg,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink9,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerColor: AppColors.line,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.white,
      margin: EdgeInsets.zero,
    ),
    textTheme: _textTheme(base.textTheme),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.p500,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.track,
        disabledForegroundColor: AppColors.ink4,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink7,
        backgroundColor: AppColors.surf,
        side: BorderSide.none,
        // 최소 높이만 보장(너비 강제 X). Size.fromHeight는 최소 너비=∞라
        // Row 인라인 버튼에서 무한폭 크래시 → Size(0, h)로.
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.p600,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink9,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentTextStyle: const TextStyle(
        fontFamily: 'Pretendard',
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.p100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppColors.p600
              : AppColors.ink4,
        ),
      ),
    ),
  );
}

TextTheme _textTheme(TextTheme b) {
  return b.copyWith(
    headlineLarge: b.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1),
    headlineMedium: b.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1),
    headlineSmall: b.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -0.5),
    titleLarge: b.titleLarge?.copyWith(
        fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -0.3),
    titleMedium: b.titleMedium?.copyWith(
        fontWeight: FontWeight.w800, color: AppColors.ink9),
    titleSmall: b.titleSmall?.copyWith(
        fontWeight: FontWeight.w700, color: AppColors.ink9),
    bodyLarge: b.bodyLarge?.copyWith(color: AppColors.ink7, height: 1.5),
    bodyMedium: b.bodyMedium?.copyWith(color: AppColors.ink7, height: 1.45),
    bodySmall: b.bodySmall?.copyWith(color: AppColors.ink5, height: 1.4),
    labelLarge: b.labelLarge?.copyWith(
        fontWeight: FontWeight.w800, color: AppColors.ink9),
  );
}
