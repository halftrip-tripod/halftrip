import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/place_map_view.dart';
import '../widgets/ui/app_card.dart';

/// 지역화폐 가맹점 지도 — 디자인: 목업 MerchantMapScreen.
/// 지역 상세 API의 가맹점 실데이터 + 지도 + 카테고리 필터.

/// 통계청 세분류 category → 사용자용 대분류. 칩·아이콘·리스트가 공유한다.
/// (원문 나열 시 "육상 운송 및 파이프라인 운송업" 같은 칩 수십 개가 생기던 문제)
(String, String) merchantGroupOf(String name, String category) {
  final text = '$name $category';
  bool has(List<String> keys) => keys.any(text.contains);
  if (has(['카페', '커피', '디저트', '제과', '빵', '찻집'])) return ('카페·디저트', '☕');
  if (has(['식당', '음식', '한식', '중식', '일식', '양식', '분식', '치킨', '주점', '횟집', '고기', '피자', '족발', '국밥'])) {
    return ('음식점', '🍲');
  }
  if (has(['숙박', '펜션', '모텔', '호텔', '민박', '리조트', '스테이'])) return ('숙박', '🏠');
  if (has(['마트', '슈퍼', '편의', '상회', '수산', '정육', '청과', '농산', '시장'])) return ('쇼핑·마트', '🛒');
  if (has(['미용', '헤어', '이용', '뷰티', '네일', '피부', '세탁', '목욕', '안경', '약국', '의원', '병원'])) {
    return ('미용·생활', '💇');
  }
  if (has(['레저', '낚시', '체험', '관광', '여행', '스포츠', '골프', '요트', '렌터', '대여'])) return ('레저·관광', '🎣');
  if (has(['꽃', '화훼', '문구', '서점', '의류', '패션', '잡화', '가구', '철물', '전자'])) return ('쇼핑·마트', '🛍️');
  return ('기타', '📍');
}

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

  List<String> _categories(List<MerchantItem> merchants) => [
        '전체',
        ...{for (final m in merchants) merchantGroupOf(m.name, m.category).$1},
      ];

  static const _maxMarkers = 250;
  PlaceMapViewport? _viewport;

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
                  _category == 0 ||
                  merchantGroupOf(m.name, m.category).$1 ==
                      categories[_category])
              .toList();
          // 수천 개를 한 번에 그리면 지도가 마커로 덮인다 — 현재 뷰포트 안에서
          // 중심 가까운 순으로 최대 250개만 렌더 (이동·줌 시 갱신).
          final geoAll = visible
              .where((m) => m.latitude != null && m.longitude != null)
              .toList();
          final vp = _viewport;
          var geo = vp == null
              ? geoAll
              : geoAll
                  .where((m) =>
                      m.latitude! >= vp.minLatitude &&
                      m.latitude! <= vp.maxLatitude &&
                      m.longitude! >= vp.minLongitude &&
                      m.longitude! <= vp.maxLongitude)
                  .toList();
          if (geo.length > _maxMarkers) {
            final cLat = vp?.centerLatitude ??
                geo.map((m) => m.latitude!).reduce((a, b) => a + b) /
                    geo.length;
            final cLng = vp?.centerLongitude ??
                geo.map((m) => m.longitude!).reduce((a, b) => a + b) /
                    geo.length;
            geo.sort((a, b) {
              double d(MerchantItem m) {
                final dy = m.latitude! - cLat;
                final dx = m.longitude! - cLng;
                return dy * dy + dx * dx;
              }
              return d(a).compareTo(d(b));
            });
            geo = geo.take(_maxMarkers).toList();
          }
          // 목록에서 고른 가맹점은 뷰포트 밖이거나 250개 제한에 밀려 마커가
          // 빠질 수 있다. 그러면 지도가 반응할 대상이 없으니 반드시 넣어 준다.
          final selected = geoAll.where((m) => m.id == _highlightedId).firstOrNull;
          if (selected != null && !geo.any((m) => m.id == selected.id)) {
            geo = [selected, ...geo];
          }
          final markers = geo
              .map((m) => PlaceMapMarkerData(
                    id: m.id,
                    name: m.name,
                    address: m.address,
                    latitude: m.latitude!,
                    longitude: m.longitude!,
                    selected: true,
                    regionLabel: merchantGroupOf(m.name, m.category).$1,
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
                  // 고른 가맹점이 바뀌면 지도를 새로 그려 그 핀 중심으로 옮기고
                  // 정보창을 연다. highlightedMarkerId는 initState에서만 읽혀서
                  // 리마운트 없이는 두 번째 선택부터 아무 반응이 없다.
                  key: ValueKey('merchant-map-$_highlightedId'),
                  markers: markers,
                  emptyMessage: '표시할 가맹점이 없어요.',
                  kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                  highlightedMarkerId: _highlightedId,
                  initialCenterLatitude: selected?.latitude,
                  initialCenterLongitude: selected?.longitude,
                  onMarkerTap: (id) => setState(() => _highlightedId = id),
                  onViewportChanged: (viewport) =>
                      setState(() => _viewport = viewport),
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

  String get _emoji => merchantGroupOf(merchant.name, merchant.category).$2;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.p50 : Colors.white,
          borderRadius: BorderRadius.circular(18),
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
