import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../repositories/travel_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import 'receipt_correct_sheet.dart';

/// 영수증 OCR — 사진 → 결제수단·금액·일시 인식 → 인정 여부 → 누적 소비 추적.
/// 디자인: halftrip-design/receipt-ocr.html
class ReceiptEvidenceScreen extends StatefulWidget {
  const ReceiptEvidenceScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<ReceiptEvidenceScreen> createState() => _ReceiptEvidenceScreenState();
}

class _ReceiptEvidenceScreenState extends State<ReceiptEvidenceScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  bool _uploading = false;

  Uint8List? _draftPreviewBytes;
  ReceiptItem? _draftReceipt;
  UploadedFileItem? _draftUploadedFile;

  final Map<int, Uint8List> _savedPreviewBytesByFileId = {};

  /// 이 지역이 인정하는 결제수단. 지역마다 달라서 화면에 고정 문구를 쓰면
  /// 지역 상세("결제 수단")와 어긋난다.
  List<String> _acceptedPaymentMethods = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
  }

  Future<TripDetail> _load() async {
    final repository = AppScope.of(context).repository;
    final detail = await repository.getTripDetail(widget.tripId);
    await _loadAcceptedPaymentMethods(repository, detail.trip.regionId);
    await _hydratePreviews(detail);
    return detail;
  }

  Future<void> _loadAcceptedPaymentMethods(
      TravelRepository repository, int regionId) async {
    try {
      final region = await repository.getRegionDetail(regionId,
          includeMerchants: false);
      _acceptedPaymentMethods = region.region.paymentMethods;
    } catch (_) {
      // 결제수단을 못 받아도 영수증 업로드 자체는 막지 않는다.
      _acceptedPaymentMethods = const [];
    }
  }

  Future<void> _hydratePreviews(TripDetail detail) async {
    final repository = AppScope.of(context).repository;
    final receiptFileIds = detail.receipts.map((r) => r.uploadedFileId).toSet();
    final files = detail.uploadedFiles.where((f) =>
        receiptFileIds.contains(f.id) &&
        f.fileCategory == FileCategory.receiptImage &&
        !_savedPreviewBytesByFileId.containsKey(f.id));
    for (final f in files) {
      try {
        _savedPreviewBytesByFileId[f.id] = await repository
            .downloadUploadedFileBytes(tripId: widget.tripId, uploadedFileId: f.id);
      } catch (_) {/* ignore */}
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await AppScope.of(context).refreshTrips();
  }

  Future<void> _pickAndAnalyze() async {
    final repository = AppScope.of(context).repository;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.single;
    if (selected.bytes == null || selected.bytes!.isEmpty) {
      if (mounted) _snack('이미지 파일을 읽지 못했어요. 다시 시도해 주세요.');
      return;
    }

    setState(() {
      _uploading = true;
      _draftPreviewBytes = selected.bytes;
    });
    try {
      final uploaded = await repository.uploadFile(
        tripId: widget.tripId,
        category: FileCategory.receiptImage,
        file: UploadBinary(
          fileName: selected.name,
          bytes: selected.bytes!,
          mimeType: _guessMime(selected.extension),
        ),
      );
      final receipt = await repository.analyzeReceipt(
        tripId: widget.tripId,
        uploadedFileId: uploaded.id,
        usageScope: ReceiptUsageScope.general,
      );
      if (!mounted) return;
      setState(() {
        _draftUploadedFile = uploaded;
        _draftReceipt = receipt;
      });
    } catch (error) {
      if (mounted) _snack('영수증 분석에 실패했어요: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _commitDraft() async {
    final file = _draftUploadedFile;
    final bytes = _draftPreviewBytes;
    if (_draftReceipt == null || file == null) return;
    if (bytes != null) _savedPreviewBytesByFileId[file.id] = bytes;
    setState(() {
      _draftReceipt = null;
      _draftUploadedFile = null;
      _draftPreviewBytes = null;
    });
    await _reload();
    if (mounted) _snack('영수증을 추가했어요.');
  }

  /// 방금 읽은 OCR 결과를 등록 전에 바로잡는다.
  Future<void> _editDraft() async {
    final draft = _draftReceipt;
    if (draft == null) return;
    final corrected = await showReceiptCorrectSheet(
      context,
      tripId: widget.tripId,
      receipt: draft,
    );
    if (corrected != null && mounted) {
      setState(() => _draftReceipt = corrected);
    }
  }

  /// 이미 등록한 영수증도 나중에 오독을 발견하면 고칠 수 있어야 한다.
  Future<void> _editSaved(ReceiptItem receipt) async {
    final corrected = await showReceiptCorrectSheet(
      context,
      tripId: widget.tripId,
      receipt: receipt,
    );
    if (corrected != null && mounted) {
      await _reload();
      _snack('영수증 정보를 수정했어요. 인정 여부도 다시 심사했어요.');
    }
  }

  Future<void> _deleteReceipt(int fileId) async {
    await AppScope.of(context)
        .repository
        .deleteUploadedFile(tripId: widget.tripId, uploadedFileId: fileId);
    _savedPreviewBytesByFileId.remove(fileId);
    await _reload();
  }

  String _guessMime(String? ext) => switch ((ext ?? '').toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('영수증 인증')),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          final spent = detail.trip.totalSpentAmount;
          final goal = detail.trip.refundConditionAmount;
          final draft = _draftReceipt;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 누적 소비
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Text('누적 소비',
                          style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink7)),
                      const Spacer(),
                      Text('${_man(spent)} / ${_man(goal)}',
                          style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink9)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: goal > 0 ? (spent / goal).clamp(0.0, 1.0) : 0.0,
                        minHeight: 8,
                        backgroundColor: AppColors.track,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.p500),
                      ),
                    ),
                    if (spent >= goal && goal > 0) ...[
                      const SizedBox(height: 9),
                      const Text('환급 최소 소비 조건을 이미 충족했어요',
                          style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B8E4B))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _PhotoArea(
                bytes: _draftPreviewBytes,
                uploading: _uploading,
                onTap: _uploading ? null : _pickAndAnalyze,
              ),
              const SizedBox(height: 10),
              _Note(_acceptedPaymentMethods.isEmpty
                  ? '인정 결제수단은 지역마다 달라요. 지역 상세의 "결제 수단"을 확인하고 결제해 주세요.'
                  : '${detail.trip.regionName} 인정 결제수단: '
                      '${_acceptedPaymentMethods.map((code) => PaymentTypeWire.fromWire(code).label).join(' · ')}'),

              // OCR 결과 (draft) — 등록 전에 "이 정보가 맞나요?"로 확인받는다.
              if (draft != null) ...[
                const SizedBox(height: 14),
                _OcrCard(receipt: draft, won: won, onEdit: _editDraft),
              ],

              // 등록한 영수증
              if (detail.receipts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(children: [
                  const Text('등록한 영수증',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink9)),
                  const SizedBox(width: 6),
                  Text('${detail.receipts.length}건',
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink4)),
                ]),
                const SizedBox(height: 12),
                for (final r in detail.receipts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReceiptRow(
                      receipt: r,
                      won: won,
                      onEdit: () => _editSaved(r),
                      onDelete: () => _deleteReceipt(r.uploadedFileId),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: FilledButton.icon(
          onPressed: _uploading
              ? null
              : (_draftReceipt != null ? _commitDraft : _pickAndAnalyze),
          icon: Icon(
              _draftReceipt != null
                  ? Icons.add_rounded
                  : Icons.receipt_long_rounded,
              size: 18),
          label: Text(_draftReceipt != null ? '이 영수증 추가' : '영수증 사진 올리기'),
        ),
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  const _PhotoArea(
      {required this.bytes, required this.uploading, required this.onTap});
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surf,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: uploading
              ? const Center(child: CircularProgressIndicator())
              : bytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Image.memory(bytes!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 36, color: AppColors.ink4),
                        SizedBox(height: 10),
                        Text('영수증 사진 올리기',
                            style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink5)),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // 정본 .note — 배경/테두리 없는 인라인 텍스트(ink5) + p600 아이콘.
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.p600),
      const SizedBox(width: 7),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink5)),
      ),
    ]);
  }
}

class _OcrCard extends StatelessWidget {
  const _OcrCard({required this.receipt, required this.won, required this.onEdit});
  final ReceiptItem receipt;
  final NumberFormat won;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final approved = receipt.reviewStatus == ReceiptReviewStatus.approved;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.p600),
            SizedBox(width: 7),
            Text('AI가 읽은 영수증',
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink9)),
          ]),
          const SizedBox(height: 14),
          _kv(
            '결제수단',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(receipt.paymentType.label,
                  style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink9)),
              const SizedBox(width: 8),
              _PayChip(approved: approved),
            ]),
          ),
          _kv('금액',
              value: '${won.format(receipt.amount ?? receipt.eligibleAmount)}원',
              highlight: true),
          _kv('결제일시', value: _dt(receipt.paymentDateTime) ?? '확인되지 않음'),
          if (receipt.reviewReason.isNotEmpty)
            _kv('판정', value: receipt.reviewReason),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.track),
          const SizedBox(height: 10),
          // OCR은 완전하지 않다 — 등록 전에 사용자에게 확인받고 고칠 길을 연다.
          Row(children: [
            const Expanded(
              child: Text('이 정보가 맞나요?',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5)),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: const Text('수정하기'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.p600,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _kv(String k, {String? value, Widget? child, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(k,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text(value ?? '',
                    style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: highlight ? 16 : 14,
                        fontWeight:
                            highlight ? FontWeight.w900 : FontWeight.w700,
                        color: AppColors.ink9)),
          ),
        ],
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final bg = approved ? const Color(0xFFE7F7EE) : AppColors.coralTint;
    final fg = approved ? const Color(0xFF1B8E4B) : AppColors.coralDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(approved ? Icons.check_rounded : Icons.close_rounded,
            size: 13, color: fg),
        const SizedBox(width: 3),
        Text(approved ? '인정' : '미인정',
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg)),
      ]),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(
      {required this.receipt,
      required this.won,
      required this.onEdit,
      required this.onDelete});
  final ReceiptItem receipt;
  final NumberFormat won;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final approved = receipt.reviewStatus == ReceiptReviewStatus.approved;
    final tint = approved ? const Color(0xFF1B8E4B) : AppColors.coralDeep;
    final tintBg = approved ? const Color(0xFFE7F7EE) : AppColors.coralTint;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: tintBg, shape: BoxShape.circle),
          child: Icon(approved ? Icons.check_rounded : Icons.close_rounded,
              size: 17, color: tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${receipt.paymentType.label}${receipt.usageScope == ReceiptUsageScope.lodging ? ' · 숙박' : ''}',
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink9)),
            const SizedBox(height: 2),
            Text(_dt(receipt.paymentDateTime) ?? '일시 미확인',
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    color: AppColors.ink5)),
          ]),
        ),
        Text('${won.format(receipt.amount ?? receipt.eligibleAmount)}원',
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink9)),
        IconButton(
          onPressed: onEdit,
          tooltip: '정보 수정',
          icon: const Icon(Icons.edit_outlined, color: AppColors.ink4, size: 20),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.ink4, size: 20),
        ),
      ]),
    );
  }
}

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

String? _dt(DateTime? d) {
  if (d == null) return null;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.month}.${d.day}(${_weekdayKo[d.weekday - 1]}) $hh:$mm';
}

String _man(int won) {
  if (won >= 10000) {
    final m = won / 10000;
    final t = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
    return '$t만';
  }
  return '$won원';
}
