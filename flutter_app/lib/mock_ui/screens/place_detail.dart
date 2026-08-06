import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S1-5 장소 정보 상세.
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({
    super.key,
    this.emoji = '🌉',
    this.name = '가우도 출렁다리',
    this.category = '관광지 · 전라남도 강진',
  });

  final String emoji;
  final String name;
  final String category;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '장소 정보',
      cta: CtaBar(children: [
        PrimaryButton('코스에 추가', icon: Icons.add_rounded, onTap: () {
          Navigator.of(context).pop();
          showMock(context, '$name을(를) 코스에 담았어요.');
        }),
      ]),
      children: [
        Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(24)),
          child: Text(emoji, style: const TextStyle(fontSize: 84)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.8)),
            const SizedBox(height: 4),
            Text(category,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            const SizedBox(height: 12),
            const Row(children: [
              Pill('환급 인정 관광지', tone: PillTone.mint),
              SizedBox(width: 6),
              Pill('디민증 할인'),
            ]),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('정보',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            SizedBox(height: 13),
            _InfoRow(Icons.place_outlined, '주소', '전라남도 강진군 대구면 저두리 940'),
            SizedBox(height: 13),
            _InfoRow(Icons.schedule_rounded, '운영시간', '09:00 ~ 18:00 · 연중무휴'),
            SizedBox(height: 13),
            _InfoRow(Icons.payments_outlined, '이용료', '무료 · 짚라인 별도 19,000원'),
            SizedBox(height: 13),
            _InfoRow(Icons.call_outlined, '문의', '061-430-3911'),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('결제 · 혜택',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            SizedBox(height: 13),
            _BenefitRow(Icons.credit_card_rounded, '지역화폐 결제 가능 · 강진사랑상품권(Chak) — 환급 인정 결제수단'),
            SizedBox(height: 13),
            _BenefitRow(Icons.badge_outlined, '디민증 제시 시 짚라인 10% 할인'),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('위치',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FA), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.place_rounded, size: 40, color: AppColors.p500),
            ),
            const SizedBox(height: 12),
            SurfRow(
              icon: Icons.place_outlined,
              title: '강진군 대구면 저두리',
              subtitle: '지도에서 길찾기',
              onTap: () => showMock(context, '지도 앱으로 이동해요. (외부 링크 · 목업)'),
            ),
          ]),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: AppColors.p600),
      ),
      const SizedBox(width: 11),
      SizedBox(
        width: 62,
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink7, height: 1.45)),
      ),
    ]);
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: AppColors.p600),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9, height: 1.45)),
      ),
    ]);
  }
}
