import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
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
  Future<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail})>? _future;
  MerchantMapSearchResult? _merchantMap;
  bool _initialized = false;
  _PlaceInfoMapTab _selectedTab = _PlaceInfoMapTab.designatedPlaces;
  int? _focusedMarkerId;
  PlaceMapViewport? _searchedViewport;
  PlaceMapViewport? _pendingViewport;
  bool _merchantInitialViewportQueued = false;
  final Map<int, MerchantDetailItem> _merchantDetailCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = _loadBundle();
    _initialized = true;
  }

  Future<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail})>
      _loadBundle() async {
    final controller = AppScope.of(context);
    final tripDetail = await controller.repository.getTripDetail(widget.tripId);
    final placeInfoDetail = await controller.repository.getPlaceInfoDetail(
      tripDetail.trip.regionId,
      residence: controller.currentUser?.residence,
    );
    return (
      tripDetail: tripDetail,
      placeInfoDetail: placeInfoDetail,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadBundle();
    });
  }

  Future<void> _loadInitialMerchantMap(int regionId) async {
    final seedMap = await AppScope.of(context).repository.getMerchantMap(
      regionId: regionId,
    );
    final merchantMap = await AppScope.of(context).repository.getMerchantMap(
      regionId: regionId,
      southLat: seedMap.centerLatitude - 0.008,
      northLat: seedMap.centerLatitude + 0.008,
      westLng: seedMap.centerLongitude - 0.008,
      eastLng: seedMap.centerLongitude + 0.008,
    );
    if (!mounted) return;
    setState(() {
      _merchantMap = merchantMap;
      _searchedViewport = PlaceMapViewport(
        centerLatitude: seedMap.centerLatitude,
        centerLongitude: seedMap.centerLongitude,
        minLatitude: seedMap.centerLatitude - 0.008,
        maxLatitude: seedMap.centerLatitude + 0.008,
        minLongitude: seedMap.centerLongitude - 0.008,
        maxLongitude: seedMap.centerLongitude + 0.008,
      );
    });
  }

  Future<void> _researchMerchants() async {
    final viewport = _pendingViewport;
    if (viewport == null) return;
    final tripDetail = await AppScope.of(context).repository.getTripDetail(
      widget.tripId,
    );
    final merchantMap = await AppScope.of(context).repository.getMerchantMap(
      regionId: tripDetail.trip.regionId,
      southLat: viewport.minLatitude,
      northLat: viewport.maxLatitude,
      westLng: viewport.minLongitude,
      eastLng: viewport.maxLongitude,
    );
    if (!mounted) return;
    setState(() {
      _searchedViewport = viewport;
      _pendingViewport = null;
      _focusedMarkerId = null;
      _merchantMap = merchantMap;
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
        SnackBar(content: Text('${place.name}을(를) 플래너에 추가했습니다.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}은(는) 이미 플래너에 있습니다.')),
    );
  }

  Future<void> _addMerchantToPlanner({
    required TripDetail tripDetail,
    required MerchantMarkerItem marker,
    required MerchantItem? fallback,
  }) async {
    final controller = AppScope.of(context);
    final detail = _merchantDetailCache[marker.id];

    final alreadyExists = tripDetail.selectedPlaces.any(
      (item) =>
          item.placeType == PlaceCategory.merchant &&
          item.referencePlaceId == marker.id,
    );

    if (!alreadyExists) {
      final resolvedName = detail?.kakaoPlaceName.isNotEmpty == true
          ? detail!.kakaoPlaceName
          : detail?.storeName.isNotEmpty == true
              ? detail!.storeName
              : fallback?.kakaoPlaceName.isNotEmpty == true
                  ? fallback!.kakaoPlaceName
                  : fallback?.name ?? '가맹점';

      final resolvedAddress = detail?.kakaoRoadAddress.isNotEmpty == true
          ? detail!.kakaoRoadAddress
          : detail?.roadAddress.isNotEmpty == true
              ? detail!.roadAddress
              : fallback?.kakaoRoadAddress.isNotEmpty == true
                  ? fallback!.kakaoRoadAddress
                  : fallback?.address ?? '주소 정보 없음';

      final payload = [
        ...tripDetail.selectedPlaces,
        TripPlaceItem(
          id: 0,
          placeType: PlaceCategory.merchant,
          referencePlaceId: marker.id,
          placeName: resolvedName,
          address: resolvedAddress,
          visitOrder: _nextVisitOrder(tripDetail),
          latitude: marker.latitude,
          longitude: marker.longitude,
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
        SnackBar(content: Text('$resolvedName을(를) 플래너에 추가했습니다.')),
      );
      return;
    }

    final displayName = detail?.storeName ?? fallback?.name ?? '가맹점';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName은(는) 이미 플래너에 있습니다.')),
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

  List<PlaceMapMarkerData> _buildMerchantMarkers({
    required String regionName,
    required List<MerchantMarkerItem> markers,
    required List<TripPlaceItem> selectedPlaces,
    required Map<int, MerchantItem> fallbackMerchants,
  }) {
    return markers.map((marker) {
      final detail = _merchantDetailCache[marker.id];
      final fallback = fallbackMerchants[marker.id];
      final displayName = detail?.kakaoPlaceName.isNotEmpty == true
          ? detail!.kakaoPlaceName
          : detail?.storeName.isNotEmpty == true
              ? detail!.storeName
              : fallback?.kakaoPlaceName.isNotEmpty == true
                  ? fallback!.kakaoPlaceName
                  : fallback?.name ?? '가맹점';
      final displayAddress = detail?.kakaoRoadAddress.isNotEmpty == true
          ? detail!.kakaoRoadAddress
          : detail?.roadAddress.isNotEmpty == true
              ? detail!.roadAddress
              : fallback?.kakaoRoadAddress.isNotEmpty == true
                  ? fallback!.kakaoRoadAddress
                  : fallback?.address ?? '상세 정보 조회 실패';

      return PlaceMapMarkerData(
        id: marker.id,
        name: displayName,
        address: displayAddress,
        latitude: marker.latitude,
        longitude: marker.longitude,
        selected: selectedPlaces.any(
          (item) =>
              item.placeType == PlaceCategory.merchant &&
              item.referencePlaceId == marker.id,
        ),
        regionLabel: regionName,
        actionLabel: '플래너에 추가',
        phoneNumber: detail?.kakaoPhone,
        roadAddress: detail?.kakaoRoadAddress ?? fallback?.kakaoRoadAddress,
        categoryName: detail?.kakaoCategory.isNotEmpty == true
            ? detail!.kakaoCategory
            : detail?.category ?? fallback?.category,
        placeUrl: detail?.kakaoPlaceUrl ?? fallback?.kakaoPlaceUrl,
      );
    }).toList();
  }

  Future<void> _loadMerchantDetail(
    int regionId,
    int merchantId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _merchantDetailCache.containsKey(merchantId)) return;
    try {
      final detail = await AppScope.of(context).repository.getMerchantDetail(
        regionId: regionId,
        merchantId: merchantId,
      );
      if (!mounted) return;
      setState(() {
        _merchantDetailCache[merchantId] = detail;
      });
      if (!detail.externalInfoAvailable && !forceRefresh) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _loadMerchantDetail(regionId, merchantId, forceRefresh: true);
        });
      }
    } catch (_) {
      // 상세 조회 실패는 허용하고 기본 마커 정보로 계속 진행합니다.
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
      child: FutureBuilder<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail})>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tripDetail = snapshot.data!.tripDetail;
          final placeInfoDetail = snapshot.data!.placeInfoDetail;
          final merchantMap = _merchantMap;
          final places = placeInfoDetail.halfPricePlaces
              .where((place) => place.latitude != null && place.longitude != null)
              .toList();
          final showingMerchants = _selectedTab == _PlaceInfoMapTab.merchants;

          final markers = showingMerchants
              ? _buildMerchantMarkers(
                  regionName: tripDetail.trip.regionName,
                  markers: merchantMap?.markers ?? const [],
                  selectedPlaces: tripDetail.selectedPlaces,
                  fallbackMerchants: const {},
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
                        final shouldLoadMerchant = tab == _PlaceInfoMapTab.merchants &&
                            _merchantMap == null;
                        setState(() {
                          _selectedTab = tab;
                          _focusedMarkerId = null;
                          if (tab == _PlaceInfoMapTab.merchants &&
                              _searchedViewport == null) {
                            _merchantInitialViewportQueued = false;
                          }
                        });
                        if (shouldLoadMerchant) {
                          _loadInitialMerchantMap(tripDetail.trip.regionId);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    if (showingMerchants) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '현재 ${merchantMap?.merchantCount ?? 0}개 가맹점',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: _hasPendingMerchantViewport()
                                  ? _researchMerchants
                                  : null,
                              child: const Text('이 지역 재검색'),
                            ),
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
                          final marker =
                              (merchantMap?.markers ?? const <MerchantMarkerItem>[])
                                  .cast<MerchantMarkerItem?>()
                                  .firstWhere(
                                    (item) => item?.id == markerId,
                                    orElse: () => null,
                                  );
                          if (marker == null) return;
                          await _addMerchantToPlanner(
                            tripDetail: tripDetail,
                            marker: marker,
                            fallback: null,
                          );
                          _loadMerchantDetail(tripDetail.trip.regionId, markerId);
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
                              if (_selectedTab == _PlaceInfoMapTab.merchants &&
                                  _searchedViewport == null &&
                                  !_merchantInitialViewportQueued) {
                                _merchantInitialViewportQueued = true;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted || _searchedViewport != null) {
                                    return;
                                  }
                                  _researchMerchants();
                                });
                              }
                            }
                          : null,
                      initialCenterLatitude: showingMerchants
                          ? merchantMap?.centerLatitude
                          : null,
                      initialCenterLongitude: showingMerchants
                          ? merchantMap?.centerLongitude
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
            '카카오맵 마커를 눌러 지정관광지와 지역화폐 가맹점을 보고, 플래너에 담아 여행 동선을 직접 구성해 보세요.',
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
