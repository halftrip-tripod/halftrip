import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';

/// 영수증 OCR 보정 시트 — "이 정보가 맞나요?"에서 수정하기를 누르면 열린다.
///
/// OCR은 완전하지 않아 금액·결제수단·결제일이 틀릴 수 있다. 여기서 고친 값은
/// 서버에서 분석과 같은 심사를 다시 타므로, 수정했다고 인정 여부가 느슨해지지 않는다.
/// 저장되면 보정된 [ReceiptItem]을 돌려주고, 취소하면 null.
Future<ReceiptItem?> showReceiptCorrectSheet(
  BuildContext context, {
  required int tripId,
  required ReceiptItem receipt,
}) {
  return showModalBottomSheet<ReceiptItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ReceiptCorrectSheet(tripId: tripId, receipt: receipt),
  );
}

class _ReceiptCorrectSheet extends StatefulWidget {
  const _ReceiptCorrectSheet({required this.tripId, required this.receipt});

  final int tripId;
  final ReceiptItem receipt;

  @override
  State<_ReceiptCorrectSheet> createState() => _ReceiptCorrectSheetState();
}

class _ReceiptCorrectSheetState extends State<_ReceiptCorrectSheet> {
  late final TextEditingController _amountController;
  late PaymentType _paymentType;
  DateTime? _paymentDateTime;
  bool _saving = false;

  /// unknown은 "못 읽었다"는 상태지 사용자가 고를 결제수단이 아니다.
  static const _selectableTypes = [
    PaymentType.creditCard,
    PaymentType.checkCard,
    PaymentType.onlinePayment,
    PaymentType.bankTransfer,
    PaymentType.cashReceipt,
    PaymentType.simpleReceipt,
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.receipt.amount?.toString() ?? '');
    _paymentType = widget.receipt.paymentType;
    _paymentDateTime = widget.receipt.paymentDateTime;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _paymentDateTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _paymentDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final receipt = widget.receipt;
    final amountText = _amountController.text.replaceAll(',', '').trim();
    final amount = int.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount <= 0)) {
      _snack('금액은 0보다 큰 숫자로 입력해 주세요.');
      return;
    }

    // 바뀐 필드만 보낸다 — 서버는 null 필드를 기존 값 유지로 처리한다.
    final amountChanged = amount != null && amount != receipt.amount;
    final typeChanged = _paymentType != receipt.paymentType;
    final dateChanged = _paymentDateTime != null &&
        _paymentDateTime != receipt.paymentDateTime;
    if (!amountChanged && !typeChanged && !dateChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    try {
      final corrected = await AppScope.of(context).repository.correctReceipt(
            tripId: widget.tripId,
            receiptId: receipt.id,
            amount: amountChanged ? amount : null,
            paymentType: typeChanged ? _paymentType : null,
            paymentDateTime: dateChanged ? _paymentDateTime : null,
          );
      if (mounted) Navigator.of(context).pop(corrected);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('수정을 저장하지 못했어요: $error');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final dt = _paymentDateTime;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('영수증 정보 수정',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9)),
          const SizedBox(height: 4),
          const Text('AI가 잘못 읽은 값을 고쳐 주세요. 수정한 값으로 인정 여부를 다시 심사해요.',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink5)),
          const SizedBox(height: 18),
          _label('금액'),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              hint: '예: ${won.format(45000)}',
              suffixText: '원',
            ),
          ),
          const SizedBox(height: 14),
          _label('결제수단'),
          DropdownButtonFormField<PaymentType>(
            initialValue:
                _selectableTypes.contains(_paymentType) ? _paymentType : null,
            hint: const Text('결제수단 선택'),
            items: [
              for (final type in _selectableTypes)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _paymentType = value);
            },
            decoration: _fieldDecoration(),
          ),
          const SizedBox(height: 14),
          _label('결제일시'),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dt == null
                    ? '날짜와 시간 선택'
                    : '${dt.year}.${dt.month}.${dt.day} '
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('저장하고 다시 심사받기'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink7)),
      );

  InputDecoration _fieldDecoration({String? hint, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      filled: true,
      fillColor: AppColors.surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
