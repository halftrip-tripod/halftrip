import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
import '../widgets/place_map_models.dart';
import '../widgets/place_map_view.dart';
import 'planner_screen.dart';

enum _PlaceInfoMapTab { designatedPlaces, merchants }

class PlaceInfoScreen extends StatefulWidget {
  const PlaceInfoScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<PlaceInfoScreen> createState() => _PlaceInfoScreenState();
}

class _PlaceInfoScreenState extends State<PlaceInfoScreen> {
  Future<({TripDetail tripDetail, RegionDetail regionDetail, MerchantMapSearchResult merchantMap})>? _future;
  bool _initialized = false;
  _PlaceInfoMapTab _selectedTab = _PlaceInfoMapTab.designatedPlaces;
  int? _focusedMarkerId;
  PlaceMapViewport? _searchedViewport;
  PlaceMapViewport? _pendingViewport;
  final Map<int, MerchantDetailItem> _merchantDetailCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = _loadBundle();
    _initialized = true;
  }

  Future<({TripDetail tripDetail, RegionDetail regionDetail, MerchantMapSearchResult merchantMap})> _loadBundle({
    PlaceMapViewport? merchantViewport,
  }) async {
    final controller = AppScope.of(context);
    final tripDetail = await controller.repository.getTripDetail(widget.tripId);
    final regionDetail = await controller.repository.getRegionDetail(
      tripDetail.trip.regionId,
      residence: controller.currentUser?.residence,
    );
    final merchantMap = await controller.repository.getMerchantMap(
      regionId: tripDetail.trip.regionId,
      southLat: merchantViewport?.minLatitude,
      northLat: merchantViewport?.maxLatitude,
      westLng: merchantViewport?.minLongitude,
      eastLng: merchantViewport?.maxLongitude,
    );
    return (
      tripDetail: tripDetail,
      regionDetail: regionDetail,
      merchantMap: merchantMap,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadBundle(merchantViewport: _searchedViewport);
    });
  }

  Future<void> _researchMerchants() async {
    final viewport = _pendingViewport;
    if (viewport == null) {
      return;
    }
    setState(() {
      _searchedViewport = viewport;
      _pendingViewport = null;
      _future = _loadBundle(merchantViewport: viewport);
      _focusedMarkerId = null;
    });
  }

  Future<void> _openPlanner() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlannerScreen(tripId: widget.tripId),
      ),
    );
  }

  int _nextVisitOrder(TripDetail tripDetail) {
    if (tripDetail.selectedPlaces.isEmpty) {
      return 1;
    }
    return tripDetail.selectedPlaces
            .map((item) => item.visitOrder)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> _addPlaceToPlanner(TripDetail tripDetail, PlaceItem place) async {
    final controller = AppScope.of(context);
    final alreadyExists = tripDetail.selectedPlaces.any(
      (item) =>
          item.placeType == PlaceCategory.halfPrice &&
          item.referencePlaceId == place.id,
    );

    if (!alreadyExists) {
      final payload = [
        ...tripDetail.selectedPlaces,
        TripPlaceItem(
          id: 0,
          placeType: PlaceCategory.halfPrice,
          referencePlaceId: place.id,
          placeName: place.name,
          address: place.address,
          visitOrder: _nextVisitOrder(tripDetail),
          latitude: place.latitude,
          longitude: place.longitude,
          checked: true,
        ),
      ];

      await controller.runTask(
        () => controller.repository.replaceTripPlaces(widget.tripId, payload),
      );
      await controller.refreshTrips();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${place.name}를 플래너에 추가했습니다.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}은 이미 플래너에 담겨 있습니다.')),
    );
  }

  Future<void> _addMerchantToPlanner(
    TripDetail tripDetail,
    MerchantDetailItem merchant,
  ) async {
    final controller = AppScope.of(context);
    final alreadyExists = tripDetail.selectedPlaces.any(
      (item) =>
          item.placeType == PlaceCategory.merchant &&
          item.referencePlaceId == merchant.id,
    );

    if (!alreadyExists) {
      final payload = [
        ...tripDetail.selectedPlaces,
        TripPlaceItem(
          id: 0,
          placeType: PlaceCategory.merchant,
          referencePlaceId: merchant.id,
          placeName: merchant.kakaoPlaceName.isNotEmpty
              ? merchant.kakaoPlaceName
              : merchant.storeName,
          address: merchant.kakaoRoadAddress.isNotEmpty
              ? merchant.kakaoRoadAddress
              : merchant.roadAddress,
          visitOrder: _nextVisitOrder(tripDetail),
          latitude: merchant.latitude,
          longitude: merchant.longitude,
          checked: true,
        ),
      ];

      await controller.runTask(
        () => controller.repository.replaceTripPlaces(widget.tripId, payload),
      );
      await controller.refreshTrips();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${merchant.name}를 플래너에 추가했습니다.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${merchant.name}은 이미 플래너에 담겨 있습니다.')),
    );
  }

  List<PlaceMapMarkerData> _buildPlaceMarkers(
    String regionName,
    List<PlaceItem> places,
    List<TripPlaceItem> selectedPlaces,
  ) {
    return places
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) => PlaceMapMarkerData(
            id: place.id,
            name: place.name,
            address: place.address,
            latitude: place.latitude!,
            longitude: place.longitude!,
            selected: selectedPlaces.any(
              (item) =>
                  item.placeType == PlaceCategory.halfPrice &&
                  item.referencePlaceId == place.id,
            ),
            regionLabel: regionName,
            imageAssetPath: _placePhotoAsset(place.name),
            actionLabel: '플래너에 추가',
          ),
        )
        .toList();
  }

  List<PlaceMapMarkerData> _buildMerchantMarkers(
    String regionName,
    List<MerchantMarkerItem> merchants,
    List<TripPlaceItem> selectedPlaces,
  ) {
    return merchants
        .map(
          (merchant) => PlaceMapMarkerData(
            id: merchant.id,
            name: _merchantDetailCache[merchant.id]?.kakaoPlaceName.isNotEmpty == true
                ? _merchantDetailCache[merchant.id]!.kakaoPlaceName
                : (_merchantDetailCache[merchant.id]?.storeName ?? '가맹점'),
            address: _merchantDetailCache[merchant.id]?.kakaoRoadAddress.isNotEmpty == true
                ? _merchantDetailCache[merchant.id]!.kakaoRoadAddress
                : (_merchantDetailCache[merchant.id]?.roadAddress ?? '상세 정보를 불러오는 중입니다.'),
            latitude: merchant.latitude,
            longitude: merchant.longitude,
            selected: selectedPlaces.any(
              (item) =>
                  item.placeType == PlaceCategory.merchant &&
                  item.referencePlaceId == merchant.id,
            ),
            regionLabel: regionName,
            actionLabel: '플래너에 추가',
            phoneNumber: _merchantDetailCache[merchant.id]?.kakaoPhone,
            roadAddress: _merchantDetailCache[merchant.id]?.kakaoRoadAddress,
            categoryName: _merchantDetailCache[merchant.id]?.kakaoCategory.isNotEmpty == true
                ? _merchantDetailCache[merchant.id]!.kakaoCategory
                : _merchantDetailCache[merchant.id]?.category,
            placeUrl: _merchantDetailCache[merchant.id]?.kakaoPlaceUrl,
          ),
        )
        .toList();
  }

  Future<void> _loadMerchantDetail(int regionId, int merchantId) async {
    if (_merchantDetailCache.containsKey(merchantId)) {
      return;
    }
    try {
      final detail = await AppScope.of(context).repository.getMerchantDetail(
        regionId: regionId,
        merchantId: merchantId,
      );
      if (!mounted) return;
      setState(() {
        _merchantDetailCache[merchantId] = detail;
      });
    } catch (_) {
      // Keep marker usable even if detail fetch fails.
    }
  }

  bool _hasPendingMerchantViewport() {
    final pending = _pendingViewport;
    final searched = _searchedViewport;
    if (pending == null) return false;
    if (searched == null) return true;
    return pending.minLatitude != searched.minLatitude ||
        pending.maxLatitude != searched.maxLatitude ||
        pending.minLongitude != searched.minLongitude ||
        pending.maxLongitude != searched.maxLongitude;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final config = AppConfig.fromEnvironment();

    return AppShell(
      title: '직접 코스 만들기',
      modeName: controller.modeName,
      child: FutureBuilder<({TripDetail tripDetail, RegionDetail regionDetail, MerchantMapSearchResult merchantMap})>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tripDetail = snapshot.data!.tripDetail;
          final regionDetail = snapshot.data!.regionDetail;
          final merchantMap = snapshot.data!.merchantMap;
          final places = regionDetail.halfPricePlaces
              .where((place) => place.latitude != null && place.longitude != null)
              .toList();
          final showingMerchants = _selectedTab == _PlaceInfoMapTab.merchants;

          final markers = showingMerchants
              ? _buildMerchantMarkers(
                  tripDetail.trip.regionName,
                  merchantMap.markers,
                  tripDetail.selectedPlaces,
                )
              : _buildPlaceMarkers(
                  tripDetail.trip.regionName,
                  places,
                  tripDetail.selectedPlaces,
                );

          final highlightedMarkerId = markers.any((item) => item.id == _focusedMarkerId)
              ? _focusedMarkerId
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _IntroCard(),
              const SizedBox(height: 16),
              SectionCard(
                title: '지도에서 장소 고르기',
                subtitle: showingMerchants
                    ? '기본은 시청/군청 등 지역 중심 화면으로 시작하고, 지도를 옮긴 뒤 `이 지역 재검색`을 눌렀을 때만 현재 화면 안의 가맹점을 다시 불러옵니다.'
                    : '카카오맵 마커를 누르면 지정관광지 정보가 지도 위 카드로 열리고, 바로 플래너에 추가할 수 있어요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaceMapTabSwitcher(
                      selectedTab: _selectedTab,
                      onChanged: (tab) {
                        setState(() {
                          _selectedTab = tab;
                          _focusedMarkerId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (showingMerchants) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '현재 ${merchantMap.merchantCount}개 가맹점',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF111827),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _hasPendingMerchantViewport()
                                ? _researchMerchants
                                : null,
                            child: const Text('이 지역 재검색'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    PlaceMapView(
                      markers: markers,
                      emptyMessage: showingMerchants
                          ? '표시할 지역화폐 가맹점 좌표가 없습니다.'
                          : '표시할 지정관광지 좌표가 아직 없습니다.',
                      kakaoEnabled: config.canUseKakaoMap,
                      highlightedMarkerId: highlightedMarkerId,
                      onMarkerTap: (markerId) {
                        setState(() {
                          _focusedMarkerId = markerId;
                        });
                        if (showingMerchants) {
                          _loadMerchantDetail(tripDetail.trip.regionId, markerId);
                        }
                      },
                      onMarkerDoubleTap: (markerId) {
                        setState(() {
                          _focusedMarkerId = markerId;
                        });
                        if (showingMerchants) {
                          _loadMerchantDetail(tripDetail.trip.regionId, markerId);
                        }
                      },
                      onMarkerAction: (markerId) async {
                        setState(() {
                          _focusedMarkerId = markerId;
                        });

                        if (showingMerchants) {
                          await _loadMerchantDetail(tripDetail.trip.regionId, markerId);
                          final selected = _merchantDetailCache[markerId];
                          if (selected == null) return;
                          await _addMerchantToPlanner(tripDetail, selected);
                        } else {
                          final selected = places.cast<PlaceItem?>().firstWhere(
                                (item) => item?.id == markerId,
                                orElse: () => null,
                              );
                          if (selected == null) return;
                          await _addPlaceToPlanner(tripDetail, selected);
                        }
                      },
                      onViewportChanged: showingMerchants
                          ? (viewport) {
                              setState(() {
                                _pendingViewport = viewport;
                              });
                            }
                          : null,
                      height: showingMerchants ? 430 : 500,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openPlanner,
                        icon: const Icon(Icons.route_rounded),
                        label: Text(
                          '플래너 보기${tripDetail.selectedPlaces.isNotEmpty ? ' (${tripDetail.selectedPlaces.length})' : ''}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7FBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '직접 코스 만들기',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '카카오맵 마커를 눌러 원하는 관광지와 지역화폐 가맹점을 보고, 플래너에 담아 여행 동선을 완성해 보세요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlaceMapTabSwitcher extends StatelessWidget {
  const _PlaceMapTabSwitcher({
    required this.selectedTab,
    required this.onChanged,
  });

  final _PlaceInfoMapTab selectedTab;
  final ValueChanged<_PlaceInfoMapTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget buildTab(_PlaceInfoMapTab tab, String label) {
      final selected = tab == selectedTab;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF16A34A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTab(_PlaceInfoMapTab.designatedPlaces, '지정관광지'),
        const SizedBox(width: 10),
        buildTab(_PlaceInfoMapTab.merchants, '지역화폐 가맹점'),
      ],
    );
  }
}

String? _placePhotoAsset(String placeName) {
  const mapping = <String, String>{
    '완도타워': 'assets/spot/wando/wandotower.jpg',
  };
  return mapping[placeName];
}
