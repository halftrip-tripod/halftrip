import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import 'pdf_embed_view.dart';

const double _pdfBaseWidth = 720;
const double _pdfBaseHeight = 1018;
const double _overlayOffsetX = 0;
const double _overlayOffsetY = 0;
const double _overlayScaleX = 1.0;
const double _overlayScaleY = 1.0;
const double _fieldDragSensitivity = 2.5;
const double _mobilePreviewMaxWidth = 430;
const Map<String, int> _templatePageCounts = {
  'stay_confirm_gangjin.pdf': 2,
  'stay_confirm_yeonggwang.pdf': 2,
};

class _TemplateOverlayProfile {
  const _TemplateOverlayProfile({
    this.textInsetX = 3,
    this.textInsetY = 3,
    this.signatureInsetX = 4,
    this.signatureInsetY = 3,
    this.checkboxInset = 2,
    this.maxCheckboxSize = 14,
  });

  final double textInsetX;
  final double textInsetY;
  final double signatureInsetX;
  final double signatureInsetY;
  final double checkboxInset;
  final double maxCheckboxSize;
}

const Map<String, _TemplateOverlayProfile> _templateOverlayProfiles = {
  'stay_confirm_wando.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 3,
    signatureInsetX: 5,
    signatureInsetY: 3,
    checkboxInset: 2.5,
    maxCheckboxSize: 13,
  ),
  'stay_confirm_pyoungchang.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 5,
    signatureInsetY: 4,
    checkboxInset: 2,
  ),
  'stay_confirm_haenam.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_gangjin.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_hadong.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_milyang.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_namhae.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_yeongam.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 4,
    signatureInsetX: 6,
    signatureInsetY: 4,
  ),
  'stay_confirm_geochang.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 3,
    signatureInsetX: 5,
    signatureInsetY: 3,
    checkboxInset: 2.5,
    maxCheckboxSize: 13,
  ),
  'stay_confirm_gochang.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 3,
    signatureInsetX: 5,
    signatureInsetY: 3,
    checkboxInset: 2.5,
    maxCheckboxSize: 13,
  ),
  'stay_confirm_hapcheon.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 3,
    signatureInsetX: 5,
    signatureInsetY: 3,
    checkboxInset: 2.5,
    maxCheckboxSize: 13,
  ),
  'stay_confirm_yeonggwang.pdf': _TemplateOverlayProfile(
    textInsetX: 4,
    textInsetY: 3,
    signatureInsetX: 5,
    signatureInsetY: 3,
    checkboxInset: 2.5,
    maxCheckboxSize: 13,
  ),
};

const Set<String> _compactFieldKeys = {
  'phone_number_mid',
  'phone_number_last',
  'traveler_phone_mid',
  'traveler_phone_last',
  'payment_date_year',
  'payment_date_month',
  'payment_date_day',
  'confirmation_date_year',
  'confirmation_date_month',
  'confirmation_date_day',
  'confirmation_date_bottom_year',
  'confirmation_date_bottom_month',
  'confirmation_date_bottom_day',
  'occupancy_count',
};

class LodgingFormPreview extends StatelessWidget {
  const LodgingFormPreview({
    super.key,
    required this.formData,
    required this.onTapSignature,
    this.templatePdfUrl,
    this.onTapField,
    this.layoutEditMode = false,
    this.selectedFieldKey,
    this.onSelectField,
    this.onUpdateField,
    this.maxPreviewWidth = _mobilePreviewMaxWidth,
  });

  final LodgingFormData formData;
  final VoidCallback onTapSignature;
  final String? templatePdfUrl;
  final ValueChanged<LodgingFormFieldItem>? onTapField;
  final bool layoutEditMode;
  final String? selectedFieldKey;
  final ValueChanged<String>? onSelectField;
  final ValueChanged<LodgingFormFieldItem>? onUpdateField;
  final double maxPreviewWidth;

  bool get _usesRealTemplate =>
      formData.template.sourceFormat.toUpperCase() != 'PDF_PLACEHOLDER';

  @override
  Widget build(BuildContext context) {
    if (_usesRealTemplate &&
        templatePdfUrl != null &&
        templatePdfUrl!.isNotEmpty) {
      return _RealPdfTemplatePreview(
        formData: formData,
        templatePdfUrl: templatePdfUrl!,
        onTapField: onTapField,
        layoutEditMode: layoutEditMode,
        selectedFieldKey: selectedFieldKey,
        onSelectField: onSelectField,
        onUpdateField: onUpdateField,
        maxPreviewWidth: maxPreviewWidth,
      );
    }
    return _FallbackTemplatePreview(formData: formData);
  }
}

class _RealPdfTemplatePreview extends StatelessWidget {
  const _RealPdfTemplatePreview({
    required this.formData,
    required this.templatePdfUrl,
    required this.onTapField,
    required this.layoutEditMode,
    required this.selectedFieldKey,
    required this.onSelectField,
    required this.onUpdateField,
    required this.maxPreviewWidth,
  });

  final LodgingFormData formData;
  final String templatePdfUrl;
  final ValueChanged<LodgingFormFieldItem>? onTapField;
  final bool layoutEditMode;
  final String? selectedFieldKey;
  final ValueChanged<String>? onSelectField;
  final ValueChanged<LodgingFormFieldItem>? onUpdateField;
  final double maxPreviewWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8DEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxPreviewWidth),
            child: _InteractivePdfOverlay(
              formData: formData,
              templatePdfUrl: templatePdfUrl,
              onTapField: onTapField,
              layoutEditMode: layoutEditMode,
              selectedFieldKey: selectedFieldKey,
              onSelectField: onSelectField,
              onUpdateField: onUpdateField,
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractivePdfOverlay extends StatelessWidget {
  const _InteractivePdfOverlay({
    required this.formData,
    required this.templatePdfUrl,
    required this.onTapField,
    required this.layoutEditMode,
    required this.selectedFieldKey,
    required this.onSelectField,
    required this.onUpdateField,
  });

  final LodgingFormData formData;
  final String templatePdfUrl;
  final ValueChanged<LodgingFormFieldItem>? onTapField;
  final bool layoutEditMode;
  final String? selectedFieldKey;
  final ValueChanged<String>? onSelectField;
  final ValueChanged<LodgingFormFieldItem>? onUpdateField;

  _TemplateOverlayProfile get _profile =>
      _templateOverlayProfiles[formData.template.templateName] ??
      const _TemplateOverlayProfile();

  int get _pageCount {
    final templateName =
        formData.template.templateName
            .split(RegExp(r'[\\/]'))
            .last
            .toLowerCase();
    final configuredPageCount = _templatePageCounts[templateName] ?? 1;
    if (_usesLegacyPercentCoordinates) {
      return configuredPageCount;
    }

    final maxFieldBottom = formData.template.fields
        .where((field) => field.type.toLowerCase() != 'hidden')
        .fold<double>(
          0,
          (maximum, field) => math.max(maximum, field.y + field.height),
        );
    final coordinatePageCount = math.max(
      1,
      (maxFieldBottom / _pdfBaseHeight).ceil(),
    );
    return math.max(configuredPageCount, coordinatePageCount);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final pageCount = _pageCount;
        final pageHeight = outerConstraints.maxWidth * 1.414;
        final previewHeight = pageHeight * pageCount;
        return SizedBox(
          height: previewHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / _pdfBaseWidth;
              final scaleY = pageHeight / _pdfBaseHeight;
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final local = event.localPosition;
                  final pdfX =
                      (local.dx - _overlayOffsetX) / (scaleX * _overlayScaleX);
                  final pdfY =
                      (local.dy - _overlayOffsetY) / (scaleY * _overlayScaleY);
                  debugPrint(
                    'PDF position: x=${pdfX.toStringAsFixed(1)}, y=${pdfY.toStringAsFixed(1)}',
                  );
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: PdfEmbedView(
                          url: templatePdfUrl,
                          height: previewHeight,
                          pageCount: pageCount,
                        ),
                      ),
                    ),
                    ...formData.template.fields
                        .where(
                          (field) =>
                              field.type.toLowerCase() != 'hidden' &&
                              _hasReasonablePlacement(field),
                        )
                        .map(
                          (field) => _buildOverlayField(
                            context,
                            constraints,
                            field,
                            pageHeight,
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool get _usesLegacyPercentCoordinates => formData.template.fields
      .where((field) => field.type.toLowerCase() != 'hidden')
      .every(
        (field) =>
            field.x <= 100 &&
            field.y <= 100 &&
            field.width <= 100 &&
            field.height <= 100,
      );

  bool _hasReasonablePlacement(LodgingFormFieldItem field) {
    if (_usesLegacyPercentCoordinates) {
      return field.x >= 0 &&
          field.x <= 100 &&
          field.y >= 0 &&
          field.y <= 100 &&
          field.width > 0 &&
          field.width <= 100 &&
          field.height > 0 &&
          field.height <= 100;
    }

    final totalBaseHeight = _pdfBaseHeight * _pageCount;
    return field.x >= 0 &&
        field.x <= _pdfBaseWidth &&
        field.y >= 0 &&
        field.y <= totalBaseHeight &&
        field.width > 0 &&
        field.width <= _pdfBaseWidth &&
        field.height > 0 &&
        field.height <= _pdfBaseHeight;
  }

  ({double x, double y, double width, double height}) _resolvePdfRect(
    LodgingFormFieldItem field,
  ) {
    if (_usesLegacyPercentCoordinates) {
      return (
        x: field.x / 100 * _pdfBaseWidth,
        y: field.y / 100 * _pdfBaseHeight,
        width: field.width / 100 * _pdfBaseWidth,
        height: field.height / 100 * _pdfBaseHeight,
      );
    }

    return (x: field.x, y: field.y, width: field.width, height: field.height);
  }

  ({double x, double y, double width, double height}) _applySafeInset(
    LodgingFormFieldItem field,
    ({double x, double y, double width, double height}) rect,
  ) {
    if (field.isCheckbox) {
      final inset = _profile.checkboxInset;
      final size =
          (rect.height - (inset * 2))
              .clamp(8, _profile.maxCheckboxSize)
              .toDouble();
      final x = rect.x + ((rect.width - size) / 2);
      final y = rect.y + ((rect.height - size) / 2);
      return (x: x, y: y, width: size, height: size);
    }

    if (_compactFieldKeys.contains(field.key)) {
      const inset = 1.0;
      final width = _safeClampDimension(
        rect.width - (inset * 2),
        minimum: 10,
        maximum: rect.width,
      );
      final height = _safeClampDimension(
        rect.height - (inset * 2),
        minimum: 10,
        maximum: rect.height,
      );
      return (
        x: rect.x + inset,
        y: rect.y + inset,
        width: width,
        height: height,
      );
    }

    if (field.isSignature) {
      final xInset = _profile.signatureInsetX;
      final yInset = _profile.signatureInsetY;
      final width = _safeClampDimension(
        rect.width - (xInset * 2),
        minimum: 16,
        maximum: rect.width,
      );
      final height = _safeClampDimension(
        rect.height - (yInset * 2),
        minimum: 12,
        maximum: rect.height,
      );
      return (
        x: rect.x + xInset,
        y: rect.y + yInset,
        width: width,
        height: height,
      );
    }

    final xInset = _profile.textInsetX;
    final yInset = _profile.textInsetY;
    final width = _safeClampDimension(
      rect.width - (xInset * 2),
      minimum: 18,
      maximum: rect.width,
    );
    final height = _safeClampDimension(
      rect.height - (yInset * 2),
      minimum: 12,
      maximum: rect.height,
    );
    return (
      x: rect.x + xInset,
      y: rect.y + yInset,
      width: width,
      height: height,
    );
  }

  double _safeClampDimension(
    double value, {
    required double minimum,
    required double maximum,
  }) {
    final normalizedMax = math.max(0, maximum);
    final normalizedMin = math.min(minimum, normalizedMax);
    return value.clamp(normalizedMin, normalizedMax).toDouble();
  }

  Widget _buildOverlayField(
    BuildContext context,
    BoxConstraints constraints,
    LodgingFormFieldItem field,
    double pageHeight,
  ) {
    if (field.width <= 0 || field.height <= 0) {
      return const SizedBox.shrink();
    }
    final pdfRect =
        layoutEditMode
            ? _resolvePdfRect(field)
            : _applySafeInset(field, _resolvePdfRect(field));
    final scaleX = constraints.maxWidth / _pdfBaseWidth;
    final scaleY = pageHeight / _pdfBaseHeight;
    final left = _overlayOffsetX + pdfRect.x * scaleX * _overlayScaleX;
    final top = _overlayOffsetY + pdfRect.y * scaleY * _overlayScaleY;
    final width = pdfRect.width * scaleX * _overlayScaleX;
    final height = pdfRect.height * scaleY * _overlayScaleY;
    final hitPadding = field.isCheckbox ? 12.0 : 0.0;
    final tapLeft = math.max(0.0, left - hitPadding).toDouble();
    final tapTop = math.max(0.0, top - hitPadding).toDouble();
    final tapWidth = (width + (hitPadding * 2)).toDouble();
    final tapHeight = (height + (hitPadding * 2)).toDouble();
    final value = formData.instance.payload[field.key];
    final interactive = field.type.toLowerCase() != 'hidden';
    final highlighted =
        layoutEditMode ? selectedFieldKey == field.key : interactive;

    if (layoutEditMode) {
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: GestureDetector(
          key: ValueKey('lodging-field-${field.key}'),
          behavior: HitTestBehavior.translucent,
          onTap: () => onSelectField?.call(field.key),
          onPanUpdate: (details) {
            final dx =
                details.delta.dx * _fieldDragSensitivity /
                (scaleX * _overlayScaleX);
            final dy =
                details.delta.dy * _fieldDragSensitivity /
                (scaleY * _overlayScaleY);
            final storedDx =
                _usesLegacyPercentCoordinates ? dx / _pdfBaseWidth * 100 : dx;
            final storedDy =
                _usesLegacyPercentCoordinates ? dy / _pdfBaseHeight * 100 : dy;
            final coordinateWidth =
                _usesLegacyPercentCoordinates ? 100.0 : _pdfBaseWidth;
            final coordinateHeight =
                _usesLegacyPercentCoordinates
                    ? 100.0
                    : _pdfBaseHeight * _pageCount;
            final nextX =
                (field.x + storedDx)
                    .clamp(0.0, coordinateWidth - field.width)
                    .toDouble();
            final nextY =
                (field.y + storedDy)
                    .clamp(0.0, coordinateHeight - field.height)
                    .toDouble();
            onUpdateField?.call(field.copyWith(x: nextX, y: nextY));
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x1A2563EB),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          highlighted
                              ? const Color(0xFFF97316)
                              : const Color(0xFF2563EB),
                      width: highlighted ? 2 : 1.2,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      color: const Color(0xCC0F172A),
                      child: Text(
                        field.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: GestureDetector(
                  key: ValueKey('lodging-field-resize-${field.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelectField?.call(field.key),
                  onPanUpdate: (details) {
                    final dw = details.delta.dx / (scaleX * _overlayScaleX);
                    final dh = details.delta.dy / (scaleY * _overlayScaleY);
                    final storedDw =
                        _usesLegacyPercentCoordinates
                            ? dw / _pdfBaseWidth * 100
                            : dw;
                    final storedDh =
                        _usesLegacyPercentCoordinates
                            ? dh / _pdfBaseHeight * 100
                            : dh;
                    final coordinateWidth =
                        _usesLegacyPercentCoordinates ? 100.0 : _pdfBaseWidth;
                    final coordinateHeight =
                        _usesLegacyPercentCoordinates
                            ? 100.0
                            : _pdfBaseHeight * _pageCount;
                    final minimumSize =
                        _usesLegacyPercentCoordinates ? 1.0 : 10.0;
                    final nextWidth =
                        (field.width + storedDw)
                            .clamp(minimumSize, coordinateWidth - field.x)
                            .toDouble();
                    final nextHeight =
                        (field.height + storedDh)
                            .clamp(minimumSize, coordinateHeight - field.y)
                            .toDouble();
                    onUpdateField?.call(
                      field.copyWith(width: nextWidth, height: nextHeight),
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: tapLeft,
      top: tapTop,
      width: tapWidth,
      height: tapHeight,
      child: GestureDetector(
        key: ValueKey('lodging-field-tap-${field.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? () => onTapField?.call(field) : null,
        child: Stack(
          children: [
            Positioned(
              left: left - tapLeft,
              top: top - tapTop,
              width: width,
              height: height,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _compactFieldKeys.contains(field.key) ? 1 : 4,
                  vertical: _compactFieldKeys.contains(field.key) ? 1 : 2,
                ),
                decoration: BoxDecoration(
                  color:
                      highlighted
                          ? const Color(0x66FFFFFF)
                          : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        highlighted
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFCBD5E1),
                    width: highlighted ? 1.2 : 0.8,
                  ),
                ),
                child: _FieldValueView(field: field, value: value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldValueView extends StatelessWidget {
  const _FieldValueView({required this.field, required this.value});

  final LodgingFormFieldItem field;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (field.isCheckbox) {
      final checked = value == true;
      return LayoutBuilder(
        builder: (context, constraints) {
          final boxSize =
              math
                  .max(
                    8.0,
                    math.min(
                      12.0,
                      math.min(constraints.maxWidth, constraints.maxHeight),
                    ),
                  )
                  .toDouble();
          final iconSize = math.max(6.0, boxSize - 2).toDouble();
          return Center(
            child: Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0F172A), width: 1),
                color: checked ? const Color(0xFF0F172A) : Colors.transparent,
              ),
              child:
                  checked
                      ? Icon(Icons.check, size: iconSize, color: Colors.white)
                      : null,
            ),
          );
        },
      );
    }

    if (field.isSignature) {
      return _SignatureValueView(value: value?.toString() ?? '');
    }

    if (_compactFieldKeys.contains(field.key)) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value?.toString() ?? '',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              height: 1.0,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactText =
            constraints.maxHeight <= 18 || constraints.maxWidth <= 80;
        if (compactText) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value?.toString() ?? '',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value?.toString() ?? '',
            maxLines: field.multiline ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.1,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _SignatureValueView extends StatelessWidget {
  const _SignatureValueView({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final points = _decodeSignature(value);
    if (points.isEmpty) {
      return const Center(
        child: Text(
          '서명',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }
    return CustomPaint(
      key: const ValueKey('lodging-signature-strokes'),
      painter: _SignatureValuePainter(points),
      child: const SizedBox.expand(),
    );
  }

  List<Offset?> _decodeSignature(String encoded) {
    if (encoded.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map((item) {
            if (item == null) return null;
            final point = item as Map<String, dynamic>;
            return Offset(
              (point['x'] as num).toDouble(),
              (point['y'] as num).toDouble(),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

class _SignatureValuePainter extends CustomPainter {
  const _SignatureValuePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 320, size.height / 220);
    final paint =
        Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SignatureValuePainter oldDelegate) =>
      oldDelegate.points != points;
}

class _FallbackTemplatePreview extends StatelessWidget {
  const _FallbackTemplatePreview({required this.formData});

  final LodgingFormData formData;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview Not Ready',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            formData.template.sourceFormat.toUpperCase() == 'PDF_PLACEHOLDER'
                ? 'This region is still using the common MVP placeholder template.'
                : 'The original template preview URL is not available yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
