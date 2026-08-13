import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../core/app_scope.dart';
import '../mock_ui/theme/app_colors.dart';
import '../mock_ui/widgets/ui.dart';
import '../models/app_models.dart';
import '../widgets/lodging_form_preview.dart';
import '../widgets/pdf_embed_view.dart';
import '../widgets/signature_pad.dart';

class LodgingFormScreen extends StatefulWidget {
  const LodgingFormScreen({
    super.key,
    required this.tripId,
    this.editorMode = false,
  });

  final int tripId;
  final bool editorMode;

  @override
  State<LodgingFormScreen> createState() => _LodgingFormScreenState();
}

class _LodgingFormScreenState extends State<LodgingFormScreen> {
  Future<LodgingFormData>? _future;
  bool _initialized = false;
  bool _layoutEditMode = false;
  bool _layoutSaving = false;
  double _previewZoom = 1.5;
  String? _selectedFieldKey;
  // 앱 차원 개인정보 제공 동의 (양식에 동의 필드가 없는 지역용 — 페이로드 미포함).
  bool _appPrivacyAgreed = false;

  final ScrollController _previewHorizontalController = ScrollController();
  final ScrollController _editorVerticalController = ScrollController();
  final Map<String, TextEditingController> _textControllers = {};
  // 분리 전화번호(_mid/_last)를 한 칸에서 입력받기 위한 합본 컨트롤러(페이로드엔 미포함).
  final Map<String, TextEditingController> _phoneCombined = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String> _signatureValues = {};
  LodgingFormData? _formData;

  String _firstSignatureFieldKey() {
    for (final field
        in _formData?.template.fields ?? const <LodgingFormFieldItem>[]) {
      if (field.isSignature) {
        return field.key;
      }
    }
    return 'signature';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = _load();
    _initialized = true;
  }

  @override
  void dispose() {
    _previewHorizontalController.dispose();
    _editorVerticalController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changePreviewZoom(double delta) {
    setState(() {
      _previewZoom = (_previewZoom + delta).clamp(1.0, 2.5).toDouble();
    });
  }

  void _panPreview(DragUpdateDetails details) {
    _moveScrollPosition(_previewHorizontalController, details.delta.dx);
    _moveScrollPosition(_editorVerticalController, details.delta.dy);
  }

  void _moveScrollPosition(ScrollController controller, double dragDelta) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final nextOffset =
        (controller.offset - dragDelta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    controller.jumpTo(nextOffset);
  }

  Future<LodgingFormData> _load() async {
    final repository = AppScope.of(context).repository;
    final formData = await repository.getLodgingFormData(widget.tripId);
    _applyFormData(formData);
    return formData;
  }

  void _applyFormData(LodgingFormData formData) {
    final payload = formData.instance.payload;
    _formData = formData;

    final activeTextKeys = <String>{};
    final activeCheckboxKeys = <String>{};
    final activeSignatureKeys = <String>{};

    for (final field in formData.template.fields) {
      if (field.isSignature) {
        activeSignatureKeys.add(field.key);
        _signatureValues[field.key] = payload[field.key]?.toString() ?? '';
        continue;
      }

      if (field.isCheckbox) {
        activeCheckboxKeys.add(field.key);
        _checkboxValues[field.key] = payload[field.key] as bool? ?? false;
        continue;
      }

      activeTextKeys.add(field.key);
      final controller = _textControllers.putIfAbsent(
        field.key,
        TextEditingController.new,
      );
      controller.text = payload[field.key]?.toString() ?? '';
    }

    final textKeysToRemove =
        _textControllers.keys
            .where((key) => !activeTextKeys.contains(key))
            .toList();
    for (final key in textKeysToRemove) {
      _textControllers.remove(key)?.dispose();
    }

    final checkboxKeysToRemove =
        _checkboxValues.keys
            .where((key) => !activeCheckboxKeys.contains(key))
            .toList();
    for (final key in checkboxKeysToRemove) {
      _checkboxValues.remove(key);
    }

    final signatureKeysToRemove =
        _signatureValues.keys
            .where((key) => !activeSignatureKeys.contains(key))
            .toList();
    for (final key in signatureKeysToRemove) {
      _signatureValues.remove(key);
    }
  }

  Map<String, dynamic> _currentPayload() {
    final source = Map<String, dynamic>.from(
      _formData?.instance.payload ?? const <String, dynamic>{},
    );
    for (final entry in _textControllers.entries) {
      source[entry.key] = entry.value.text.trim();
    }
    for (final entry in _checkboxValues.entries) {
      source[entry.key] = entry.value;
    }
    for (final entry in _signatureValues.entries) {
      source[entry.key] = entry.value;
    }

    final fieldKeys =
        _formData?.template.fields.map((field) => field.key).toSet() ??
        const <String>{};
    void mirrorWhenBlank(String targetKey, String sourceKey) {
      if (!fieldKeys.contains(targetKey) || !fieldKeys.contains(sourceKey)) {
        return;
      }
      if ((source[targetKey]?.toString().trim() ?? '').isEmpty) {
        source[targetKey] = source[sourceKey] ?? '';
      }
    }

    mirrorWhenBlank('lodging_name_bottom', 'lodging_name');
    mirrorWhenBlank('address_bottom', 'address');
    mirrorWhenBlank('confirmation_date_bottom_year', 'confirmation_date_year');
    mirrorWhenBlank(
      'confirmation_date_bottom_month',
      'confirmation_date_month',
    );
    mirrorWhenBlank('confirmation_date_bottom_day', 'confirmation_date_day');
    // 해남처럼 확인란이 둘인 양식에서 아래쪽 확인일을 비워 두면 위쪽 작성일과
    // 같은 날로 본다. 실무에서도 두 날짜를 다르게 적는 일은 거의 없다.
    mirrorWhenBlank('confirmation_date_bottom', 'confirmation_date');
    return source;
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final saved = await controller.runTask(
      () => controller.repository.saveLodgingForm(
        widget.tripId,
        LodgingFormSaveRequest(payload: _currentPayload(), status: 'DRAFT'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _applyFormData(saved);
      _future = Future.value(saved);
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('숙박확인서를 저장했어요. 정산 때 증빙 패키지에 자동으로 묶여요.')));
  }

  Future<void> _downloadPdf() async {
    final controller = AppScope.of(context);
    final saved = await controller.runTask(
      () => controller.repository.saveLodgingForm(
        widget.tripId,
        LodgingFormSaveRequest(payload: _currentPayload(), status: 'DRAFT'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _applyFormData(saved);
      _future = Future.value(saved);
    });
    final path = await controller.runTask(
      () => controller.repository.downloadLodgingFormPdf(widget.tripId),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path)));
  }

  /// 지자체가 전자서명을 인정하는지. false면 출력→실물 서명→업로드로 유도한다.
  bool get _electronicSignatureAllowed =>
      _formData?.template.electronicSignatureAllowed ?? true;

  /// 현재 입력을 저장한 뒤 서버가 렌더한 숙박확인서 PDF 바이트를 가져온다.
  Future<Uint8List?> _saveThenLoadPdfBytes() async {
    final controller = AppScope.of(context);
    final saved = await controller.runTask(
      () => controller.repository.saveLodgingForm(
        widget.tripId,
        LodgingFormSaveRequest(payload: _currentPayload(), status: 'DRAFT'),
      ),
    );
    if (!mounted) return null;
    setState(() {
      _applyFormData(saved);
      _future = Future.value(saved);
    });
    return controller.runTask(
      () => controller.repository.fetchLodgingFormPdfBytes(widget.tripId),
    );
  }

  Future<void> _printPdf() async {
    try {
      final bytes = await _saveThenLoadPdfBytes();
      if (bytes == null || !mounted) return;
      // 안드로이드/iOS 시스템 인쇄 대화상자 — 실제 프린터 전송 + "PDF로 저장" 포함.
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'trip-${widget.tripId}-lodging-form.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인쇄를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await _saveThenLoadPdfBytes();
      if (bytes == null || !mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'trip-${widget.tripId}-lodging-form.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _previewRenderedPdf() async {
    final controller = AppScope.of(context);
    final saved = await controller.runTask(
      () => controller.repository.saveLodgingForm(
        widget.tripId,
        LodgingFormSaveRequest(payload: _currentPayload(), status: 'DRAFT'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _applyFormData(saved);
      _future = Future.value(saved);
    });

    final url = controller.repository.getLodgingFormRenderedPdfUrl(widget.tripId);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 환경에서는 PDF 미리보기를 지원하지 않습니다.')),
      );
      return;
    }
    final separator = url.contains('?') ? '&' : '?';
    final previewUrl =
        '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
    final pageCount = _renderedPdfPageCount(saved);
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text(
                  '미리보기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              backgroundColor: const Color(0xFFF1F5F9),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final previewWidth = math.min(constraints.maxWidth, 900.0);
                  final previewHeight = previewWidth * 1.414 * pageCount;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: previewWidth,
                        child: PdfEmbedView(
                          url: previewUrl,
                          height: previewHeight,
                          pageCount: pageCount,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }

  int _renderedPdfPageCount(LodgingFormData formData) {
    final templateName =
        formData.template.templateName
            .split(RegExp(r'[\\/]'))
            .last
            .toLowerCase();
    return templateName.contains('gangjin') || templateName.contains('yeonggwang')
        ? 2
        : 1;
  }

  Future<void> _editSignature([String? fieldKey]) async {
    if (!_electronicSignatureAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 지역은 전자서명을 인정하지 않아요. 출력해서 실물 서명을 받아 주세요.'),
        ),
      );
      return;
    }
    final resolvedFieldKey = fieldKey ?? _firstSignatureFieldKey();
    final signed = await showSignaturePadDialog(
      context,
      initialValue: _signatureValues[resolvedFieldKey] ?? '',
    );
    if (signed == null) return;
    setState(() {
      _signatureValues[resolvedFieldKey] = signed;
    });
  }

  Future<void> _pickDate(String fieldKey) async {
    final controller = _textControllers.putIfAbsent(
      fieldKey,
      TextEditingController.new,
    );
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text.trim()) ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (picked == null) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() => controller.text = '${picked.year}-$month-$day');
  }

  /// `<base>_year|_month|_day` 형태의 날짜 파트면 base 키를 돌려준다(아니면 null).
  /// 예) payment_date_month → payment_date, confirmation_date_bottom_year → confirmation_date_bottom.
  String? _dateGroupBase(String key) =>
      RegExp(r'^(.*_date(?:_bottom)?)_(?:year|month|day)$').firstMatch(key)?.group(1);

  /// 분리 전화번호 파트(`..phone.._mid`/`_last`, 뒤에 `_bottom` 가능)면 그룹키를 돌려준다(아니면 null).
  /// 예) phone_number_mid → phone_number, applicant_phone_last_bottom → applicant_phone_bottom.
  String? _phoneGroupKey(String key) {
    final m = RegExp(r'^(.*phone.*)_(?:mid|last)(_bottom)?$').firstMatch(key);
    if (m == null) return null;
    return '${m.group(1)}${m.group(2) ?? ''}';
  }

  /// 분리형(mid/last) 전화 그룹에 대응하는 "전체 번호" 렌더 키. 렌더러는 이 키가
  /// 있으면 010을 붙이지 않고 값을 그대로 찍으므로, 유선번호(061-…)가 010으로
  /// 둔갑하는 문제를 막는다. 대응 키가 없으면 null(기존 010 분할 유지 — 휴대전화용).
  String? _phoneFullFieldKey(String base) {
    switch (base) {
      case 'phone_number':
        return 'phone_number';
      case 'traveler_phone':
        return 'traveler_phone_number';
      default:
        return null;
    }
  }

  /// 필드 목록을 위젯으로 그리되, 날짜(연/월/일)·분리 전화번호(가운데/끝자리)는
  /// 각각 캘린더·단일 입력 하나로 묶는다.
  List<Widget> _fieldWidgets(List<LodgingFormFieldItem> fields) {
    final dateBases = <String>{
      for (final f in fields)
        if (_dateGroupBase(f.key) != null) _dateGroupBase(f.key)!,
    };
    final done = <String>{};
    final out = <Widget>[];
    for (final field in fields) {
      final dateBase = _dateGroupBase(field.key);
      if (dateBase != null) {
        // 아래쪽 확인일(_bottom)은 위쪽 값이 자동 복사되므로 따로 그리지 않는다.
        if (dateBase.endsWith('_bottom') &&
            dateBases.contains(
                dateBase.substring(0, dateBase.length - '_bottom'.length))) {
          continue;
        }
        if (!done.add('date:$dateBase')) continue;
        out.add(_dateGroupField(dateBase, fields));
        continue;
      }
      final phoneGroup = _phoneGroupKey(field.key);
      if (phoneGroup != null) {
        if (!done.add('phone:$phoneGroup')) continue;
        out.add(_phoneGroupField(phoneGroup, field));
        continue;
      }
      out.add(_docxInputField(field));
    }
    return out;
  }

  /// 가운데/끝자리로 나뉜 전화번호를 숫자만 넣으면(01040594200) 010-4059-4200으로
  /// 자동 정리해 각 칸에 나눠 저장한다(양식엔 010이 인쇄돼 있어 지역번호는 별도 저장 안 함).
  Widget _phoneGroupField(String groupKey, LodgingFormFieldItem sample) {
    final bottom = groupKey.endsWith('_bottom');
    final base = bottom
        ? groupKey.substring(0, groupKey.length - '_bottom'.length)
        : groupKey;
    final suffix = bottom ? '_bottom' : '';
    final midCtl =
        _textControllers.putIfAbsent('${base}_mid$suffix', TextEditingController.new);
    final lastCtl =
        _textControllers.putIfAbsent('${base}_last$suffix', TextEditingController.new);
    final fullKey = _phoneFullFieldKey(base);
    final combined = _phoneCombined.putIfAbsent(groupKey, () {
      final c = TextEditingController();
      // 저장된 전체 번호가 있으면 그걸 우선(유선번호 보존). 없을 때만 mid/last에
      // 010을 붙여 복원(휴대전화 양식 기존 동작).
      final savedFull = fullKey == null
          ? ''
          : (_formData?.instance.payload[fullKey]?.toString().trim() ?? '');
      if (savedFull.isNotEmpty) {
        c.text = _formatKoreanPhone(savedFull);
      } else {
        final mid = midCtl.text.trim(), last = lastCtl.text.trim();
        if (mid.isNotEmpty || last.isNotEmpty) {
          c.text = _formatKoreanPhone('010$mid$last');
        }
      }
      return c;
    });
    final label =
        sample.label.replaceAll(RegExp(r'\s*(가운데자리|끝자리)\s*$'), '').trim();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      const SizedBox(height: 8),
      TextField(
        controller: combined,
        keyboardType: TextInputType.number,
        inputFormatters: [_KoreanPhoneFormatter()],
        onChanged: (v) {
          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
          final last =
              digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
          final mid = digits.length >= 8
              ? digits.substring(digits.length - 8, digits.length - 4)
              : (digits.length > 4 ? digits.substring(0, digits.length - 4) : '');
          midCtl.text = mid;
          lastCtl.text = last;
          // 렌더러가 우선 읽는 전체 번호 키에 입력값을 그대로 저장(지역번호 보존).
          // 양식에 010이 인쇄돼 있어도 이 값이 있으면 렌더러가 010을 덧붙이지 않는다.
          if (fullKey != null) {
            _textControllers
                .putIfAbsent(fullKey, TextEditingController.new)
                .text = _formatKoreanPhone(digits);
          }
        },
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9),
        decoration: InputDecoration(
          hintText: '숫자만 입력 (예: 01040594200)',
          hintStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink4),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.p500, width: 1.5)),
        ),
      ),
    ]);
  }

  /// 연/월/일을 캘린더 한 번으로 고르는 날짜 입력. 연도 필드가 없는 양식은 월·일만 채운다.
  Widget _dateGroupField(String base, List<LodgingFormFieldItem> fields) {
    final hasYear = fields.any((f) => f.key == '${base}_year');
    final yearCtl = hasYear
        ? _textControllers.putIfAbsent('${base}_year', TextEditingController.new)
        : null;
    final monthCtl =
        _textControllers.putIfAbsent('${base}_month', TextEditingController.new);
    final dayCtl =
        _textControllers.putIfAbsent('${base}_day', TextEditingController.new);
    final label = base.startsWith('payment_date') ? '결제일' : '확인일';

    final y = yearCtl?.text.trim() ?? '';
    final m = monthCtl.text.trim();
    final d = dayCtl.text.trim();
    final filled = m.isNotEmpty && d.isNotEmpty;
    final shown = !filled
        ? ''
        : '${hasYear && y.isNotEmpty ? '$y년 ' : ''}$m월 $d일';

    Future<void> pick() async {
      final now = DateTime.now();
      final initial = DateTime(
        int.tryParse(y) ?? now.year,
        int.tryParse(m) ?? now.month,
        int.tryParse(d) ?? now.day,
      );
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2, 12, 31),
      );
      if (picked == null) return;
      setState(() {
        yearCtl?.text = picked.year.toString();
        monthCtl.text = picked.month.toString();
        dayCtl.text = picked.day.toString();
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: pick,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                shown.isEmpty ? '날짜를 선택하세요.' : shown,
                style: TextStyle(
                    fontSize: shown.isEmpty ? 14 : 15,
                    fontWeight: shown.isEmpty ? FontWeight.w500 : FontWeight.w600,
                    color: shown.isEmpty ? AppColors.ink4 : AppColors.ink9),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.ink4),
          ]),
        ),
      ),
    ]);
  }

  String _fieldHint(LodgingFormFieldItem field) {
    if (field.isDate) {
      return '날짜를 선택하세요.';
    }
    return switch (field.key) {
      'business_number' => '123-45-67890',
      'occupancy_count' => '2',
      'payment_amount' => '180000',
      'payment_date' => '2026-05-03',
      'phone_number' => '010-1234-5678',
      'traveler_phone_number' => '010-1234-5678',
      _ => field.helperText.isEmpty ? '내용을 입력하세요.' : field.helperText,
    };
  }

  Future<void> _editFieldFromPreview(LodgingFormFieldItem field) async {
    if (field.isSignature) {
      await _editSignature(field.key);
      return;
    }
    if (field.isCheckbox) {
      setState(() {
        _checkboxValues[field.key] = !(_checkboxValues[field.key] ?? false);
      });
      return;
    }
    if (field.isDate) {
      await _pickDate(field.key);
      return;
    }

    final controller = _textControllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: field.multiline ? 3 : 1,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _fieldHint(field),
                  helperText:
                      field.helperText.isEmpty ? null : field.helperText,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateLayoutField(LodgingFormFieldItem updatedField) {
    final formData = _formData;
    if (formData == null) return;

    final fields = formData.template.fields
        .map((field) => field.key == updatedField.key ? updatedField : field)
        .toList(growable: false);
    setState(() {
      _selectedFieldKey = updatedField.key;
      _formData = LodgingFormData(
        tripId: formData.tripId,
        regionName: formData.regionName,
        template: formData.template.copyWith(fields: fields),
        instance: formData.instance,
        todos: formData.todos,
      );
    });
  }

  Future<void> _saveLayout() async {
    final formData = _formData;
    if (formData == null || _layoutSaving) return;

    setState(() => _layoutSaving = true);
    final controller = AppScope.of(context);
    try {
      final saved = await controller.runTask(
        () => controller.repository.saveLodgingFormTemplateLayout(
          widget.tripId,
          formData.template.fields,
        ),
      );
      if (!mounted) return;
      setState(() {
        _applyFormData(saved);
        _future = Future.value(saved);
        _layoutEditMode = false;
        _selectedFieldKey = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필드 위치와 크기를 저장했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('필드 배치 저장에 실패했습니다: $error')));
    } finally {
      if (mounted) setState(() => _layoutSaving = false);
    }
  }

  Widget _buildLoadError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36),
            const SizedBox(height: 12),
            Text('숙박확인서를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  // ── DOCX 입력 화면 (docs 시안: 섹션 그룹 + 동의/미동의 세그먼트 + 하단 버튼 4개) ──

  /// _currentPayload가 상단 값으로 자동 미러링하는 키 — 입력칸으로 노출하지 않는다.
  static const _mirroredBottomKeys = {
    'lodging_name_bottom',
    'address_bottom',
    'confirmation_date_bottom',
    'confirmation_date_bottom_year',
    'confirmation_date_bottom_month',
    'confirmation_date_bottom_day',
  };

  /// 필드 키 → 섹션 인덱스 (0 신청자 · 1 숙박업소 · 2 이용내역 · 3 확인/서명).
  int _sectionOf(LodgingFormFieldItem field) {
    final k = field.key;
    if (field.isSignature ||
        k.startsWith('agreed_') ||
        k.startsWith('confirmation_date') ||
        k == 'lodging_verified') {
      return 3;
    }
    if (k.startsWith('payment_') || k == 'occupancy_count') return 2;
    if (k.startsWith('traveler_') ||
        k.startsWith('applicant_') ||
        k == 'region_name' ||
        k == 'trip_date_range' ||
        k == 'residence') {
      return 0;
    }
    return 1;
  }

  /// 동의 항목 안내 문구 (실제 지자체 양식 조항 기반).
  String? _consentSentence(String baseKey) => switch (baseKey) {
        'agreed_stay_proof' =>
          '부정수급 방지를 위해 지자체에서 요청 시 카드 또는 기타 결제방식의 숙박 취소내역을 제공하는 데 동의합니다.',
        'agreed_personal_info' => '반값여행 정산 심사를 위해 위 정보를 지자체에 제공하는 데 동의합니다.',
        'agreed_user_match' => '여행 신청자와 결제자 정보가 다를 경우 지원금이 지급되지 않음을 확인했습니다.',
        _ => null,
      };

  Widget _buildDocxEditor(LodgingFormData formData) {
    final fieldsByKey = <String, LodgingFormFieldItem>{};
    for (final field in formData.template.fields) {
      if (field.editable && !_mirroredBottomKeys.contains(field.key)) {
        fieldsByKey.putIfAbsent(field.key, () => field);
      }
    }

    final sections = List.generate(4, (_) => <LodgingFormFieldItem>[]);
    for (final field in fieldsByKey.values) {
      sections[_sectionOf(field)].add(field);
    }

    return DetailScaffold(
      title: '${formData.regionName} 숙박확인서',
      closeIcon: widget.editorMode,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 36),
      children: [
        if (!_electronicSignatureAllowed) _buildPhysicalSignatureNotice(),
        if (sections[0].isNotEmpty) _section('신청자 정보', AppCard(child: _fieldColumn(sections[0]))),
        if (sections[1].isNotEmpty) _section('숙박업소 정보', AppCard(child: _fieldColumn(sections[1]))),
        if (sections[2].isNotEmpty) _section('숙박 이용내역', AppCard(child: _usageColumn(sections[2]))),
        _section('확인 및 서명', Column(children: _confirmChildren(sections[3]))),
        const NoteRow('전자서명 불인정 지역은 인쇄 후 실물 서명을 받아 올려 주세요.'),
        _buildBottomButtons(),
      ],
    );
  }

  /// 섹션 제목이 자기 카드에 붙도록 한 덩어리로 묶는다.
  Widget _section(String title, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 2), child: SectionTitle(title)),
      const SizedBox(height: 12),
      child,
    ]);
  }

  Widget _fieldColumn(List<LodgingFormFieldItem> fields) {
    final widgets = _fieldWidgets(fields);
    return Column(children: [
      for (var i = 0; i < widgets.length; i++) ...[
        if (i > 0) const SizedBox(height: 18),
        widgets[i],
      ],
    ]);
  }

  /// 이용내역 — 결제수단 체크박스 무리는 칩 그룹으로 묶어서 그린다.
  Widget _usageColumn(List<LodgingFormFieldItem> fields) {
    final methods = fields
        .where((f) => f.key.startsWith('payment_method_') && f.isCheckbox)
        .toList(growable: false);
    final otherText =
        fields.where((f) => f.key == 'payment_method_other_text').toList(growable: false);
    final rest = fields
        .where((f) => !f.key.startsWith('payment_method_'))
        .toList(growable: false);

    final showOtherText = otherText.isNotEmpty &&
        (_checkboxValues['payment_method_other'] ?? false);

    final restWidgets = _fieldWidgets(rest);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < restWidgets.length; i++) ...[
        if (i > 0) const SizedBox(height: 18),
        restWidgets[i],
      ],
      if (methods.isNotEmpty) ...[
        if (rest.isNotEmpty) const SizedBox(height: 18),
        const Text('결제 수단',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in methods) _methodChip(m, methods),
        ]),
        if (showOtherText) ...[
          const SizedBox(height: 14),
          _docxInputField(otherText.first),
        ],
      ],
    ]);
  }

  Widget _methodChip(LodgingFormFieldItem field, List<LodgingFormFieldItem> all) {
    final on = _checkboxValues[field.key] ?? false;
    return GestureDetector(
      onTap: () => setState(() {
        // 결제수단은 하나만 — 선택 시 나머지는 해제.
        for (final m in all) {
          _checkboxValues[m.key] = m.key == field.key ? !on : false;
        }
      }),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.p50 : AppColors.surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? AppColors.p500 : AppColors.line, width: 1.5),
        ),
        child: Text(field.label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: on ? AppColors.p600 : AppColors.ink5)),
      ),
    );
  }

  /// 확인 및 서명 — 동의쌍(_yes/_no)은 세그먼트, 단일 체크는 체크 카드, 서명은 서명 카드.
  List<Widget> _confirmChildren(List<LodgingFormFieldItem> fields) {
    final byKey = {for (final f in fields) f.key: f};
    final used = <String>{};
    final children = <Widget>[];

    void add(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(w);
    }

    // 양식에 개인정보 동의 항목이 없으면 앱 차원의 동의 행을 먼저 보여준다.
    final hasPrivacyField = byKey.keys.any((k) => k.startsWith('agreed_personal_info'));
    if (!hasPrivacyField) {
      add(_privacyCheckCard());
    }

    final leftovers = <LodgingFormFieldItem>[];
    for (final field in fields) {
      if (used.contains(field.key)) continue;

      if (field.isCheckbox && field.key.endsWith('_yes')) {
        final base = field.key.substring(0, field.key.length - 4);
        final no = byKey['${base}_no'];
        if (no != null) {
          used.addAll([field.key, no.key]);
          add(_consentSegment(base, field, no));
          continue;
        }
      }
      if (field.isCheckbox && field.key.endsWith('_no')) {
        final base = field.key.substring(0, field.key.length - 3);
        if (byKey.containsKey('${base}_yes')) continue; // 쌍에서 처리됨
      }

      if (field.isCheckbox) {
        used.add(field.key);
        add(_checkCard(field));
        continue;
      }
      if (field.isSignature) {
        used.add(field.key);
        add(_signCard(field));
        continue;
      }
      leftovers.add(field); // 작성일 등 텍스트/날짜
    }
    if (leftovers.isNotEmpty) {
      add(AppCard(child: _fieldColumn(leftovers)));
    }
    return children;
  }

  /// 앱 차원 개인정보 제공 동의 (양식에 해당 필드가 없는 지역용 · 페이로드 미포함).
  Widget _privacyCheckCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _appPrivacyAgreed = !_appPrivacyAgreed),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            _checkBox(_appPrivacyAgreed),
            const SizedBox(width: 12),
          ]),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _appPrivacyAgreed = !_appPrivacyAgreed),
            behavior: HitTestBehavior.opaque,
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('개인정보 제공 동의',
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              SizedBox(height: 3),
              Text('제공 항목·활용 목적·보관 기간 확인',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showPrivacySheet,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('보기',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.p600)),
              Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.p600),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _checkBox(bool on) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? AppColors.p500 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: on ? AppColors.p500 : AppColors.line, width: 2),
      ),
      child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }

  Widget _checkCard(LodgingFormFieldItem field) {
    final on = _checkboxValues[field.key] ?? false;
    final sentence = _consentSentence(field.key) ??
        (field.helperText.isEmpty ? null : field.helperText);
    final isPrivacy = field.key.startsWith('agreed_personal_info');
    return GestureDetector(
      onTap: () => setState(() => _checkboxValues[field.key] = !on),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.soft,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _checkBox(on),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(field.label,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              if (sentence != null) ...[
                const SizedBox(height: 3),
                Text(sentence,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink5,
                        height: 1.5)),
              ],
            ]),
          ),
          if (isPrivacy) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showPrivacySheet,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('보기',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.p600)),
                  Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.p600),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  /// 양식의 □동의 □미동의 쌍 → 문구 + [동의|미동의] 세그먼트.
  Widget _consentSegment(
      String baseKey, LodgingFormFieldItem yes, LodgingFormFieldItem no) {
    final agreed = _checkboxValues[yes.key] ?? false;
    final declined = _checkboxValues[no.key] ?? false;
    final sentence = _consentSentence(baseKey) ?? yes.label;
    final isPrivacy = baseKey == 'agreed_personal_info';

    Widget option(String label, bool on, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.p50 : AppColors.surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? AppColors.p500 : AppColors.line, width: 1.5),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: on ? AppColors.p600 : AppColors.ink5)),
          ),
        ),
      );
    }

    void select(bool agree) => setState(() {
          _checkboxValues[yes.key] = agree;
          _checkboxValues[no.key] = !agree;
        });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(sentence,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink7,
                    height: 1.6)),
          ),
          if (isPrivacy) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showPrivacySheet,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('보기',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.p600)),
                  Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.p600),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 13),
        Row(children: [
          option('동의', agreed, () => select(true)),
          const SizedBox(width: 8),
          option('미동의', declined, () => select(false)),
        ]),
      ]),
    );
  }

  /// 서명 카드 (목업 S2-7): 빈 상태 = "여기를 눌러 서명" 박스, 서명 후 = 서명 미리보기 + 다시 서명.
  Widget _signCard(LodgingFormFieldItem field) {
    final value = _signatureValues[field.key] ?? '';
    final hasSignature = value.isNotEmpty;

    Widget boxChild;
    if (!_electronicSignatureAllowed) {
      boxChild = const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.edit_document, size: 26, color: AppColors.warning),
        SizedBox(height: 6),
        Text('출력 후 실물 서명·인장이 필요한 지역이에요',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]);
    } else if (!hasSignature) {
      boxChild = const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.draw_rounded, size: 26, color: AppColors.ink4),
        SizedBox(height: 6),
        Text('여기를 눌러 서명',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]);
    } else {
      boxChild = Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CustomPaint(painter: _SignaturePreviewPainter(value)),
          ),
        ),
        const Positioned(
          right: 10,
          bottom: 8,
          child: Text('다시 서명',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink5,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.ink5)),
        ),
      ]);
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.label,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.ink9,
                letterSpacing: -.3)),
        const SizedBox(height: 11),
        GestureDetector(
          onTap: () => _editSignature(field.key),
          child: Container(
            height: 110,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: boxChild,
          ),
        ),
      ]),
    );
  }

  Future<void> _showPrivacySheet() async {
    Widget row(String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink7,
                  height: 1.55)),
        ]),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('개인정보 제공 안내',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9)),
              const SizedBox(height: 16),
              row('제공 항목', '신청자 이름·연락처, 거주지, 여행 기간, 숙박업소·이용 금액 등 숙박확인서 기재 정보'),
              row('제공받는 자', '여행 지역 지자체 (반값여행 주관 시·군)'),
              row('활용 목적', '반값여행(지역사랑 휴가지원) 환급 심사 및 정산 증빙 확인'),
              row('보관 기간', '사업 정산 완료 후 관계 법령에 따른 보존 기간까지'),
              const SizedBox(height: 4),
              Row(children: [
                PrimaryButton('확인', onTap: () => Navigator.of(sheetContext).pop()),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    Widget whiteButton(String label, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.soft,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 19, color: AppColors.ink7),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink7)),
            ]),
          ),
        ),
      );
    }

    return Column(children: [
      GestureDetector(
        onTap: _previewRenderedPdf,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.description_outlined, size: 17, color: AppColors.p600),
          SizedBox(width: 6),
          Text('미리보기',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.p600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.p600)),
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [
        whiteButton('PDF 저장', Icons.download_rounded, _downloadPdf),
        const SizedBox(width: 10),
        whiteButton('공유', Icons.ios_share_rounded, _sharePdf),
        const SizedBox(width: 10),
        whiteButton('인쇄', Icons.print_outlined, _printPdf),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        PrimaryButton('숙박확인서 저장', icon: Icons.bed_outlined, onTap: _save),
      ]),
    ]);
  }

  Widget _buildPhysicalSignatureNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이 지역은 전자서명을 인정하지 않아요',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '내용을 채운 뒤 ①인쇄(또는 PDF 저장) → ②숙박업소에서 대표자 실물 서명·인장 → '
            '③서명받은 서류를 촬영해 증빙으로 올려 주세요.',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: AppColors.ink7.withValues(alpha: .9)),
          ),
        ],
      ),
    );
  }

  /// 목업 스타일 입력칸 — 라벨 위 + 흰 라운드 인풋. 전화·숫자 필드는 키보드/포맷터 자동.
  Widget _docxInputField(LodgingFormFieldItem field) {
    // 섹션 0~2에 섞여 들어온 체크박스·서명도 안전하게 처리.
    if (field.isCheckbox) return _checkCard(field);
    if (field.isSignature) return _signCard(field);

    final controller = _textControllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );

    final key = field.key;
    final isFullPhone = key.contains('phone') &&
        !key.contains('_mid') &&
        !key.contains('_last');
    final isDigitsOnly = key.contains('_mid') ||
        key.contains('_last') ||
        key.endsWith('_year') ||
        key.endsWith('_month') ||
        key.endsWith('_day') ||
        key == 'occupancy_count' ||
        key == 'payment_amount';
    final isBusinessNumber = key == 'business_number';

    final formatters = <TextInputFormatter>[
      if (isFullPhone) _KoreanPhoneFormatter(),
      if (isBusinessNumber) _BusinessNumberFormatter(),
      if (isDigitsOnly) FilteringTextInputFormatter.digitsOnly,
    ];
    final keyboardType = (isFullPhone || isDigitsOnly || isBusinessNumber)
        ? TextInputType.number
        : (field.multiline ? TextInputType.multiline : TextInputType.text);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(field.label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        readOnly: field.isDate,
        onTap: field.isDate ? () => _pickDate(field.key) : null,
        minLines: field.multiline ? 2 : 1,
        maxLines: field.multiline ? 4 : 1,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9),
        decoration: InputDecoration(
          hintText: _fieldHint(field),
          hintStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink4),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: field.isDate
              ? const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.ink4)
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.p500, width: 1.5)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // 진입 즉시 입력 화면 (별도 런처 화면 없음).
    return FutureBuilder<LodgingFormData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return DetailScaffold(
              title: '숙박확인서 작성',
              closeIcon: true,
              children: [_buildLoadError(snapshot.error)],
            );
          }
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: AppColors.bg,
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final formData = _formData ?? snapshot.data!;
          if (formData.template.sourceFormat.toUpperCase() == 'DOCX') {
            return _buildDocxEditor(formData);
          }
          // PDF 오버레이 편집 (필드 위치 조정 모드)은 기존 화면 유지.
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              title: Text('${formData.regionName} 숙박확인서',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'PDF 내려받기',
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(child: _buildPdfOverlayEditor(formData)),
          );
        },
      );
  }

  /// 기존 PDF 오버레이 편집 화면 — 필드 위치·크기 조정과 캔버스 줌을 지원한다.
  Widget _buildPdfOverlayEditor(LodgingFormData formData) {
    final controller = AppScope.of(context);
    final previewData = LodgingFormData(
          tripId: formData.tripId,
          regionName: formData.regionName,
          template: formData.template,
          instance: LodgingFormInstanceItem(
            instanceId: formData.instance.instanceId,
            status: formData.instance.status,
            payload: _currentPayload(),
            lastSavedAt: formData.instance.lastSavedAt,
            renderedPdfFileName: formData.instance.renderedPdfFileName,
          ),
          todos: formData.todos,
        );
        final templatePdfUrl = controller.repository
            .getLodgingFormTemplatePreviewUrl(widget.tripId);
        final canEditLayout =
            formData.template.sourceFormat.toUpperCase() != 'PDF_PLACEHOLDER' &&
            templatePdfUrl != null &&
            templatePdfUrl.isNotEmpty;

        return ListView(
          controller: _editorVerticalController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (canEditLayout) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      _layoutEditMode ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        _layoutEditMode
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFD8DEE8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF 필드 편집',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _layoutEditMode
                                    ? '박스를 끌어 이동하고 우하단 핸들로 크기를 조절하세요.'
                                    : '박스를 눌러 값을 입력하거나 필드 위치를 조정할 수 있어요.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _layoutSaving
                                  ? null
                                  : () => setState(() {
                                    _layoutEditMode = !_layoutEditMode;
                                    _selectedFieldKey = null;
                                  }),
                          icon: Icon(
                            _layoutEditMode
                                ? Icons.close_rounded
                                : Icons.open_with_rounded,
                            size: 18,
                          ),
                          label: Text(_layoutEditMode ? '취소' : '위치 편집'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.zoom_in_map_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          '미리보기 크기',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '축소',
                          onPressed:
                              _previewZoom <= 1.0
                                  ? null
                                  : () => _changePreviewZoom(-0.25),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${(_previewZoom * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: '확대',
                          onPressed:
                              _previewZoom >= 2.5
                                  ? null
                                  : () => _changePreviewZoom(0.25),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _previewZoom = 1.0),
                          child: const Text('화면 맞춤'),
                        ),
                      ],
                    ),
                    if (_layoutEditMode) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _layoutSaving ? null : _saveLayout,
                          icon:
                              _layoutSaving
                                  ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save_outlined, size: 18),
                          label: const Text('필드 배치 저장'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasWidth = math.min(
                  1400.0,
                  math.max(
                    constraints.maxWidth,
                    constraints.maxWidth * _previewZoom,
                  ),
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _panPreview,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Scrollbar(
                      controller: _previewHorizontalController,
                      thumbVisibility: _previewZoom > 1.0,
                      interactive: true,
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _previewHorizontalController,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: canvasWidth,
                          child: LodgingFormPreview(
                            formData: previewData,
                            onTapSignature: _editSignature,
                            templatePdfUrl: templatePdfUrl,
                            maxPreviewWidth: canvasWidth,
                            onTapField:
                                _layoutEditMode ? null : _editFieldFromPreview,
                            layoutEditMode: _layoutEditMode,
                            selectedFieldKey: _selectedFieldKey,
                            onSelectField:
                                (key) =>
                                    setState(() => _selectedFieldKey = key),
                            onUpdateField: _updateLayoutField,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              label: const Text(
                'PDF 내려받기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
  }
}

/// 저장된 서명(JSON 좌표 리스트)을 박스 크기에 맞춰 축소해 그리는 미리보기 페인터.
class _SignaturePreviewPainter extends CustomPainter {
  _SignaturePreviewPainter(String encoded) : points = _decode(encoded);

  final List<Offset?> points;

  static List<Offset?> _decode(String value) {
    try {
      final list = jsonDecode(value) as List<dynamic>;
      return list.map((item) {
        if (item == null) return null;
        final map = item as Map<String, dynamic>;
        return Offset((map['x'] as num).toDouble(), (map['y'] as num).toDouble());
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = points.whereType<Offset>().toList();
    if (drawn.length < 2) return;

    // 서명 획의 실제 범위를 구해 박스 안에 맞춘다 (비율 유지).
    var minX = drawn.first.dx, maxX = drawn.first.dx;
    var minY = drawn.first.dy, maxY = drawn.first.dy;
    for (final p in drawn) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final w = math.max(maxX - minX, 1.0);
    final h = math.max(maxY - minY, 1.0);
    final scale = math.min(size.width / w, size.height / h).clamp(0.0, 1.5);
    final dx = (size.width - w * scale) / 2 - minX * scale;
    final dy = (size.height - h * scale) / 2 - minY * scale;

    final paint = Paint()
      ..color = AppColors.ink9
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(
          Offset(current.dx * scale + dx, current.dy * scale + dy),
          Offset(next.dx * scale + dx, next.dy * scale + dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePreviewPainter oldDelegate) =>
      oldDelegate.points != points;
}

/// 숫자만 입력해도 010-1234-5678 형태로 하이픈을 자동 삽입한다 (02 지역번호 대응).
/// 숫자열을 한국 전화번호 형태(010-1234-5678 / 02-123-4567)로 하이픈 삽입.
String _formatKoreanPhone(String raw) {
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('02')) {
    if (d.length <= 2) return d;
    if (d.length <= 5) return '${d.substring(0, 2)}-${d.substring(2)}';
    if (d.length <= 9) {
      return '${d.substring(0, 2)}-${d.substring(2, d.length - 4)}-${d.substring(d.length - 4)}';
    }
    return '${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6, 10)}';
  }
  if (d.length <= 3) return d;
  if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
  if (d.length <= 10) {
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
  }
  return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, math.min(11, d.length))}';
}

class _KoreanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = _formatKoreanPhone(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 사업자등록번호 123-45-67890 자동 하이픈.
class _BusinessNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String text;
    if (d.length <= 3) {
      text = d;
    } else if (d.length <= 5) {
      text = '${d.substring(0, 3)}-${d.substring(3)}';
    } else {
      text = '${d.substring(0, 3)}-${d.substring(3, 5)}-${d.substring(5, math.min(10, d.length))}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
