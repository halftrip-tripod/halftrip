import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/place_map_view.dart';
import '../widgets/ui/app_card.dart';

/// 지역화폐 가맹점 지도 — 디자인: 목업 MerchantMapScreen.
/// 지역 상세 API의 가맹점 실데이터 + 지도 + 카테고리 필터.
class MerchantMapScreen extends StatefulWidget {
  const MerchantMapScreen({
    super.key,
    required this.regionId,
    required this.regionName,
  });

  final int regionId;
  final String regionName;

  @override
  State<MerchantMapScreen> createState() => _MerchantMapScreenState();
}

class _MerchantMapScreenState extends State<MerchantMapScreen> {
  Future<RegionDetail>? _future;
  bool _initialized = false;
  int _category = 0;
  int? _highlightedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final controller = AppScope.of(context);
    _future = controller.repository.getRegionDetail(
      widget.regionId,
      residence: controller.currentUser?.residence,
    );
    _initialized = true;
  }

  List<String> _categories(List<MerchantItem> merchants) =>
      ['전체', ...{for (final m in merchants) m.category}];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('${widget.regionName} 가맹점 지도')),
      body: FutureBuilder<RegionDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final merchants = snapshot.data!.merchants;
          final categories = _categories(merchants);
          final visible = merchants
              .where((m) =>
                  _category == 0 || m.category == categories[_category])
              .toList();
          final markers = visible
              .where((m) => m.latitude != null && m.longitude != null)
              .map((m) => PlaceMapMarkerData(
                    id: m.id,
                    name: m.name,
                    address: m.address,
                    latitude: m.latitude!,
                    longitude: m.longitude!,
                    selected: true,
                    regionLabel: m.category,
                  ))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              // 카테고리 칩
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _category = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == _category ? AppColors.p500 : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: i == _category
                            ? const [
                                BoxShadow(
                                    color: Color(0x400EA5E9),
                                    blurRadius: 10,
                                    offset: Offset(0, 4)),
                              ]
                            : AppShadows.soft,
                      ),
                      child: Text(
                        categories[i],
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color:
                              i == _category ? Colors.white : AppColors.ink5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // 지도
              AppCard(
                padding: const EdgeInsets.all(8),
                radius: 20,
                child: PlaceMapView(
                  markers: markers,
                  emptyMessage: '표시할 가맹점이 없어요.',
                  kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                  highlightedMarkerId: _highlightedId,
                  onMarkerTap: (id) => setState(() => _highlightedId = id),
                  height: 300,
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Row(children: [
                  const Text('지역화폐 가맹점',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink5)),
                  const Spacer(),
                  Text('${visible.length}곳',
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink4)),
                ]),
              ),
              for (final merchant in visible)
                _MerchantRow(
                  merchant: merchant,
                  highlighted: merchant.id == _highlightedId,
                  onTap: () => setState(() => _highlightedId = merchant.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.merchant,
    required this.highlighted,
    required this.onTap,
  });

  final MerchantItem merchant;
  final bool highlighted;
  final VoidCallback onTap;

  String get _emoji {
    final text = '${merchant.name} ${merchant.category}';
    if (text.contains('시장')) return '🧺';
    if (text.contains('카페') || text.contains('디저트')) return '☕';
    if (text.contains('숙') || text.contains('스테이') || text.contains('펜션')) {
      return '🏠';
    }
    if (text.contains('마트') || text.contains('편의')) return '🛒';
    if (text.contains('식당') || text.contains('음식') || text.contains('한식')) {
      return '🍲';
    }
    return '🏪';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.p50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.soft,
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(_emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(merchant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9)),
              const SizedBox(height: 4),
              Text('${merchant.category} · ${merchant.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
