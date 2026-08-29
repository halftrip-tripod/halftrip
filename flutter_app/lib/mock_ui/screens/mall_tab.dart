import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/merchant_map_screen.dart';
import '../../utils/internal_note.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S3-1 온라인몰 메인 (사용처 연결 허브).
class MallTab extends StatefulWidget {
  const MallTab({super.key});

  @override
  State<MallTab> createState() => _MallTabState();
}

class _MallData {
  const _MallData(this.settled, this.mallsByRegion, this.localCurrencyUrlByRegion,
      this.allRegionMallEntries);
  final List<TripSummary> settled;
  final Map<int, List<OnlineMallItem>> mallsByRegion;
  final Map<int, String?> localCurrencyUrlByRegion;
  final List<(String, OnlineMallItem)> allRegionMallEntries;
}

class _MallTabState extends State<MallTab> {
  Future<_MallData>? _future;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 정산을 신청하고 이 탭으로 오면 "내 환급금 사용처"가 새로 생긴다 —
    // 셸이 IndexedStack이라 탭 재진입 신호로 재조회해야 반영된다.
    AppState.I.tabShownTick.addListener(_onTabShown);
  }

  @override
  void dispose() {
    AppState.I.tabShownTick.removeListener(_onTabShown);
    super.dispose();
  }

  void _onTabShown() {
    if (!mounted || AppState.I.shownTab != 2 || _future == null) return;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // 데이터 로딩(컨트롤러 notifyListeners 동반)을 첫 프레임 이후로 미뤄
    // 빌드 도중 markNeedsBuild 예외를 방지한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() { _future = _load(); });
    });
  }

  Future<_MallData> _load() async {
    final controller = AppScope.of(context);
    await controller.refreshTrips();
    final settled =
        controller.trips.where((t) => t.settlementApplied).toList();
    final mallsByRegion = <int, List<OnlineMallItem>>{};
    final localCurrencyUrlByRegion = <int, String?>{};
    for (final trip in settled) {
      try {
        final detail = await controller.repository.getPlaceInfoDetail(
          trip.regionId,
          residence: controller.currentUser?.residence,
        );
        mallsByRegion[trip.regionId] = detail.onlineMalls;
        localCurrencyUrlByRegion[trip.regionId] = detail.region.localCurrencyAppUrl;
      } catch (_) {
        mallsByRegion[trip.regionId] = const [];
      }
    }

    final allRegionMallEntries = <(String, OnlineMallItem)>[];
    try {
      final regions = await controller.repository.getRegions(
        residence: controller.currentUser?.residence,
      );
      final details = await Future.wait(regions.map((region) async {
        try {
          return await controller.repository.getPlaceInfoDetail(
            region.id,
            residence: controller.currentUser?.residence,
          );
        } catch (_) {
          return null;
        }
      }));
      for (var i = 0; i < regions.length; i++) {
        final detail = details[i];
        if (detail == null) continue;
        for (final mall in detail.onlineMalls) {
          allRegionMallEntries.add((_regionEmoji(regions[i].name), mall));
        }
      }
    } catch (_) {}

    return _MallData(settled, mallsByRegion, localCurrencyUrlByRegion, allRegionMallEntries);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MallData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final settled = data?.settled ?? const <TripSummary>[];
        final mallEntries = data?.allRegionMallEntries ?? const <(String, OnlineMallItem)>[];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: [
            const Text('온라인몰',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
            const SizedBox(height: 20),
            const SectionTitle('내 환급금 사용처'),
            const SizedBox(height: 8),
            const NoteRow('정산을 신청한 지역이에요. 환급금(지역화폐)이 들어오면 여기서 쓸 수 있어요.'),
            const SizedBox(height: 14),
            if (data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (settled.isEmpty)
              const _EmptyUsage()
            else
              for (final trip in settled) ...[
                _RegionUsageCard(
                  trip: trip,
                  malls: data.mallsByRegion[trip.regionId] ?? const [],
                  localCurrencyUrl: data.localCurrencyUrlByRegion[trip.regionId],
                ),
                const SizedBox(height: 14),
              ],
            const SizedBox(height: 10),
            const SectionTitle('지역별 온라인몰'),
            const SizedBox(height: 12),
            if (data != null && mallEntries.isEmpty)
              const NoteRow('등록된 온라인몰이 아직 없어요.')
            else if (mallEntries.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  for (final entry in mallEntries)
                    InkWell(
                      onTap: () => _openMallUrl(context, entry.$2.name, entry.$2.mallUrl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(children: [
                          EmojiBox(entry.$1, size: 42, fontSize: 21, color: AppColors.surf, radius: 13),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(entry.$2.name,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                              // 내부 메모("TODO: 실제 온라인몰 연동 예정")가 그대로 노출되던 자리.
                              if (userFacingNote(entry.$2.description) case final note?) ...[
                                const SizedBox(height: 2),
                                Text(note,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                              ],
                            ]),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 17, color: AppColors.ink4),
                        ]),
                      ),
                    ),
                ]),
              ),
          ],
        ),
        );
      },
    );
  }
}

void _openMallUrl(BuildContext context, String name, String url) {
  if (url.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name 링크는 연동 준비 중이에요.')));
    return;
  }
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    '화천': '🎣', // 산천어
    '영천': '🔭', // 보현산 천문대
    '함양': '🌱', // 산삼
    '산청': '🍵', // 동의보감·한방
    '고성': '🦕', // 공룡
    '안동': '🎭', // 하회탈
    '서천': '🐦', // 철새
    '태안': '🌅', // 해변
    '장흥': '🌲', // 편백숲
  };
  return map[regionName] ?? '📍';
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(children: [
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: AppColors.p50, shape: BoxShape.circle),
          child: const Icon(Icons.shopping_bag_outlined, size: 26, color: AppColors.p600),
        ),
        const SizedBox(height: 12),
        const Text('아직 정산 신청한 여행이 없어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
        const SizedBox(height: 6),
        const Text('여행을 다녀와 정산까지 마치면\n환급금 쓸 곳을 여기 모아드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5)),
        const SizedBox(height: 6),
      ]),
    );
  }
}

class _RegionUsageCard extends StatelessWidget {
  const _RegionUsageCard({required this.trip, required this.malls, this.localCurrencyUrl});
  final TripSummary trip;
  final List<OnlineMallItem> malls;
  final String? localCurrencyUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          EmojiBox(_regionEmoji(trip.regionName), size: 46, fontSize: 23),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.regionName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 2),
            // 날짜는 붙이지 않는다. 여기에 여행 종료일을 적어 두어 신청일로 읽혔다.
            const Text('정산 신청 완료',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlineButton('지역화폐 앱',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => _openMallUrl(
                    context, '${trip.regionName} 지역화폐 앱', localCurrencyUrl ?? '')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlineButton('온라인몰',
                icon: Icons.shopping_bag_outlined,
                onTap: () => _openMallUrl(
                    context,
                    '${trip.regionName} 온라인몰',
                    malls.isNotEmpty ? malls.first.mallUrl : '')),
          ),
        ]),
        const SizedBox(height: 10),
        OutlineButton('${trip.regionName} 지역화폐 가맹점 지도',
            icon: Icons.place_outlined,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MerchantMapScreen(regionId: trip.regionId, regionName: trip.regionName)))),
      ]),
    );
  }
}
