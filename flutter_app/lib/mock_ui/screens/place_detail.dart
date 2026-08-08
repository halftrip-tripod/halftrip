import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S1-5 장소 정보 상세 — 실 API(PlaceItem) 연동.
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final PlaceItem place;

  Future<void> _openDirections(BuildContext context) async {
    final uri = (place.latitude != null && place.longitude != null)
        ? Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${place.latitude},${place.longitude}',
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${place.name} ${place.address}',
          });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('길찾기 화면을 열지 못했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentLabel = place.paymentMethods.isNotEmpty
        ? place.paymentMethods.map((code) => PaymentTypeWire.fromWire(code).label).join(' · ')
        : '지역화폐, 카드 결제';
    final hasDigitalDiscount = (place.digitalDiscountText ?? '').trim().isNotEmpty;

    return DetailScaffold(
      title: '장소 정보',
      cta: CtaBar(children: [
        PrimaryButton('코스에 추가', icon: Icons.add_rounded, onTap: () {
          Navigator.of(context).pop();
          showMock(context, '${place.name}을(를) 코스에 담았어요.');
        }),
      ]),
      children: [
        Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(24)),
          child: const Text('📍', style: TextStyle(fontSize: 84)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.8)),
            const SizedBox(height: 4),
            Text(place.address,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            const SizedBox(height: 12),
            Row(children: [
              if (place.eligibleForRefund) const Pill('환급 인정 관광지', tone: PillTone.mint),
              if (place.eligibleForRefund && hasDigitalDiscount) const SizedBox(width: 6),
              if (hasDigitalDiscount) const Pill('디민증 할인'),
            ]),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('정보',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 13),
            _InfoRow(Icons.place_outlined, '주소', place.address),
            const SizedBox(height: 13),
            _InfoRow(Icons.schedule_rounded, '운영시간', place.openingHours ?? '운영시간 정보 준비중'),
            const SizedBox(height: 13),
            _InfoRow(Icons.payments_outlined, '이용료', place.admissionFee ?? '이용료 정보 준비중'),
            const SizedBox(height: 13),
            _InfoRow(Icons.call_outlined, '문의', place.phone ?? '문의처 정보 준비중'),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('결제 · 혜택',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 13),
            _BenefitRow(Icons.credit_card_rounded, '환급 인정 결제수단 — $paymentLabel'),
            const SizedBox(height: 13),
            _BenefitRow(Icons.badge_outlined,
                hasDigitalDiscount ? place.digitalDiscountText! : '디민증 할인 정보가 아직 없어요.'),
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
              title: place.address,
              subtitle: '지도에서 길찾기',
              onTap: () => _openDirections(context),
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
