import 'dart:math';

import 'package:flutter/material.dart';

/// 프로필 아바타 프리셋 + 반익명 닉네임 생성 (커뮤니티 profiles 계약: nickname·avatar_preset).
/// 계정 실명과 분리 — 화면 표시·인사말은 닉네임/아바타를 사용한다.
///
/// 아바타 = 배경색 + 여행 아이콘의 자유 조합.
/// 저장값(`avatar_preset`)은 `"<색 인덱스>:<아이콘 인덱스>"` 문자열로 인코딩한다.

/// 아바타 배경색 팔레트 — 앱 톤에 맞춘 파스텔(원 위에 이모지).
const avatarColors = <Color>[
  Color(0xFFE0F2FE), // 하늘 (p100, 메인)
  Color(0xFFE4F6F2), // 민트 틴트
  Color(0xFFFDEAEA), // 코랄 틴트
  Color(0xFFFFF3E2), // 소프트 앰버
  Color(0xFFEDE9FE), // 소프트 바이올렛
  Color(0xFFDCFCE7), // 소프트 그린
];

/// 여행 관련 아바타 이모지.
const avatarEmojis = <String>[
  '🧳', '✈️', '🏖️', '⛰️', '🗺️', '📸',
  '⛵', '🎒', '🏔️', '🧭', '🚃', '🍜',
  '☕', '🌊', '🌴', '🏨',
];

String get defaultAvatarPreset => encodeAvatar(0, 0);

/// (색 인덱스, 이모지 인덱스) → 저장 문자열.
String encodeAvatar(int colorIndex, int emojiIndex) =>
    '$colorIndex:$emojiIndex';

/// 저장 문자열 → (배경색, 이모지). 형식이 깨지면 기본값(0,0)으로 폴백.
({Color color, String emoji, int colorIndex, int emojiIndex}) decodeAvatar(
    String preset) {
  var colorIndex = 0;
  var emojiIndex = 0;
  final parts = preset.split(':');
  if (parts.length == 2) {
    colorIndex = int.tryParse(parts[0]) ?? 0;
    emojiIndex = int.tryParse(parts[1]) ?? 0;
  }
  colorIndex = colorIndex % avatarColors.length;
  emojiIndex = emojiIndex % avatarEmojis.length;
  return (
    color: avatarColors[colorIndex],
    emoji: avatarEmojis[emojiIndex],
    colorIndex: colorIndex,
    emojiIndex: emojiIndex,
  );
}

/// 랜덤 아바타 조합 (가입 시 초기값).
String randomAvatar([Random? random]) {
  final rng = random ?? Random();
  return encodeAvatar(
      rng.nextInt(avatarColors.length), rng.nextInt(avatarEmojis.length));
}

const _nickAdjectives = <String>[
  '여행하는', '느긋한', '부지런한', '설레는', '바다보는', '산타는',
  '미식하는', '골목누비는', '노을보는', '즉흥적인', '든든한', '푸른',
];

const _nickNouns = <String>[
  '민트', '고래', '수달', '바다', '유자', '동백',
  '파도', '노을', '골목', '갈매기', '밤바다', '청귤',
];

/// "여행하는민트42" 형태의 반익명 닉네임을 랜덤 생성한다.
String randomNickname([Random? random]) {
  final rng = random ?? Random();
  final adjective = _nickAdjectives[rng.nextInt(_nickAdjectives.length)];
  final noun = _nickNouns[rng.nextInt(_nickNouns.length)];
  final number = rng.nextInt(90) + 10; // 두 자리
  return '$adjective$noun$number';
}
