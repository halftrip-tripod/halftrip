import 'dart:convert';
import 'package:flutter/material.dart';

import '../mock_ui/theme/app_colors.dart';

Future<String?> showSignaturePadDialog(
  BuildContext context, {
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SignaturePadDialog(initialValue: initialValue),
  );
}

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  late List<Offset?> _points;

  @override
  void initState() {
    super.initState();
    _points = _decode(widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('전자서명',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -.4)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(_points.clear),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 14, color: AppColors.ink5),
                    SizedBox(width: 4),
                    Text('지우기',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink5)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(children: [
                  if (_points.isEmpty)
                    const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.draw_rounded, size: 26, color: AppColors.ink4),
                        SizedBox(height: 6),
                        Text('이 영역에 손가락으로 서명해 주세요',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink4)),
                      ]),
                    ),
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() => _points.add(details.localPosition));
                    },
                    onPanUpdate: (details) {
                      setState(() => _points.add(details.localPosition));
                    },
                    onPanEnd: (_) {
                      setState(() => _points.add(null));
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(_points),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surf,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: const Text('취소',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink7)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(_encode(_points)),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.p500,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x470EA5E9),
                            blurRadius: 18,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Text('서명 완료',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  List<Offset?> _decode(String? value) {
    if (value == null || value.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(value) as List<dynamic>;
      return list.map((item) {
        if (item == null) {
          return null;
        }
        final map = item as Map<String, dynamic>;
        return Offset(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _encode(List<Offset?> points) {
    final payload = points
        .map(
          (point) => point == null ? null : {'x': point.dx, 'y': point.dy},
        )
        .toList();
    return jsonEncode(payload);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink9
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    // points는 같은 리스트를 in-place로 add하므로 참조 비교로는 갱신 감지 불가
    // → 항상 다시 그려 실시간 획이 보이게 한다.
    return true;
  }
}
