import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/signature_pad.dart';

/// 숙박확인서 — 숙소 정보 폼 + 대표자 전자 서명 → 저장.
/// 디자인: halftrip-design/lodging-form.html
class LodgingFormScreen extends StatefulWidget {
  const LodgingFormScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<LodgingFormScreen> createState() => _LodgingFormScreenState();
}

class _LodgingFormScreenState extends State<LodgingFormScreen> {
  Future<LodgingFormData>? _future;
  bool _initialized = false;
  bool _saving = false;

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String> _signatureValues = {};
  LodgingFormData? _formData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
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
    for (final field in formData.template.fields) {
      if (field.isSignature) {
        _signatureValues[field.key] = payload[field.key]?.toString() ?? '';
      } else if (field.isCheckbox) {
        _checkboxValues[field.key] = payload[field.key] as bool? ?? false;
      } else {
        final c = _textControllers.putIfAbsent(
            field.key, TextEditingController.new);
        c.text = payload[field.key]?.toString() ?? '';
      }
    }
  }

  Map<String, dynamic> _currentPayload() {
    final source = Map<String, dynamic>.from(
        _formData?.instance.payload ?? const <String, dynamic>{});
    for (final e in _textControllers.entries) {
      source[e.key] = e.value.text.trim();
    }
    for (final e in _checkboxValues.entries) {
      source[e.key] = e.value;
    }
    for (final e in _signatureValues.entries) {
      source[e.key] = e.value;
    }
    return source;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = AppScope.of(context);
    try {
      await controller.runTask(() => controller.repository.saveLodgingForm(
            widget.tripId,
            LodgingFormSaveRequest(
                payload: _currentPayload(), status: 'DRAFT'),
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('숙박확인서를 저장했어요.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장에 실패했어요: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSignature(String key) async {
    final signed = await showSignaturePadDialog(context,
        initialValue: _signatureValues[key] ?? '');
    if (signed == null) return;
    setState(() => _signatureValues[key] = signed);
  }

  String _hint(LodgingFormFieldItem f) => switch (f.key) {
        'business_number' => '123-45-67890',
        'occupancy_count' => '2',
        'payment_amount' => '60000',
        'payment_date' => '2026-06-15',
        'phone_number' || 'traveler_phone_number' => '010-1234-5678',
        _ => f.helperText.isEmpty ? '내용을 입력하세요' : f.helperText,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('숙박확인서')),
      body: FutureBuilder<LodgingFormData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final fields = (_formData ?? snapshot.data!).template.fields;
          final textFields =
              fields.where((f) => !f.isSignature && !f.isCheckbox).toList();
          final sigFields = fields.where((f) => f.isSignature).toList();
          final checkFields = fields.where((f) => f.isCheckbox).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 숙소 정보 폼
              AppCard(
                child: Column(children: [
                  for (var i = 0; i < textFields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _FormField(
                      label: textFields[i].label,
                      child: TextField(
                        controller: _textControllers[textFields[i].key],
                        maxLines: textFields[i].multiline ? 3 : 1,
                        style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink9),
                        decoration: _fieldDeco(_hint(textFields[i])),
                      ),
                    ),
                  ],
                  for (final f in checkFields) ...[
                    const SizedBox(height: 8),
                    _CheckRow(
                      label: f.label,
                      checked: _checkboxValues[f.key] ?? false,
                      onTap: () => setState(() => _checkboxValues[f.key] =
                          !(_checkboxValues[f.key] ?? false)),
                    ),
                  ],
                ]),
              ),

              // 서명
              for (final f in sigFields) ...[
                const SizedBox(height: 14),
                _SignatureCard(
                  label: f.label.isEmpty ? '숙소 대표자 서명' : f.label,
                  signed: (_signatureValues[f.key] ?? '').isNotEmpty,
                  onTap: () => _editSignature(f.key),
                ),
              ],

              const SizedBox(height: 12),
              const _Note('반값여행은 1박 숙박이 필수예요. 숙소 정보를 적고 대표자 서명을 받아 제출해요.'),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.hotel_rounded, size: 18),
          label: const Text('숙박확인서 저장'),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.ink4),
        filled: true,
        fillColor: AppColors.surf,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            borderSide: BorderSide.none),
      );
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink7)),
      const SizedBox(height: 7),
      child,
    ]);
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard(
      {required this.label, required this.signed, required this.onTap});
  final String label;
  final bool signed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.field),
            onTap: onTap,
            child: Container(
              height: 96,
              alignment: Alignment.center,
              child: signed
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: Color(0xFF1B8E4B), size: 28),
                        SizedBox(height: 6),
                        Text('서명 완료 · 다시 서명하려면 탭',
                            style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B8E4B))),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_outlined,
                            color: AppColors.ink4, size: 26),
                        SizedBox(height: 6),
                        Text('여기를 눌러 서명',
                            style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink5)),
                      ],
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(
      {required this.label, required this.checked, required this.onTap});
  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? AppColors.p500 : AppColors.white,
              shape: BoxShape.circle,
              border: checked
                  ? null
                  : Border.all(color: AppColors.gray, width: 1.6),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink9)),
          ),
        ]),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.ink4),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink5)),
        ),
      ]),
    );
  }
}
