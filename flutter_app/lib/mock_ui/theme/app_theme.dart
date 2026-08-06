import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 하프트립 목업 테마 — 토스풍(테두리 없음·소프트 그림자), Pretendard.
ThemeData buildAppTheme() {
  const font = 'Pretendard';
  return ThemeData(
    useMaterial3: true,
    fontFamily: font,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.p500,
      primary: AppColors.p500,
      surface: AppColors.bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.ink9),
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.ink9,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.ink9),
      headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.ink9,
          letterSpacing: -1),
      headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppColors.ink9,
          letterSpacing: -.5),
      titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.ink9,
          letterSpacing: -.5),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink9),
      bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.ink7,
          height: 1.45),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.p500,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
            fontFamily: font, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink9,
      contentTextStyle: const TextStyle(
          fontFamily: font,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.p500
              : AppColors.gray),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
  );
}
