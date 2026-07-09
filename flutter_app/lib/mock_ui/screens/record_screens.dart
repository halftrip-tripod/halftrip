import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'trip_detail.dart';

/// S2-5 관광지 인증샷 ⭐.
class AuthPhotoScreen extends StatefulWidget {
  const AuthPhotoScreen({super.key});

  @override
  State<AuthPhotoScreen> createState() => _AuthPhotoScreenState();
}

class _AuthPhotoScreenState extends State<AuthPhotoScreen> {
  bool _retaken = false;

  void _retake() {
    setState(() => _retaken = true);
    if (AppState.I.authPhotoDone < 2) {
      AppState.I.authPhotoDone = 2;
      AppState.I.update();
    }
    showMock(context, '다시 촬영한 사진으로 얼굴·배경 인증까지 통과했어요! (목업)');
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '관광지 인증',
      cta: _retaken
          ? null
          : CtaBar(children: [PrimaryButton('다시 촬영하기', icon: Icons.refresh_rounded, onTap: _retake)]),
      children: [
        _ProgHeader(
          icon: Icons.photo_camera_outlined,
          label: '지정관광지 인증',
          value: '${AppState.I.authPhotoDone} / 2곳',
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('가우도 출렁다리 인증',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        ),
        _UploadPhoto(emoji: '🌉', onRetake: _retake),
        const NoteRow(
          '기본 카메라로 찍은 사진을 올려주세요. 위치·시간(GPS) 정보가 있어야 자동 인증돼요. 캡처·SNS 저장 사진은 정보가 지워질 수 있어요.',
          icon: Icons.photo_camera_outlined,
        ),
        if (!_retaken)
          const FitBanner(warn: true, title: '얼굴·배경 확인이 필요해요', subtitle: '사람과 배경이 잘 보이게 다시 찍어주세요')
        else
          const FitBanner(title: '인증 완료! 2/2곳 달성', subtitle: '위치·시각·인원·얼굴 모두 확인됐어요'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            const _VRow(icon: Icons.place_outlined, ok: true, label: '위치 · 지정관광지 반경 내', value: '일치'),
            const _VRow(icon: Icons.schedule_rounded, ok: true, label: '촬영 시각 · 여행 기간 내', value: '확인'),
            const _VRow(icon: Icons.group_outlined, ok: true, label: '인원', value: '2명 확인'),
            _VRow(
                icon: _retaken ? Icons.check_rounded : Icons.error_outline_rounded,
                ok: _retaken,
                label: '얼굴·배경',
                value: _retaken ? '확인' : '확인 안됨'),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('지정관광지 인증 현황',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            const _VRow(icon: Icons.check_rounded, ok: true, label: '🏯 다산초당', value: '인증 완료'),
            _VRow(
                icon: _retaken ? Icons.check_rounded : Icons.photo_camera_outlined,
                ok: _retaken,
                pending: !_retaken,
                label: '🌉 가우도 출렁다리',
                value: _retaken ? '인증 완료' : '판정 중'),
          ]),
        ),
      ],
    );
  }
}

/// S2-6 영수증 OCR ⭐.
class ReceiptOcrScreen extends StatefulWidget {
  const ReceiptOcrScreen({super.key});

  @override
  State<ReceiptOcrScreen> createState() => _ReceiptOcrScreenState();
}

class _ReceiptOcrScreenState extends State<ReceiptOcrScreen> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return DetailScaffold(
      title: '영수증 인증',
      cta: CtaBar(children: [
        PrimaryButton(_added ? '추가 완료' : '이 영수증 추가', disabled: _added, onTap: () {
          s.addReceipt(Receipt(name: '강진만 회타운', category: '한식', amount: 38000));
          setState(() => _added = true);
          showMock(context, '영수증을 등록했어요. 누적 소비에 반영됩니다.');
        }),
      ]),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProgressGauge(
              label: '누적 소비',
              value: '${s.spentAmount ~/ 10000}만 / 20만원',
              progress: (s.spentAmount / 200000).clamp(0, 1),
            ),
            const SizedBox(height: 9),
            const Text('환급 최소 소비(팀 5만원 이상)는 이미 충족했어요',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ),
        _UploadPhoto(emoji: '🧾', height: 200, onRetake: () => showMock(context, '카메라는 목업에서 생략했어요.')),
        const NoteRow('인정 결제수단: 지역화폐 · 카드 · 현금영수증. 간이영수증·계좌이체는 인정되지 않을 수 있어요.'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.p600),
              SizedBox(width: 7),
              Text('AI가 읽은 영수증',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            ]),
            SizedBox(height: 4),
            _OcrKv('상호', '강진만 회타운'),
            _OcrKv('결제수단', '강진사랑상품권(Chak)', chip: '인정'),
            _OcrKv('금액', '38,000원', bold: true),
            _OcrKv('결제일시', '6.14 (토) 12:41'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '등록한 영수증 '),
              TextSpan(
                  text: '${s.receipts.length + 2}건',
                  style: const TextStyle(color: AppColors.ink4, fontWeight: FontWeight.w700)),
            ]),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final r in s.receipts)
              _VRow(
                icon: Icons.check_rounded,
                ok: true,
                label: '${r.name} · ${r.category}',
                value: '${_comma(r.amount)}원',
              ),
          ]),
        ),
      ],
    );
  }

  String _comma(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

/// S2-7 숙박확인서 작성·서명 ⭐.
class LodgingFormScreen extends StatelessWidget {
  const LodgingFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '숙박확인서',
      cta: CtaBar(children: [
        PrimaryButton('숙박확인서 저장', icon: Icons.bed_outlined, onTap: () {
          AppState.I.lodgingSaved = true;
          AppState.I.update();
          Navigator.of(context).pop();
          showMock(context, '숙박확인서를 저장했어요. 정산 때 증빙 패키지에 자동으로 묶여요.');
        }),
      ]),
      children: [
        AppCard(
          child: Column(children: const [
            _FormKv('숙소명', '다산 한옥스테이'),
            _FormKv('대표자명', '김다산'),
            _FormKv('주소', '전라남도 강진군 도암면 만덕리 12-3'),
            _FormKv('연락처', '061-432-1234'),
            Row(children: [
              Expanded(child: _FormKv('체크인', '6.14 (토)')),
              SizedBox(width: 12),
              Expanded(child: _FormKv('체크아웃', '6.15 (일)')),
            ]),
            Row(children: [
              Expanded(child: _FormKv('투숙객', '규희 외 1명')),
              SizedBox(width: 12),
              Expanded(child: _FormKv('결제금액', '60,000원')),
            ]),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('숙소 대표자 서명',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 11),
            Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Stack(children: [
                const Center(
                  child: Text('〰️ 서명 완료',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink7)),
                ),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () => showMock(context, '서명 패드는 목업에서 생략했어요.'),
                    child: const Text('다시 서명',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink5,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const NoteRow('반값여행은 1박 숙박이 필수예요. 숙소 정보를 적고 대표자 서명을 받아 제출해요.'),
      ],
    );
  }
}

/// S2-8 증빙 패키지 ⭐.
class EvidencePackageScreen extends StatelessWidget {
  const EvidencePackageScreen({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '증빙 패키지',
      cta: CtaBar(children: [
        PrimaryButton('정산 신청 페이지로 이동', icon: Icons.open_in_new_rounded, onTap: () async {
          showMock(context, '지자체 정산 페이지로 이동해요. (외부 링크 · 목업)');
          await Future.delayed(const Duration(milliseconds: 900));
          if (!context.mounted) return;
          showSettleConfirmSheet(context, trip);
        }),
      ]),
      children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: '정산에 필요한\n'),
            TextSpan(text: '증빙', style: TextStyle(color: AppColors.p600)),
            TextSpan(text: '이 모두 준비됐어요'),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
        ),
        const Text('아래 증빙을 하나의 패키지로 묶어드려요',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: const [
            _PkgCheck('관광지 인증샷', '2 / 2곳 · 8장'),
            _PkgCheck('영수증 · 최소 소비', '12건 · 41만원'),
            _PkgCheck('숙박확인서', '1부 (서명 완료)'),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('생성된 증빙 패키지',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.folder_zip_outlined, size: 22, color: AppColors.p600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${trip.region}_반값여행_증빙팩.zip',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 3),
                  const Text('인증사진 8장 · 영수증 12건 · 숙박확인서 1부',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            OutlineButton('패키지 미리보기 · 다운로드',
                icon: Icons.description_outlined,
                onTap: () => showMock(context, '패키지 PDF 미리보기는 목업에서 생략했어요.')),
          ]),
        ),
        const NoteRow('이 패키지를 정산 신청 페이지에 업로드하면 심사를 거쳐 지역화폐가 지급돼요.'),
      ],
    );
  }
}

// ===== 공용 조각 =====

class _ProgHeader extends StatelessWidget {
  const _ProgHeader({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      radius: 18,
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.p600),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.p600)),
      ]),
    );
  }
}

class _UploadPhoto extends StatelessWidget {
  const _UploadPhoto({required this.emoji, required this.onRetake, this.height = 230});
  final String emoji;
  final VoidCallback onRetake;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(22)),
      child: Stack(children: [
        Center(child: Text(emoji, style: TextStyle(fontSize: height * .32))),
        Positioned(
          right: 12,
          bottom: 12,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: AppShadows.soft),
              child: const Row(children: [
                Icon(Icons.refresh_rounded, size: 14, color: AppColors.ink7),
                SizedBox(width: 5),
                Text('다시 촬영',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink7)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _VRow extends StatelessWidget {
  const _VRow({
    required this.icon,
    required this.ok,
    required this.label,
    required this.value,
    this.pending = false,
  });

  final IconData icon;
  final bool ok;
  final String label;
  final String value;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pending
        ? (AppColors.p100, AppColors.p600)
        : ok
            ? (AppColors.successTint, AppColors.success)
            : (AppColors.dangerTint, AppColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: fg),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9)),
        ),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: pending ? AppColors.p600 : (ok ? AppColors.ink5 : AppColors.danger),
            )),
      ]),
    );
  }
}

class _OcrKv extends StatelessWidget {
  const _OcrKv(this.k, this.v, {this.chip, this.bold = false});
  final String k;
  final String v;
  final String? chip;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(children: [
        SizedBox(
          width: 78,
          child: Text(k,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ),
        Expanded(
          child: Text(v,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: AppColors.ink9,
              )),
        ),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              const Icon(Icons.check_rounded, size: 12, color: AppColors.success),
              const SizedBox(width: 3),
              Text(chip!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF177D43))),
            ]),
          ),
      ]),
    );
  }
}

class _FormKv extends StatelessWidget {
  const _FormKv(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(13)),
          child: Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
        ),
      ]),
    );
  }
}

class _PkgCheck extends StatelessWidget {
  const _PkgCheck(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: AppColors.p500, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
        ),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]),
    );
  }
}
