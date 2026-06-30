import 'dart:convert';
import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: const Text('전자서명'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: GestureDetector(
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
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(_points.clear),
                  child: const Text('지우기'),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '손가락으로 이 영역에 서명해 주세요',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_encode(_points)),
          child: const Text('저장'),
        ),
      ],
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
      ..color = const Color(0xFF0F5132)
      ..strokeWidth = 3
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
