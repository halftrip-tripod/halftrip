import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import 'submission_package_screen.dart';

/// 정산 신청 — 제출서류 체크 + 외부 정산 페이지 이동 + "신청 완료" 자가 표시.
/// (환급 완료는 외부라 앱이 모름 — 앱이 아는 마지막 상태 = 정산 신청 완료)
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  bool _busy = false;

  static const Map<String, String> _settlementUrlsByRegion = {
    '평창': 'https://www.wandotrip.kr/bbs/apply_date.php',
    '영월': 'https://halftour.kr/application/1',
    '제천': 'https://www.jctour.kr/menu2/1',
    '거창': 'https://geochangtour.kr/content/expenses_info',
    '고창': 'https://gochangtrip.co.kr/',
    '강진': 'https://www.gangjintour.com/main/main.html?',
    '남해': 'https://www.namhae.go.kr/tour/01057/01058.web',
    '완도': 'https://www.wandotrip.kr/bbs/apply_date.php',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
  }

  Future<TripDetail> _load() =>
      AppScope.of(context).repository.getTripDetail(widget.tripId);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await AppScope.of(context).refreshTrips();
  }

  Future<void> _openSettlementSite(String regionName) async {
    final url =
        _settlementUrlsByRegion[regionName] ?? _settlementUrlsByRegion['완도']!;
    final launched =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (mounted && !launched) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$regionName 정산 페이지를 열지 못했어요.')));
    }
  }

  Future<void> _applySettlement() async {
    final detail = await _future;
    if (!mounted) return;
    // 개인정보 최소화(계약 B): 실명·전화번호는 정산 신청 시점에만 수집한다.
    final applicant = await _askApplicantInfo(
      initialName: detail?.trip.applicantName ?? '',
    );
    if (applicant == null || !mounted) return;

    setState(() => _busy = true);
    final controller = AppScope.of(context);
    try {
      await controller.runTask(() => controller.repository.applySettlement(
            widget.tripId,
            applicantName: applicant.$1,
            phoneNumber: applicant.$2,
          ));
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('정산 신청 완료로 표시했어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 신청자 실명·전화번호 입력 시트. 취소하면 null.
  Future<(String, String)?> _askApplicantInfo({required String initialName}) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController();
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 4, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '신청자 정보 확인',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.ink9,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '실명과 전화번호는 이번 정산 신청에만 사용하고 계정에는 저장하지 않아요.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _ApplicantField(
              controller: nameController,
              hint: '이름 (신분증 기준)',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 10),
            _ApplicantField(
              controller: phoneController,
              hint: '전화번호 (010-0000-0000)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('이름과 전화번호를 입력해주세요.')));
                    return;
                  }
                  Navigator.of(sheetContext).pop((name, phone));
                },
                child: const Text('정산 신청 완료로 표시'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmission(TripDetail detail) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SubmissionPackageScreen(
            tripId: widget.tripId, detail: detail, showSettlementButton: false)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('정산 신청')),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          final applied = detail.trip.settlementApplied;
          final authCount = detail.uploadedFiles
              .where((f) => f.fileCategory == FileCategory.authPhoto)
              .length;
          final hasLodging = detail.uploadedFiles
                  .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
              detail.lodgingInfo?.uploadedFileId != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (applied)
                AppCard(
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                          color: AppColors.p50, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.p600, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text('정산 신청 완료',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text('환급은 보통 1~2개월 뒤 지자체에서 개별 안내돼요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.ink5)),
                  ]),
                )
              else ...[
                // 제출서류 준비
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('제출서류 준비',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _CheckItem(
                          label: '관광지 인증샷',
                          value: '${authCount.clamp(0, 2)}/2곳',
                          done: authCount >= 2),
                      _CheckItem(
                          label: '영수증 · 소비',
                          value: '${detail.receipts.length}건',
                          done: detail.receipts.isNotEmpty),
                      _CheckItem(
                          label: '숙박확인서',
                          value: hasLodging ? '완료' : '미작성',
                          done: hasLodging,
                          last: true),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _openSubmission(detail),
                        icon: const Icon(Icons.folder_zip_outlined, size: 18),
                        label: const Text('증빙 패키지 보기'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.field))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Note(
                    '${detail.trip.regionName} 정산 페이지에서 증빙을 제출하세요. 심사를 거쳐 지역화폐가 지급돼요.'),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          if (detail == null || detail.trip.settlementApplied) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _openSettlementSite(detail.trip.regionName),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('정산 신청하러 가기'),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _busy ? null : _applySettlement,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '이미 신청했어요 · ',
                          style: TextStyle(color: AppColors.ink5)),
                      TextSpan(
                          text: '완료로 표시',
                          style: TextStyle(
                              color: AppColors.p600,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline)),
                    ]),
                    style: TextStyle(fontFamily: 'Pretendard', fontSize: 13),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.value,
    required this.done,
    this.last = false,
  });
  final String label;
  final String value;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: last ? 0 : 8),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: done ? AppColors.p500 : AppColors.track,
              shape: BoxShape.circle),
          child: Icon(Icons.check_rounded,
              size: 14, color: done ? Colors.white : AppColors.ink4),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink9)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.ink5 : AppColors.ink4)),
      ]),
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

class _ApplicantField extends StatelessWidget {
  const _ApplicantField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink9,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.ink4),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
