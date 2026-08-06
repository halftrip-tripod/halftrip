import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 세그먼트 필터 (트랙 배경 위 흰 칩). 디자인의 `.seg`에 대응.
class SegChips extends StatelessWidget {
  const SegChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : null,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    boxShadow: i == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: i == selected ? AppColors.ink9 : AppColors.ink5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
