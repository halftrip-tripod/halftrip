import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../mock_ui/screens/region_detail.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';

/// 관심 지역 보기·해제 — 홈/지역 상세의 ★(관심 등록)으로 담은 지역을 관리한다.
/// (추가는 지역 둘러보기가 있는 홈·지역 상세에서. 여기선 조회/해제만.)
class FavoriteRegionsScreen extends StatefulWidget {
  const FavoriteRegionsScreen({super.key});

  @override
  State<FavoriteRegionsScreen> createState() => _FavoriteRegionsScreenState();
}

class _FavoriteRegionsScreenState extends State<FavoriteRegionsScreen> {
  bool _busy = false;

  Future<void> _remove(RegionSummary region) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = AppScope.of(context);
    try {
      await controller.toggleFavoriteRegion(region);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${region.name}을(를) 관심 지역에서 뺐어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PillTone _statusTone(String statusCode) =>
      switch (statusCode.toUpperCase()) {
        'APPLYING' => PillTone.sky,
        'CLOSED' => PillTone.gray,
        _ => PillTone.gold,
      };

  @override
  Widget build(BuildContext context) {
    final favorites = AppScope.of(context).currentUser?.favoriteRegions ??
        const <RegionSummary>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('관심 지역')),
      body: SafeArea(
        child: favorites.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final region = favorites[i];
                  return AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    // 카드 탭 = 지역 상세 (★ 버튼은 해제 전용으로 그대로).
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => RegionDetailScreen(region: region)))
                        .then((_) => setState(() {})),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                              color: AppColors.p50, shape: BoxShape.circle),
                          child: const Icon(Icons.place_rounded,
                              color: AppColors.p600, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${region.name} · ${region.province}',
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink9,
                                      )),
                                  const SizedBox(width: 8),
                                  Pill(region.statusLabel,
                                      tone: _statusTone(region.statusCode)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text('오픈 · 마감 알림을 받는 중',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink5,
                                  )),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '관심 해제',
                          onPressed: _busy ? null : () => _remove(region),
                          icon: const Icon(Icons.star_rounded,
                              color: AppColors.warning),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.surf, shape: BoxShape.circle),
            child: const Icon(Icons.star_outline_rounded,
                size: 30, color: AppColors.ink4),
          ),
          const SizedBox(height: 16),
          Text('아직 관심 지역이 없어요',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('홈 · 지역 상세에서 ★를 눌러 담으면\n오픈 · 마감 알림을 받을 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink5,
              )),
        ],
      ),
    );
  }
}
