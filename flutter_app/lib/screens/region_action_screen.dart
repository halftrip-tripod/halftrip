import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../data/region_guides.dart';
import '../models/app_models.dart';
import '../mock_ui/widgets/region_art.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';

/// 지역 상세 (S1-2, 신청 판단 허브) — 디자인: halftrip-design/region-detail.html
/// 히어로 + 환급 조건 요약 + 정산 규칙 아코디언 + 디민증·지역화폐 + 하단 CTA.
/// 오픈예정 지역은 신청 대신 오픈 알림 CTA (관심·알림 API 연동).
class RegionActionScreen extends StatefulWidget {
  const RegionActionScreen({super.key, required this.region});

  final RegionSummary region;

  @override
  State<RegionActionScreen> createState() => _RegionActionScreenState();
}

class _RegionActionScreenState extends State<RegionActionScreen> {
  final Set<int> _openSections = {0};

  bool get _isPreparing =>
      widget.region.statusCode.toUpperCase() == 'PREPARING';

  Future<void> _toggleOpenAlert() async {
    final controller = AppScope.of(context);
    final wasEnabled = controller.currentUser?.favoriteRegions
            .any((item) => item.id == widget.region.id) ??
        false;
    await controller.toggleFavoriteRegion(widget.region);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasEnabled
          ? '${widget.region.name} 오픈 알림을 해제했어요.'
          : '${widget.region.name} 접수가 열리면 바로 알려드릴게요!'),
    ));
  }

  Future<void> _openApplyLink() async {
    final url = widget.region.halfPriceApplyUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 연결된 신청 페이지가 없습니다.')),
      );
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _openDigitalCardLink() async {
    final url = widget.region.digitalTourCardApplyUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발급 페이지 연결을 준비 중이에요.')),
      );
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final region = widget.region;
    final guide = settlementGuideFor(region.name);
    final guideText = _joinGuideBullets(guide);
    final isFavorite = controller.currentUser?.favoriteRegions
            .any((item) => item.id == region.id) ??
        false;
    final alertEnabled = isFavorite;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(region.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // HERO
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RegionArt(region.name, size: 64, fontSize: 34, radius: 20),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.name,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink9,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          region.province,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Pill(
                      region.statusLabel,
                      tone: switch (region.statusCode.toUpperCase()) {
                        'APPLYING' => PillTone.sky,
                        'CLOSED' => PillTone.gray,
                        _ => PillTone.gold,
                      },
                    ),
                    if (region.digitalBenefitAvailable) ...[
                      const SizedBox(width: 8),
                      const Pill('디민증 중복혜택', tone: PillTone.mint),
                    ],
                    const Spacer(),
                    _BudgetChip(remaining: region.mockBudgetRemaining.clamp(0, 100)),
                  ],
                ),
              ],
            ),
          ),
          // 오픈 전 안내 — 조건은 공고 기준으로 미리 공개
          if (_isPreparing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.p50,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_outlined, size: 20, color: AppColors.p600),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '아직 접수 전이에요. 아래 조건은 지자체 사업 공고 기준 — 미리 확인하고 오픈되면 바로 신청하세요.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 환급 조건 요약
          _DCard(
            title: '환급 조건 요약',
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '50%',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: AppColors.p600,
                        letterSpacing: -1.2,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: 9),
                    Text(
                      '여행경비 환급',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink7,
                      ),
                    ),
                  ],
                ),
              ),
              _Kv('결제 수단', _paymentSummary(region.name, guideText)),
              _Kv('인증 조건', _proofSummary(region.name, guideText)),
              _Kv('최소 소비', _minSpendSummary(region.name, guideText)),
              _Kv('1인 최대 환급', '${_formatWon(region.refundConditionAmount)}원'),
            ],
          ),
          const SizedBox(height: 16),
          // 상세 정산 규칙 (아코디언)
          _DCard(
            title: '상세 정산 규칙',
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.soft,
                      ),
                      child: const Icon(Icons.schedule_rounded,
                          size: 19, color: AppColors.p600),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '정산 신청 기한',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.p600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guide.deadline,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < guide.sections.length; i++)
                _accordion(i, guide.sections[i]),
              if (guide.note != null && guide.note!.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    guide.note!,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A6800),
                      height: 1.55,
                    ),
                  ),
                ),
            ],
          ),
          // 디민증
          if (region.digitalBenefitAvailable) ...[
            const SizedBox(height: 16),
            _DCard(
              title: '디지털 관광주민증 혜택',
              children: [
                const Text(
                  '반값여행 + 디민증 중복 혜택 가능',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.mintDeep,
                  ),
                ),
                Text(
                  '${region.name} 관광주민증 제시 시 일부 가맹점에서 추가 할인 혜택을 받을 수 있어요.',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink5,
                    height: 1.45,
                  ),
                ),
                _OutlineAction(
                  icon: Icons.badge_outlined,
                  trailing: Icons.open_in_new_rounded,
                  label: '관광주민증 발급받으러 가기',
                  onTap: _openDigitalCardLink,
                ),
              ],
            ),
          ],
          // 지역화폐
          const SizedBox(height: 16),
          _DCard(
            title: '지역화폐 앱 안내',
            children: [
              Text(
                _localCurrencyAppName(region.name),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                ),
              ),
              Text(
                _localCurrencyDescription(region.name),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
      // 하단 CTA — 접수중: 별표+신청 / 오픈예정: 오픈 알림
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: _isPreparing
            ? FilledButton.icon(
                onPressed: _toggleOpenAlert,
                icon: Icon(
                  alertEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 19,
                ),
                label: Text(alertEnabled ? '오픈 알림 신청됨 ✓' : '오픈 알림 받기'),
              )
            : Row(
                children: [
                  GestureDetector(
                    onTap: () => controller.toggleFavoriteRegion(region),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 24,
                        color:
                            isFavorite ? AppColors.warning : AppColors.ink5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _openApplyLink,
                      child: const Text('신청하러 가기'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _accordion(int index, RegionRuleSection section) {
    final open = _openSections.contains(index);
    return Column(
      children: [
        if (index > 0) const Divider(height: 1, color: AppColors.line),
        InkWell(
          onTap: () => setState(
              () => open ? _openSections.remove(index) : _openSections.add(index)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_sectionIcon(section.title),
                      size: 18, color: AppColors.p600),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.ink4),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 45, bottom: 14, right: 2),
            child: Column(
              children: [
                for (final bullet in section.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: const BoxDecoration(
                              color: AppColors.p400, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            bullet,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink7,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

IconData _sectionIcon(String title) {
  if (title.contains('인증') || title.contains('사진')) {
    return Icons.photo_camera_outlined;
  }
  if (title.contains('결제') || title.contains('경비') || title.contains('소비')) {
    return Icons.credit_card_rounded;
  }
  if (title.contains('숙박')) return Icons.bed_outlined;
  return Icons.description_outlined;
}

/// 지역상세 카드 (제목 + 컨텐츠, 13px 간격).
class _DCard extends StatelessWidget {
  const _DCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -0.3,
            ),
          ),
          for (final child in children) ...[const SizedBox(height: 13), child],
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink9,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final urgent = remaining < 35;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFEECEC) : AppColors.p100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.local_fire_department_rounded : Icons.savings_outlined,
            size: 14,
            color: urgent ? AppColors.danger : AppColors.p700,
          ),
          const SizedBox(width: 5),
          Text(
            '잔여 예산 $remaining%',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: urgent ? AppColors.danger : AppColors.p700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.p600),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink7,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Icon(trailing, size: 15, color: AppColors.ink4),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatWon(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final indexFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _joinGuideBullets(RegionSettlementGuide guide) =>
    guide.sections.expand((section) => section.bullets).join(' ');

String _paymentSummary(String regionName, String guideText) {
  if (guideText.contains('카드') && guideText.contains('간편결제')) {
    return '지역화폐, 카드, 간편결제';
  }
  if (guideText.contains('제로페이')) {
    return '지역화폐, 제로페이, 카드';
  }
  if (guideText.contains('현금영수증')) {
    return '카드, 현금영수증, 지역화폐';
  }
  return '지역화폐, 카드 결제';
}

String _proofSummary(String regionName, String guideText) {
  if (guideText.contains('인증샷') || guideText.contains('사진')) {
    return '영수증 + 여행 인증 사진';
  }
  return '영수증 제출';
}

String _minSpendSummary(String regionName, String guideText) {
  if (guideText.contains('개인 신청자 3만 원')) {
    return '개인 30,000원 / 팀 50,000원 이상';
  }
  if (guideText.contains('개인 신청자 5만원')) {
    return '개인 50,000원 / 팀 100,000원 이상';
  }
  if (guideText.contains('개인당 5만원')) {
    return '개인 50,000원 / 팀 100,000원 이상';
  }
  if (guideText.contains('최소 소비액(여행경비) 5만원')) {
    return '50,000원 이상';
  }
  return '지역 공고 기준 확인';
}

String _localCurrencyAppName(String regionName) => switch (regionName) {
      '평창' => '평창사랑상품권',
      '횡성' => '횡성몰 / 홈페이지',
      '영월' => '영월별빛고운카드',
      '제천' => '제천화폐 Chak',
      '거창' => '거창반값여행 상품권',
      '고창' => '고창사랑카드',
      '합천' => '합천반값여행 상품권',
      '영광' => '그리고',
      '밀양' => '밀양사랑상품권',
      '영암' => '월출페이',
      '하동' => '하동반값여행 상품권',
      '강진' => '강진사랑상품권 Chak',
      '남해' => '남해사랑상품권',
      '해남' => '해남사랑상품권',
      '고흥' => '고흥사랑상품권',
      '완도' => '완도사랑상품권',
      _ => '지역화폐 앱',
    };

String _localCurrencyDescription(String regionName) => switch (regionName) {
      '평창' => '평창사랑상품권 가맹점에서 사용할 수 있어요.',
      '횡성' => '횡성 지역 공지에 따라 사용 앱이 공개될 예정입니다.',
      '영월' => '영월 지역화폐 결제 내역과 카드 정보를 함께 확인해요.',
      '제천' => '제천화폐 사용 내역은 Chak 시스템 기준으로 정산됩니다.',
      '거창' => '거창 반값여행 상품권 사용 내역을 앱에서 확인해요.',
      '고창' => '고창사랑카드 결제 내역을 정산 전에 확인해 주세요.',
      '합천' => '모바일 합천반값여행 상품권 사용 내역이 필요해요.',
      '영광' => '그리고 앱 또는 카드 거래내역을 준비해 주세요.',
      '밀양' => '밀양사랑상품권 제로페이 사용 내역이 필요해요.',
      '영암' => '월출페이 이용내역 상세 화면으로 정산에 활용해요.',
      '하동' => '하동반값여행 상품권 제로페이 전자영수증이 필요해요.',
      '강진' => '강진사랑상품권 Chak 거래내역을 확인할 수 있어요.',
      _ => '지역화폐 거래내역을 정산 증빙으로 활용할 수 있어요.',
    };

