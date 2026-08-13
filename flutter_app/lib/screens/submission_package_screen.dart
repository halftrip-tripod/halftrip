import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import 'settlement_screen.dart';

/// 증빙 패키지 — 인증샷+영수증+숙박확인서를 제출 규격으로 묶어 정산 신청으로 연결.
/// 디자인: halftrip-design/evidence-package.html
class SubmissionPackageScreen extends StatelessWidget {
  const SubmissionPackageScreen({
    super.key,
    required this.tripId,
    required this.detail,
    this.showSettlementButton = true,
  });

  final int tripId;
  final TripDetail detail;
  final bool showSettlementButton;

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final authCount = detail.uploadedFiles
        .where((f) => f.fileCategory == FileCategory.authPhoto)
        .length;
    final receiptCount = detail.receipts.length;
    final hasLodging = detail.uploadedFiles
            .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;
    final spent = detail.trip.totalSpentAmount;
    final fileName = '${detail.trip.regionName}_반값여행_증빙팩.zip';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('증빙 패키지')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.ink9,
              ),
              children: [
                TextSpan(text: '정산에 필요한\n'),
                TextSpan(text: '증빙', style: TextStyle(color: AppColors.p600)),
                TextSpan(text: '이 모두 준비됐어요'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('아래 증빙을 하나의 패키지로 묶어드려요',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink5)),
          const SizedBox(height: 18),

          // 완성도 체크리스트
          AppCard(
            child: Column(children: [
              _CheckItem(
                  label: '관광지 인증샷',
                  value: '${authCount.clamp(0, 2)}/2곳 · $authCount장',
                  done: authCount >= 2),
              _CheckItem(
                  label: '영수증 · 최소 소비',
                  value: '$receiptCount건 · ${won.format(spent)}원',
                  done: receiptCount > 0),
              _CheckItem(
                  label: '숙박확인서',
                  value: hasLodging ? '1부 (서명 완료)' : '미작성',
                  done: hasLodging,
                  last: true),
            ]),
          ),
          const SizedBox(height: 18),

          // 생성된 패키지
          const Text('생성된 증빙 패키지',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink9)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: AppColors.p50,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.p600, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink9)),
                      const SizedBox(height: 3),
                      Text(
                          '인증사진 $authCount장 · 영수증 $receiptCount건 · 숙박확인서 ${hasLodging ? 1 : 0}부',
                          style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12.5,
                              color: AppColors.ink5)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // 정본 .btn-outline — 보조 톤(surf 배경·ink7 글자·p600 아이콘). 최종액션이 아니라 미리보기라 primary 아님.
              TextButton.icon(
                onPressed: () => _downloadPackage(context),
                icon: const Icon(Icons.description_outlined,
                    size: 16, color: AppColors.p600),
                label: const Text('패키지 미리보기 · 다운로드',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink7)),
                style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    backgroundColor: AppColors.surf,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const _Note('이 패키지를 정산 신청 페이지에 업로드하면 심사를 거쳐 지역화폐가 지급돼요.'),
        ],
      ),
      bottomNavigationBar: showSettlementButton
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettlementScreen(tripId: tripId))),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('정산 신청 페이지로 이동'),
              ),
            )
          : null,
    );
  }

  Future<void> _downloadPackage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = AppScope.of(context);
    final fileIds = detail.uploadedFiles.map((f) => f.id).toList();
    if (fileIds.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('병합할 증빙 파일이 아직 없어요.')));
      return;
    }
    try {
      final path = await controller.runTask(
          () => controller.repository.downloadMergedPdf(tripId, fileIds));
      messenger.showSnackBar(SnackBar(content: Text('증빙 패키지를 생성했어요: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('패키지 생성에 실패했어요: $e')));
    }
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
            shape: BoxShape.circle,
          ),
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
