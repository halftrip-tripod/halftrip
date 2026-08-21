import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';

/// 체크박스 정본 — 출발 준비 체크리스트 스타일. 모든 체크리스트는 이걸 쓴다.
/// 22×22 둥근 사각(radius 7) · 체크 시 p500 채움 + 흰 체크(15) · 미체크 시 흰 배경 + line 2px.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.p500 : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: AppColors.line, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}
