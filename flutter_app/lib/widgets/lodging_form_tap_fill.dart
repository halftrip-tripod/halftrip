import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
// 웹에서도 pdfx로 페이지를 이미지로 그린다 — 브라우저 내장 뷰어(<embed>)는 배율·여백을 제멋대로
// 잡아 좌표를 겹칠 수 없다. io 구현은 dart:io를 쓰지 않아 웹에서도 그대로 돈다.
import 'pdf_embed_view_io.dart';

/// 숙박확인서 양식 위에 직접 입력하는 화면.
///
/// 양식 PDF를 그대로 깔고 그 위에 **보이지 않는** 입력칸을 서버 좌표대로 올린다 — 빈칸을 누르면
/// 그 자리에 커서가 생기고, 쓴 글자는 양식에 적은 것처럼 보인다. 박스·테두리는 그리지 않는다.
///
/// 좌표는 서버가 주는 720 x 1018 캔버스 기준(2쪽은 y >= 1018). 서버가 PDF에서 추출한 좌표
/// (`template.tapToFill`)일 때만 이 화면을 쓴다 — 손으로 잰 좌표는 칸에서 밀린다.
///
/// A4를 폰 폭에 맞추면 글자가 7px쯤이라 읽을 수 없다. 칸에 포커스가 가면 글자가 16px쯤 되도록
/// 그 칸으로 확대하고, 키보드에 가리지 않게 화면 위쪽에 둔다. 평소엔 핀치로 자유롭게 확대·이동.
class LodgingFormTapFill extends StatefulWidget {
  const LodgingFormTapFill({
    super.key,
    required this.fields,
    required this.templatePdfUrl,
    required this.textControllers,
    required this.checkboxValues,
    required this.signatureValues,
    required this.onTapSignature,
    required this.onToggleCheckbox,
    required this.onPickDate,
    this.authToken,
    this.controller,
  });

  final List<LodgingFormFieldItem> fields;
  final String templatePdfUrl;
  final String? authToken;

  /// 화면(State)이 들고 있는 값 저장소를 그대로 쓴다 — 목록형 입력 화면과 값이 공유된다.
  final Map<String, TextEditingController> textControllers;
  final Map<String, bool> checkboxValues;
  final Map<String, String> signatureValues;

  final ValueChanged<String> onTapSignature;
  final ValueChanged<String> onToggleCheckbox;
  final ValueChanged<String> onPickDate;
  final LodgingFormTapFillController? controller;

  @override
  State<LodgingFormTapFill> createState() => _LodgingFormTapFillState();
}

/// 바깥(저장 버튼 등)에서 "이 칸이 비었어요"를 짚어 주기 위한 손잡이.
class LodgingFormTapFillController {
  _LodgingFormTapFillState? _state;

  /// 그 칸으로 이동해 잠깐 강조한다. 글자 칸이면 커서도 넣는다.
  void attention(String fieldKey) => _state?._attention(fieldKey);
}

const double _baseWidth = 720;
const double _baseHeight = 1018;
// 양식 본문 글자(12pt, A4 595pt 폭)를 720 캔버스로 옮긴 크기.
const double _baseFontSize = 14.5;
// 포커스 때 화면에서 이 크기로 보이도록 확대한다.
const double _focusedFontSize = 16;
const Color _ink = Color(0xFF111827);

class _LodgingFormTapFillState extends State<LodgingFormTapFill>
    with TickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  final Map<int, FocusNode> _focusNodes = {};
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  AnimationController? _zoom;
  Size _viewport = Size.zero;
  int? _focusedIndex;
  String? _attentionKey;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    // 처음 들어왔을 때만 입력할 수 있는 칸을 잠깐 비춘다 — 이후엔 양식만 보인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hint.forward();
    });
  }

  @override
  void didUpdateWidget(covariant LodgingFormTapFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller?._state = null;
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _zoom?.dispose();
    _hint.dispose();
    _transform.dispose();
    super.dispose();
  }

  int get _pageCount {
    var bottom = _baseHeight;
    for (final field in widget.fields) {
      bottom = math.max(bottom, field.y + field.height);
    }
    return (bottom / _baseHeight).ceil().clamp(1, 8).toInt();
  }

  bool _isTextInput(LodgingFormFieldItem field) =>
      field.editable && !field.isSignature && !field.isCheckbox && !field.isDate;

  /// 같은 키가 여러 칸에 나오면(하단 업소명·주소 등) 첫 편집 칸만 입력을 받고 나머지는 값을 비춘다.
  bool _ownsInput(int index) {
    final field = widget.fields[index];
    if (!_isTextInput(field)) return false;
    for (var i = 0; i < index; i++) {
      if (widget.fields[i].key == field.key && _isTextInput(widget.fields[i])) {
        return false;
      }
    }
    return true;
  }

  FocusNode _focusNodeFor(int index) {
    return _focusNodes.putIfAbsent(index, () {
      final node = FocusNode();
      node.addListener(() {
        if (!mounted) return;
        if (node.hasFocus) {
          setState(() => _focusedIndex = index);
          _zoomToField(index);
        } else if (_focusedIndex == index) {
          setState(() => _focusedIndex = null);
        }
      });
      return node;
    });
  }

  void _attention(String fieldKey) {
    final index = widget.fields.indexWhere(
      (field) => field.key == fieldKey && field.editable,
    );
    if (index < 0) return;
    setState(() => _attentionKey = fieldKey);
    if (_ownsInput(index)) {
      _focusNodeFor(index).requestFocus();
    } else {
      _zoomToField(index);
    }
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _attentionKey == fieldKey) {
        setState(() => _attentionKey = null);
      }
    });
  }

  void _zoomToField(int index) {
    if (_viewport.isEmpty) return;
    final field = widget.fields[index];
    final pageScale = _viewport.width / _baseWidth;
    final contentHeight = pageScale * _baseHeight * _pageCount;
    final zoom =
        (_focusedFontSize / (_baseFontSize * pageScale)).clamp(1.0, 4.0).toDouble();

    // 칸의 왼쪽 위를 화면 (12, 높이의 18%)에 둔다 — 키보드가 올라와도 가리지 않는 자리.
    var dx = 12 - field.x * pageScale * zoom;
    var dy = _viewport.height * 0.18 - field.y * pageScale * zoom;
    dx = dx
        .clamp(math.min(0.0, _viewport.width - _viewport.width * zoom), 0.0)
        .toDouble();
    dy = dy
        .clamp(math.min(0.0, _viewport.height - contentHeight * zoom), 0.0)
        .toDouble();

    final target = Matrix4.identity()
      ..setEntry(0, 0, zoom)
      ..setEntry(1, 1, zoom)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
    _zoom?.dispose();
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final tween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    animation.addListener(() => _transform.value = tween.value);
    _zoom = animation..forward();
  }

  void _focusNext(int fromIndex) {
    for (var i = fromIndex + 1; i < widget.fields.length; i++) {
      if (_ownsInput(i)) {
        _focusNodeFor(i).requestFocus();
        return;
      }
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport != _viewport) {
          _viewport = viewport;
          // 키보드가 올라와 화면이 줄면, 입력 중인 칸이 다시 보이는 자리로 옮긴다.
          final focused = _focusedIndex;
          if (focused != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _focusedIndex == focused) _zoomToField(focused);
            });
          }
        }
        final pageScale = viewport.width / _baseWidth;
        final pageCount = _pageCount;
        final contentHeight = pageScale * _baseHeight * pageCount;

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: viewport.width,
              height: contentHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PdfEmbedView(
                      url: widget.templatePdfUrl,
                      height: contentHeight,
                      pageCount: pageCount,
                      authToken: widget.authToken,
                      plain: true,
                    ),
                  ),
                  for (var i = 0; i < widget.fields.length; i++)
                    if (widget.fields[i].type != 'hidden')
                      _buildField(i, pageScale),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(int index, double pageScale) {
    final field = widget.fields[index];
    final rect = Rect.fromLTWH(
      field.x * pageScale,
      field.y * pageScale,
      field.width * pageScale,
      field.height * pageScale,
    );
    // 월·일처럼 작은 칸은 손가락으로 맞히기 어렵다 — 누르는 영역만 조금 넓힌다(보이지 않는다).
    final inflate = field.editable ? math.min(6.0, 10 * pageScale) : 0.0;
    final hit = rect.inflate(inflate);

    Widget content;
    VoidCallback? onTap;
    if (field.isSignature) {
      content = _SignatureInk(value: widget.signatureValues[field.key] ?? '');
      onTap = field.editable ? () => widget.onTapSignature(field.key) : null;
    } else if (field.isCheckbox) {
      final checked = widget.checkboxValues[field.key] ?? false;
      content = checked
          ? FittedBox(
              child: Text('✓',
                  style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: rect.height)),
            )
          : const SizedBox.expand();
      onTap = field.editable ? () => widget.onToggleCheckbox(field.key) : null;
    } else if (_ownsInput(index)) {
      content = _buildTextInput(index, field, rect, pageScale);
      onTap = () => _focusNodeFor(index).requestFocus();
    } else {
      final controller = widget.textControllers[field.key];
      content = controller == null
          ? const SizedBox.expand()
          : ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) =>
                  _FittedValue(text: value.text, rect: rect, scale: pageScale),
            );
      onTap = field.editable && field.isDate
          ? () => widget.onPickDate(field.key)
          : null;
    }

    return Positioned.fromRect(
      rect: hit,
      child: GestureDetector(
        behavior: onTap == null
            ? HitTestBehavior.deferToChild
            : HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: _hint,
          builder: (context, child) {
            // 0→1→0 을 두 번: 처음 들어왔을 때 입력 칸을 연하게 두 번 깜빡인다.
            final pulse = field.editable
                ? math.sin(_hint.value * math.pi * 2).abs() *
                    (1 - _hint.value)
                : 0.0;
            final attention = _attentionKey == field.key && field.editable;
            final color = attention
                ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                : const Color(0xFF3B82F6).withValues(alpha: 0.22 * pulse);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
              child: child,
            );
          },
          child: Padding(padding: EdgeInsets.all(inflate), child: content),
        ),
      ),
    );
  }

  Widget _buildTextInput(
    int index,
    LodgingFormFieldItem field,
    Rect rect,
    double pageScale,
  ) {
    final controller = widget.textControllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    final key = field.key;
    final numeric = key.contains('amount') ||
        key.endsWith('_month') ||
        key.endsWith('_day') ||
        key.endsWith('_year') ||
        key.contains('count');
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final style = _fittedStyle(value.text, rect, pageScale, field.multiline);
        final centered = _isCentered(rect, pageScale);
        return Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: TextField(
            controller: controller,
            focusNode: _focusNodeFor(index),
            style: style,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            maxLines: field.multiline ? 2 : 1,
            minLines: 1,
            cursorColor: const Color(0xFF2563EB),
            cursorWidth: math.max(1.0, 1.5 * pageScale),
            keyboardType: key.contains('phone')
                ? TextInputType.phone
                : numeric
                    ? TextInputType.number
                    : TextInputType.text,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _focusNext(index),
            // 입력 중 자동 스크롤은 우리가 확대·이동으로 직접 처리한다.
            scrollPadding: EdgeInsets.zero,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: centered ? 0 : 8 * pageScale,
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isCentered(Rect rect, double scale) => rect.width / scale < 220;

/// 칸을 넘치면 글자를 줄인다(최소 60%). 그래도 넘치면 잘리지 않고 칸 안에서 스크롤된다.
TextStyle _fittedStyle(String text, Rect rect, double scale, bool multiline) {
  var size = math.min(_baseFontSize * scale, rect.height * 0.78);
  final available = rect.width - (_isCentered(rect, scale) ? 2 : 16 * scale);
  if (text.isNotEmpty && available > 0) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final room = multiline ? available * 1.9 : available;
    if (painter.width > room) {
      size = math.max(size * 0.6, size * room / painter.width);
    }
  }
  return TextStyle(
    fontSize: size,
    height: 1.15,
    color: _ink,
    fontWeight: FontWeight.w500,
  );
}

class _FittedValue extends StatelessWidget {
  const _FittedValue({required this.text, required this.rect, required this.scale});

  final String text;
  final Rect rect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final centered = _isCentered(rect, scale);
    // 60%까지 줄여도 안 들어가면 잘라낸다(서버 PDF도 같은 규칙) — 옆 글자 위로 넘치지 않게.
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: centered ? 0 : 8 * scale),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: _fittedStyle(text, rect, scale, false),
        ),
      ),
    );
  }
}

/// 서명 획(JSON: [{x,y}, null(펜 뗌), ...])을 칸 안에 비율을 지켜 가운데로 그린다.
class _SignatureInk extends StatelessWidget {
  const _SignatureInk({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final strokes = _parse(value);
    if (strokes.isEmpty) return const SizedBox.expand();
    return CustomPaint(size: Size.infinite, painter: _SignatureInkPainter(strokes));
  }

  static List<List<Offset>> _parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final strokes = <List<Offset>>[[]];
      for (final point in decoded) {
        if (point is Map && point['x'] is num && point['y'] is num) {
          strokes.last.add(Offset(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          ));
        } else if (strokes.last.isNotEmpty) {
          strokes.add([]);
        }
      }
      return strokes.where((stroke) => stroke.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}

class _SignatureInkPainter extends CustomPainter {
  _SignatureInkPainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final points = strokes.expand((stroke) => stroke).toList();
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final point in points) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    final width = math.max(bounds.width, 1.0);
    final height = math.max(bounds.height, 1.0);
    final scale = math.min(size.width / width, size.height / height) * 0.92;
    final offset = Offset(
      (size.width - width * scale) / 2 - bounds.left * scale,
      (size.height - height * scale) / 2 - bounds.top * scale,
    );
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(0.8, size.height * 0.045);
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first * scale + offset,
          paint.strokeWidth / 2,
          Paint()..color = _ink,
        );
        continue;
      }
      final path = Path()
        ..moveTo(stroke.first.dx * scale + offset.dx, stroke.first.dy * scale + offset.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * scale + offset.dx, point.dy * scale + offset.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureInkPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
