import 'package:flutter/material.dart';

/// 디자인 시스템 컬러 토큰 (halftrip-design/SPEC-디자인시스템.md).
/// 화면에서 hex 직접 쓰지 말고 반드시 토큰 사용.
abstract final class AppColors {
  // Primary (하늘색)
  static const p50 = Color(0xFFF0F9FF);
  static const p100 = Color(0xFFE0F2FE);
  static const p200 = Color(0xFFBAE6FD);
  static const p300 = Color(0xFF93D5F5);
  static const p400 = Color(0xFF38BDF8);
  static const p500 = Color(0xFF0EA5E9); // 메인 브랜드
  static const p600 = Color(0xFF0284C7);
  static const p700 = Color(0xFF0369A1);

  // Neutral
  static const ink9 = Color(0xFF0F172A);
  static const ink7 = Color(0xFF334155);
  static const ink5 = Color(0xFF64748B);
  static const ink4 = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const surf = Color(0xFFF8FAFC);
  static const track = Color(0xFFEFF3F8);
  static const bg = Color(0xFFF7FAFD);
  static const gray = Color(0xFFCBD5E1);
  static const white = Color(0xFFFFFFFF);

  // Semantic
  static const success = Color(0xFF22B35E);
  static const warning = Color(0xFFF5A623);
  static const gold = Color(0xFFFFC107); // 다녀온 지역 도장 (밝은 노랑)
  static const danger = Color(0xFFEF4444);
  static const wallet = Color(0xFFFF6B00);

  // 보조 포인트 (로고색 — 특수 강조만)
  static const mint = Color(0xFF57C5B4);
  static const mintDeep = Color(0xFF1F9E8C);
  static const mintTint = Color(0xFFE4F6F2);
  static const coral = Color(0xFFF08080);
  static const coralDeep = Color(0xFFD9534F);
  static const coralTint = Color(0xFFFDEAEA);

  // 시맨틱 틴트 (배지·배너 배경)
  static const successTint = Color(0xFFEAF8F0);
  static const dangerTint = Color(0xFFFEECEC);
  static const warningTint = Color(0xFFFFF3E2);
}

/// 그림자 토큰.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 28, offset: Offset(0, 10)),
  ];
  static const soft = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 3)),
  ];
  static const float = [
    BoxShadow(
        color: Color(0x290F172A),
        blurRadius: 38,
        spreadRadius: -6,
        offset: Offset(0, 16)),
  ];
}
