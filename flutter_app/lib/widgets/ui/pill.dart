import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 상태 라벨 칩 색상 톤. 디자인의 `.pill.*`에 대응.
enum PillTone { sky, mint, gold, gray, success, danger, warning }

/// 작은 상태 라벨 칩 (접수중·환급완료·디민증 등).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = PillTone.sky, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _palette(PillTone t) => switch (t) {
        PillTone.sky => (AppColors.p100, AppColors.p700),
        PillTone.mint => (AppColors.mintTint, AppColors.mintDeep),
        PillTone.gold => (const Color(0xFFFBF1D5), const Color(0xFFA9790C)),
        PillTone.gray => (AppColors.track, AppColors.ink5),
        PillTone.success => (const Color(0xFFE7F7EE), const Color(0xFF1B8E4B)),
        PillTone.danger => (const Color(0xFFFEECEC), AppColors.danger),
        PillTone.warning => (const Color(0xFFFFF3E2), const Color(0xFFB8731B)),
      };
}
