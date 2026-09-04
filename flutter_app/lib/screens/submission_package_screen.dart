import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../utils/browser_file_download.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/app_confirm_dialog.dart';
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
    final requiredAuth = detail.trip.authRequiredCount ?? 2;
    final receiptCount = detail.receipts.length;
    final hasLodging = detail.uploadedFiles
            .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
        detail.lodgingInfo?.uploadedFileId != null;
    final spent = detail.trip.totalSpentAmount;
    final goal = detail.trip.refundConditionAmount;
    final spentOk = goal <= 0 || spent >= goal;
    // 정산 누리집은 사진·영수증을 낱장으로 업로드한다 — 원본을 종류별로 묶은 zip이 기본.
    final fileName = '${detail.trip.regionName}_반값여행_증빙팩.zip';

    // 하나라도 비면 패키지를 "완성"으로 부르지 않는다. 빈 증빙을 제출하면 반려된다.
    final missing = <String>[
      if (authCount < requiredAuth) '관광지 인증샷',
      if (receiptCount == 0) '영수증',
      if (!spentOk) '최소 소비금액',
      if (!hasLodging) '숙박확인서',
    ];
    final ready = missing.isEmpty;
    final hasAnyFile = detail.uploadedFiles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('증빙 패키지')),
      body: ListView(
        // 증빙 계열 화면(인증샷·영수증·정산)과 같은 여백.
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.ink9,
              ),
              children: ready
                  ? const [
                      TextSpan(text: '정산에 필요한\n'),
                      TextSpan(text: '증빙', style: TextStyle(color: AppColors.p600)),
                      TextSpan(text: '이 모두 준비됐어요'),
                    ]
                  : [
                      const TextSpan(text: '아직 준비되지 않은\n'),
                      TextSpan(
                          text: '증빙 ${missing.length}가지',
                          style: const TextStyle(color: AppColors.p600)),
                      const TextSpan(text: '가 있어요'),
                    ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
              ready
                  ? '아래 증빙을 하나의 패키지로 묶어드려요'
                  : '${missing.join(' · ')}를 채워야 정산에서 반려되지 않아요',
              style: const TextStyle(
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
                  value: '${authCount.clamp(0, requiredAuth)}/$requiredAuth곳 · $authCount장',
                  done: authCount >= requiredAuth),
              // 영수증 건수와 소비 금액은 서로 다른 조건이라 한 줄에 묶으면
              // "0건인데 12만원"처럼 앞뒤가 안 맞는 문구가 된다.
              _CheckItem(
                  label: '영수증',
                  value: '$receiptCount건',
                  done: receiptCount > 0),
              _CheckItem(
                  label: '최소 소비',
                  value: goal > 0
                      ? '${won.format(spent)} / ${won.format(goal)}원'
                      : '${won.format(spent)}원',
                  done: spentOk),
              _CheckItem(
                  label: '숙박확인서',
                  value: hasLodging ? '1부 (서명 완료)' : '미작성',
                  done: hasLodging,
                  last: true),
            ]),
          ),
          const SizedBox(height: 18),

          // 생성된 패키지
          Text(ready ? '생성된 증빙 패키지' : '패키지 미리보기',
              style: const TextStyle(
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
              // 정본 .btn-outline — 보조 톤(surf 배경·ink7 글자·p600 아이콘). 최종액션이 아니라 준비물이라 primary 아님.
              TextButton.icon(
                // 증빙 파일이 하나도 없으면 묶을 것이 없다.
                onPressed: hasAnyFile ? () => _downloadZip(context) : null,
                icon: const Icon(Icons.folder_zip_outlined,
                    size: 16, color: AppColors.p600),
                label: Text(
                    hasAnyFile ? '증빙 zip 다운로드' : '증빙을 1개 이상 올려야 만들 수 있어요',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink7)),
                style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    backgroundColor: AppColors.surf,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18))),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _Note(ready
              ? '이 패키지를 정산 신청 페이지에 업로드하면 심사를 거쳐 지역화폐가 지급돼요.'
              : '지금 상태로 제출하면 증빙 누락으로 반려될 수 있어요. ${missing.join(' · ')}를 먼저 채워주세요.'),
        ],
      ),
      bottomNavigationBar: showSettlementButton
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: FilledButton.icon(
                onPressed: () => _goToSettlement(context, missing),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('정산 신청 페이지로 이동'),
              ),
            )
          : null,
    );
  }

  /// 증빙이 빈 채로 정산까지 흘러가지 않도록 한 번 되묻는다.
  /// 정산 신청 자체는 외부 사이트에서 이뤄지므로 완전히 막지는 않는다.
  Future<void> _goToSettlement(BuildContext context, List<String> missing) async {
    final navigator = Navigator.of(context);
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
    await navigator.push(
        MaterialPageRoute(builder: (_) => SettlementScreen(tripId: tripId)));
  }

  /// 원본 증빙을 종류별 폴더로 묶은 zip — 정산 누리집이 낱장 업로드 방식이라,
  /// PC에서 풀어 그대로 항목별로 올릴 수 있게 한다. 서명 파일은 제출물이 아니라 제외.
  Future<void> _downloadZip(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = AppScope.of(context);
    final files = detail.uploadedFiles
        .where((f) => f.fileCategory != FileCategory.signature)
        .toList();
    if (files.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('묶을 증빙 파일이 아직 없어요.')));
      return;
    }
    final zipName = '${detail.trip.regionName}_반값여행_증빙팩.zip';
    try {
      final path = await controller.runTask(() async {
        final archive = Archive();
        final counters = <FileCategory, int>{};
        for (final file in files) {
          final bytes = await controller.repository.downloadUploadedFileBytes(
            tripId: tripId,
            uploadedFileId: file.id,
          );
          final index = (counters[file.fileCategory] ?? 0) + 1;
          counters[file.fileCategory] = index;
          final entry = _zipEntryName(file, index);
          archive.addFile(ArchiveFile(entry, bytes.length, bytes));
        }
        final zipBytes = ZipEncoder().encode(archive);
        if (kIsWeb) {
          await downloadFileBytes(zipBytes, zipName,
              mimeType: 'application/zip');
          return '브라우저 다운로드: $zipName';
        }
        final directory = await getApplicationDocumentsDirectory();
        final out = File('${directory.path}/$zipName');
        await out.writeAsBytes(zipBytes);
        return out.path;
      });
      if (kIsWeb) {
        messenger.showSnackBar(SnackBar(content: Text('증빙 zip을 만들었어요: $path')));
        return;
      }
      // 앱 내부 폴더는 사용자가 못 꺼낸다 — 만든 즉시 공유 시트를 띄워
      // 내 파일·드라이브·카톡 등으로 저장/전송하게 한다.
      messenger.showSnackBar(const SnackBar(content: Text('증빙 zip을 만들었어요. 저장할 곳을 골라 주세요.')));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'application/zip', name: zipName)],
        subject: zipName,
        text: '${detail.trip.regionName} 반값여행 증빙 패키지',
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('zip 생성에 실패했어요: $e')));
    }
  }

  String _zipEntryName(UploadedFileItem file, int index) {
    final name = file.originalFileName;
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : (file.mimeType.contains('pdf') ? 'pdf' : 'jpg');
    return switch (file.fileCategory) {
      FileCategory.authPhoto => '인증샷/인증샷_$index.$ext',
      FileCategory.receiptImage => '영수증/영수증_$index.$ext',
      FileCategory.lodgingConfirmation => '숙박확인서/숙박확인서_$index.$ext',
      FileCategory.generatedPdf => '숙박확인서/숙박확인서_작성본_$index.$ext',
      FileCategory.signature => '기타/서명_$index.$ext',
    };
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
