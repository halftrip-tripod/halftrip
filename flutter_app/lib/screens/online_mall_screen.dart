import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui/app_card.dart';

/// 온라인몰 (S3-1) — 디자인: halftrip-design/online-mall.html
/// 설계 결정: 온라인몰 = 사용처 "연결 허브". 환급 여부·잔액은 앱이 알 수 없으므로
/// 지갑 금액 대신 정산 신청한 지역의 사용처(지역화폐 앱·온라인몰·가맹점 지도)로 연결만 한다.
class OnlineMallScreen extends StatelessWidget {
  const OnlineMallScreen({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  static const List<_ExternalMall> _malls = [
    _ExternalMall(emoji: '🍲', name: '강진맘', desc: '강진군 공식 농수산물 쇼핑몰'),
    _ExternalMall(emoji: '🏎️', name: '영암몰', desc: '영암군 특산물 쇼핑몰', url: 'https://yeongam.jnmall.kr/'),
    _ExternalMall(emoji: '🏔️', name: '평창몰', desc: '평창군 한우·특산물 직거래몰'),
    _ExternalMall(emoji: '🌊', name: '영월몰', desc: '영월군 농특산물 쇼핑몰'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settled = controller.trips.where((t) => t.settlementApplied).toList();

    return AppShell(
      title: '온라인몰',
      modeName: controller.modeName,
      currentTabIndex: currentTabIndex,
      onTabSelected: onTabSelected,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const Text(
            '온라인몰',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('내 환급금 사용처'),
          const SizedBox(height: 8),
          const _Note('정산을 신청한 지역이에요. 환급금(지역화폐)이 들어오면 여기서 쓸 수 있어요.'),
          const SizedBox(height: 14),
          if (settled.isEmpty)
            const _EmptyUsage()
          else
            for (final trip in settled) ...[
              _RegionUsageCard(trip: trip),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 10),
          const _SectionTitle('지역별 온라인몰'),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final mall in _malls) _ExternalMallRow(mall: mall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.ink9,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.p600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.ink5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// 정산 신청한 지역 카드 — 지역화폐 앱 · 온라인몰 · 가맹점 지도 연결.
class _RegionUsageCard extends StatelessWidget {
  const _RegionUsageCard({required this.trip});

  final TripSummary trip;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final applied = '${trip.endDate.month}.${trip.endDate.day}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_regionEmoji(trip.regionName),
                    style: const TextStyle(fontSize: 23)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.regionName,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '정산 신청 완료 · $applied',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OutlineAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '지역화폐 앱',
                  onTap: () =>
                      _todo(context, '${trip.regionName} 지역화폐 앱으로 이동해요.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineAction(
                  icon: Icons.shopping_bag_outlined,
                  label: '온라인몰',
                  onTap: () =>
                      _todo(context, '${trip.regionName} 온라인몰로 이동해요.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OutlineAction(
            icon: Icons.place_outlined,
            label: '${trip.regionName} 지역화폐 가맹점 지도',
            onTap: () => _todo(context, '가맹점 지도는 연동 준비 중이에요.'),
          ),
        ],
      ),
    );
  }
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.p50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 26, color: AppColors.p600),
          ),
          const SizedBox(height: 12),
          const Text(
            '아직 정산 신청한 여행이 없어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink9,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '여행을 다녀와 정산까지 마치면\n환급금 쓸 곳을 여기 모아드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.ink5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
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
  });

  final IconData icon;
  final String label;
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
          ],
        ),
      ),
    );
  }
}

class _ExternalMall {
  const _ExternalMall({
    required this.emoji,
    required this.name,
    required this.desc,
    this.url,
  });

  final String emoji;
  final String name;
  final String desc;
  final String? url;
}

class _ExternalMallRow extends StatelessWidget {
  const _ExternalMallRow({required this.mall});

  final _ExternalMall mall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final url = mall.url;
        if (url == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${mall.name} 링크는 연동 준비 중이에요.')),
          );
          return;
        }
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(mall.emoji, style: const TextStyle(fontSize: 21)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mall.name,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mall.desc,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 17, color: AppColors.ink4),
          ],
        ),
      ),
    );
  }
}

String _regionEmoji(String regionName) {
  const map = <String, String>{
    '평창': '🏔️',
    '횡성': '🥩',
    '영월': '🌊',
    '제천': '⛰️',
    '거창': '🌿',
    '고창': '🏛️',
    '합천': '🌄',
    '영광': '🐟',
    '밀양': '🏞️',
    '영암': '🏎️',
    '하동': '🍃',
    '강진': '🍲',
    '남해': '🌴',
    '해남': '🌾',
    '고흥': '🚀',
    '완도': '🏝️',
  };
  return map[regionName] ?? '📍';
}
