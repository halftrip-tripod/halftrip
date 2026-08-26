import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/app_confirm_dialog.dart';

/// 정산 신청 — 제출서류 체크 + 외부 정산 페이지 이동 + "신청 완료" 자가 표시.
/// (환급 완료는 외부라 앱이 모름 — 앱이 아는 마지막 상태 = 정산 신청 완료)
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen>
    with WidgetsBindingObserver {
  Future<TripDetail>? _future;
  bool _initialized = false;
  bool _busy = false;

  /// 외부 정산 페이지로 나갔다가 돌아왔는지 — 복귀 시 1회성 완료 확인 팝업용.
  bool _awaitingSiteReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingSiteReturn) return;
    _awaitingSiteReturn = false;
    _askIfSettlementDone();
  }

  Future<void> _askIfSettlementDone() async {
    final detail = await _future;
    if (!mounted || detail == null || detail.trip.settlementApplied) return;
    final done = await showAppConfirmDialog(
      context,
      title: '정산 신청을 완료했나요?',
      message: '지자체 정산 페이지에서 신청을 마쳤다면 이 여행도 완료로 표시할게요.',
      cancelLabel: '아직이에요',
      confirmLabel: '네, 완료했어요',
    );
    if (done && mounted) {
      await _applySettlement();
    }
  }

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
      return;
    }
    // 외부 페이지에서 돌아오면 "신청 완료했나요?" 1회 확인.
    _awaitingSiteReturn = true;
  }

  Future<void> _applySettlement() async {
    final detail = await _future;
    if (!mounted) return;
    // 신청은 지자체 사이트에서 이뤄지므로 앱이 실명·전화번호를 따로 받지 않는다.
    // (기존 신청자 정보 확인 시트 제거 — 8/26 결정)
    setState(() => _busy = true);
    final controller = AppScope.of(context);
    try {
      await controller.runTask(() => controller.repository.applySettlement(
            widget.tripId,
            applicantName: detail?.trip.applicantName ?? '',
            phoneNumber: '',
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

  /// 지자체에 제출했을 때 반려 사유가 되는 항목들.
  List<String> _missingEvidence(
      TripDetail detail, int authCount, bool hasLodging) {
    final goal = detail.trip.refundConditionAmount;
    return [
      if (authCount < (detail.trip.authRequiredCount ?? 2)) '관광지 인증샷',
      if (detail.receipts.isEmpty) '영수증',
      if (goal > 0 && detail.trip.totalSpentAmount < goal) '최소 소비금액',
      if (!hasLodging) '숙박확인서',
    ];
  }

  /// 증빙이 빈 채로 외부 정산 페이지까지 가지 않도록 한 번 되묻는다.
  /// 신청 자체는 외부에서 이뤄지므로 완전히 막지는 않는다.
  Future<void> _confirmThenOpenSite(
      TripDetail detail, List<String> missing) async {
    if (missing.isNotEmpty) {
      final proceed = await showAppConfirmDialog(
        context,
        title: '아직 빠진 증빙이 있어요',
        message: '${missing.join(' · ')}가 준비되지 않았어요.\n'
            '이대로 제출하면 반려될 수 있어요. 그래도 진행할까요?',
        cancelLabel: '증빙 마저 준비하기',
        confirmLabel: '그래도 진행',
        destructive: true,
      );
      if (!proceed) return;
    }
    await _openSettlementSite(detail.trip.regionName);
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
          final requiredAuth = detail.trip.authRequiredCount ?? 2;
          final hasLodging = detail.uploadedFiles
                  .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
              detail.lodgingInfo?.uploadedFileId != null;
          final missing = _missingEvidence(detail, authCount, hasLodging);

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
                          value: '${authCount.clamp(0, requiredAuth)}/$requiredAuth곳',
                          done: authCount >= requiredAuth),
                      _CheckItem(
                          label: '영수증 · 소비',
                          value: '${detail.receipts.length}건',
                          done: detail.receipts.isNotEmpty),
                      _CheckItem(
                          label: '숙박확인서',
                          value: hasLodging ? '완료' : '미작성',
                          done: hasLodging,
                          last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Note(missing.isEmpty
                    ? '${detail.trip.regionName} 정산 페이지에서 증빙을 제출하세요. 심사를 거쳐 지역화폐가 지급돼요.'
                    : '아직 ${missing.join(' · ')}가 준비되지 않았어요. 이대로 제출하면 반려될 수 있어요.'),
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
          final authCount = detail.uploadedFiles
              .where((f) => f.fileCategory == FileCategory.authPhoto)
              .length;
          final hasLodging = detail.uploadedFiles
                  .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
              detail.lodgingInfo?.uploadedFileId != null;
          final missing = _missingEvidence(detail, authCount, hasLodging);
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _confirmThenOpenSite(detail, missing),
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
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.p600)),
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
        AppCheckbox(checked: done),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

