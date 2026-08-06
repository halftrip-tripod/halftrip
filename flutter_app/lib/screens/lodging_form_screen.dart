import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
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

  final ScrollController _previewHorizontalController = ScrollController();
  final ScrollController _editorVerticalController = ScrollController();
  final Map<String, TextEditingController> _textControllers = {};
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
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
                  '작성 결과 미리보기',
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

  Future<void> _openPdfEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (context) =>
                LodgingFormScreen(tripId: widget.tripId, editorMode: true),
      ),
    );
    if (!mounted) return;
    setState(() => _future = _load());
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

  Widget _buildPdfLauncher(LodgingFormData formData) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${formData.regionName} 숙박확인서',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formData.template.sourceFormat.toUpperCase() == 'DOCX'
                    ? '이름, 주소, 날짜를 입력하면 원본 문서 표 안에 자동으로 반영돼요.'
                    : '전체 화면에서 PDF 위 입력칸을 작성하고, 필드 위치와 크기를 직접 조정할 수 있어요.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openPdfEditor,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    formData.template.sourceFormat.toUpperCase() == 'DOCX'
                        ? '숙박확인서 입력하기'
                        : 'PDF 작성',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocxEditor(LodgingFormData formData) {
    final fieldsByKey = <String, LodgingFormFieldItem>{};
    for (final field in formData.template.fields) {
      if (field.editable) {
        fieldsByKey.putIfAbsent(field.key, () => field);
      }
    }
    final fields = fieldsByKey.values.toList(growable: false);

    return ListView(
      controller: _editorVerticalController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Text(
                    '문서 입력',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '입력한 내용은 지역 원본 DOCX의 표와 서명란에 자동 배치됩니다. 위치와 크기를 맞출 필요가 없습니다.',
                style: TextStyle(height: 1.5, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...fields.map(_buildDocxField),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _previewRenderedPdf,
          icon: const Icon(Icons.preview_outlined),
          label: const Text('작성 결과 미리보기'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFF93C5FD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF 받기'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocxField(LodgingFormFieldItem field) {
    if (field.isCheckbox) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: CheckboxListTile(
          value: _checkboxValues[field.key] ?? false,
          onChanged: (value) {
            setState(() => _checkboxValues[field.key] = value ?? false);
          },
          title: Text(
            field.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: field.helperText.isEmpty ? null : Text(field.helperText),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF2563EB),
        ),
      );
    }

    if (field.isSignature) {
      final hasSignature = (_signatureValues[field.key] ?? '').isNotEmpty;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasSignature ? '서명이 입력되었습니다.' : '버튼을 눌러 직접 서명해 주세요.',
                    style: TextStyle(
                      color:
                          hasSignature
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: FilledButton.tonalIcon(
                onPressed: () => _editSignature(field.key),
                icon: Icon(
                  hasSignature ? Icons.edit_rounded : Icons.draw_rounded,
                ),
                label: Text(hasSignature ? '다시 서명' : '서명'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      );
    }

    final controller = _textControllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: field.isDate,
        onTap: field.isDate ? () => _pickDate(field.key) : null,
        minLines: field.multiline ? 2 : 1,
        maxLines: field.multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: _fieldHint(field),
          suffixIcon:
              field.isDate
                  ? IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, size: 20),
                    onPressed: () => _pickDate(field.key),
                  )
                  : null,
          helperText: field.helperText.isEmpty ? null : field.helperText,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final content = FutureBuilder<LodgingFormData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildLoadError(snapshot.error);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final formData = _formData ?? snapshot.data!;
        if (!widget.editorMode) {
          return _buildPdfLauncher(formData);
        }
        if (formData.template.sourceFormat.toUpperCase() == 'DOCX') {
          return _buildDocxEditor(formData);
        }
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
      },
    );

    if (widget.editorMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            '숙박확인서 작성',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
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
        body: SafeArea(child: content),
      );
    }

    return AppShell(
      title: '숙박확인서',
      modeName: controller.modeName,
      child: content,
    );
  }
}
