import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S3-1 온라인몰 메인 (사용처 연결 허브).
class MallTab extends StatelessWidget {
  const MallTab({super.key});

  static const _malls = [
    ('🍲', '강진맘', '강진군 공식 농수산물 쇼핑몰'),
    ('🏔️', '평창몰', '평창군 한우·특산물 직거래몰'),
    ('🐙', '청정완도', '완도군 수산물 온라인몰'),
    ('🌊', '영월몰', '영월군 농특산물 쇼핑몰'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: [
        const Text('온라인몰',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
        const SizedBox(height: 20),
        const SectionTitle('내 환급금 사용처'),
        const SizedBox(height: 8),
        const NoteRow('정산을 신청한 지역이에요. 환급금(지역화폐)이 들어오면 여기서 쓸 수 있어요.'),
        const SizedBox(height: 14),
        const _RegionUsageCard(emoji: '⛰️', name: '제천', sub: '정산 신청 완료 · 5.11'),
        const SizedBox(height: 14),
        const _RegionUsageCard(emoji: '🌊', name: '영월', sub: '정산 신청 완료 · 6.02'),
        const SizedBox(height: 24),
        const SectionTitle('지역별 온라인몰'),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final m in _malls)
              InkWell(
                onTap: () => showMock(context, '${m.$2}(으)로 이동해요. (외부 링크 · 목업)'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(children: [
                    EmojiBox(m.$1, size: 42, fontSize: 21, color: AppColors.surf, radius: 13),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.$2,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                        const SizedBox(height: 2),
                        Text(m.$3,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                      ]),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 17, color: AppColors.ink4),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

/// 지역화폐 가맹점 지도 — 지도 목업 + 핀 매칭 가맹점 리스트.
class MerchantMapScreen extends StatefulWidget {
  const MerchantMapScreen({super.key, required this.regionName});
  final String regionName;

  @override
  State<MerchantMapScreen> createState() => _MerchantMapScreenState();
}

class _MerchantMapScreenState extends State<MerchantMapScreen> {
  int _cat = 0;

  static const _cats = ['전체', '음식점', '카페', '숙박', '마트·편의'];

  static const _merchants = [
    ('🍲', '중앙시장 손맛식당', '음식점', '중앙로 12', true),
    ('☕', '호수뷰 카페', '카페', '호반로 88', false),
    ('🏠', '온돌 한옥스테이', '숙박', '향교길 5', true),
    ('🛒', '우리동네 하나로마트', '마트·편의', '시장길 31', false),
    ('🍖', '숯불 정육식당', '음식점', '역전로 47', true),
  ];

  @override
  Widget build(BuildContext context) {
    final list = _merchants
        .where((m) => _cat == 0 || m.$3 == _cats[_cat])
        .toList();
    return DetailScaffold(
      title: '${widget.regionName} 가맹점 지도',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        CatChips(labels: _cats, selected: _cat, onChanged: (i) => setState(() => _cat = i)),
        Container(
          height: 188,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFEDF4FA), borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.map_outlined, size: 40, color: AppColors.p400),
            const SizedBox(height: 8),
            Text('${widget.regionName} 일대 · 가맹점 ${list.length}곳 (지도 목업)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(children: [
            const Text('지역화폐 가맹점',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
            const Spacer(),
            Text('${list.length}곳',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
          ]),
        ),
        for (var i = 0; i < list.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line))),
            child: Row(children: [
              EmojiBox(list[i].$1, size: 42, fontSize: 21, color: AppColors.surf, radius: 13),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(list[i].$2,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text('${list[i].$3} · ${widget.regionName} ${list[i].$4}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                    ),
                    if (list[i].$5) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.mintTint, borderRadius: BorderRadius.circular(999)),
                        child: const Text('디민증 할인',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.mintDeep)),
                      ),
                    ],
                  ]),
                ]),
              ),
              GestureDetector(
                onTap: () => showMock(context, '${list[i].$2} 길찾기 — 지도 앱으로 이동해요. (외부 링크 · 목업)'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.near_me_outlined, size: 19, color: AppColors.p600),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

class _RegionUsageCard extends StatelessWidget {
  const _RegionUsageCard({required this.emoji, required this.name, required this.sub});
  final String emoji;
  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          EmojiBox(emoji, size: 46, fontSize: 23),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlineButton('지역화폐 앱',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => showMock(context, '$name 지역화폐 앱으로 이동해요. (외부 링크 · 목업)')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlineButton('온라인몰',
                icon: Icons.shopping_bag_outlined,
                onTap: () => showMock(context, '$name 온라인몰로 이동해요. (외부 링크 · 목업)')),
          ),
        ]),
        const SizedBox(height: 10),
        OutlineButton('$name 지역화폐 가맹점 지도',
            icon: Icons.place_outlined,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MerchantMapScreen(regionName: name)))),
      ]),
    );
  }
}
