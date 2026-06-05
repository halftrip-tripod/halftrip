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
  Future<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail, MerchantMapSearchResult merchantMap})>? _future;
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

  Future<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail, MerchantMapSearchResult merchantMap})> _loadBundle({
    PlaceMapViewport? merchantViewport,
  }) async {
    final controller = AppScope.of(context);
    final tripDetail = await controller.repository.getTripDetail(widget.tripId);
    final placeInfoDetail = await controller.repository.getPlaceInfoDetail(
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
      placeInfoDetail: placeInfoDetail,
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
    if (viewport == null) return;
    setState(() {
      _searchedViewport = viewport;
      _pendingViewport = null;
      _focusedMarkerId = null;
      _future = _loadBundle(merchantViewport: viewport);
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
        SnackBar(content: Text('${place.name}Î•??åÎûò?àÏóê Ï∂îÍ??àÏäµ?àÎã§.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}?Ä ?¥Î? ?åÎûò?àÏóê ?¥Í≤® ?àÏäµ?àÎã§.')),
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
                  : fallback?.name ?? 'Í∞ÄÎßπÏ†ê';

      final resolvedAddress = detail?.kakaoRoadAddress.isNotEmpty == true
          ? detail!.kakaoRoadAddress
          : detail?.roadAddress.isNotEmpty == true
              ? detail!.roadAddress
              : fallback?.kakaoRoadAddress.isNotEmpty == true
                  ? fallback!.kakaoRoadAddress
                  : fallback?.address ?? 'Ï£ºÏÜå ?ïÎ≥¥ ?ÜÏùå';

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
        SnackBar(content: Text('$resolvedNameÎ•??åÎûò?àÏóê Ï∂îÍ??àÏäµ?àÎã§.')),
      );
      return;
    }

    final displayName = detail?.storeName ?? fallback?.name ?? 'Í∞ÄÎßπÏ†ê';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName?Ä ?¥Î? ?åÎûò?àÏóê ?¥Í≤® ?àÏäµ?àÎã§.')),
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
            actionLabel: '?åÎûò?àÏóê Ï∂îÍ?',
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
                  : fallback?.name ?? 'Í∞ÄÎßπÏ†ê';
      final displayAddress = detail?.kakaoRoadAddress.isNotEmpty == true
          ? detail!.kakaoRoadAddress
          : detail?.roadAddress.isNotEmpty == true
              ? detail!.roadAddress
              : fallback?.kakaoRoadAddress.isNotEmpty == true
                  ? fallback!.kakaoRoadAddress
                  : fallback?.address ?? '?ÅÏÑ∏ ?ïÎ≥¥ Ï°∞Ìöå ?§Ìå®';

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
        actionLabel: '?åÎûò?àÏóê Ï∂îÍ?',
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
      // Read ?§Ìå®???àÏö©. Write(?åÎûò??Ï∂îÍ?)??marker Í∏∞Î≥∏Í∞íÏúºÎ°?Í≥ÑÏÜç Í∞Ä?•Ìï¥????
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
      title: 'ÏßÅÏ†ë ÏΩîÏä§ ÎßåÎì§Í∏?,
      modeName: controller.modeName,
      child: FutureBuilder<({TripDetail tripDetail, PlaceInfoDetail placeInfoDetail, MerchantMapSearchResult merchantMap})>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tripDetail = snapshot.data!.tripDetail;
          final placeInfoDetail = snapshot.data!.placeInfoDetail;
          final merchantMap = snapshot.data!.merchantMap;
          final places = placeInfoDetail.halfPricePlaces
              .where((place) => place.latitude != null && place.longitude != null)
              .toList();
          final showingMerchants = _selectedTab == _PlaceInfoMapTab.merchants;

          final markers = showingMerchants
              ? _buildMerchantMarkers(
                  regionName: tripDetail.trip.regionName,
                  markers: merchantMap.markers,
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
                title: 'ÏßÄ?ÑÏóê???•ÏÜå Í≥†Î•¥Í∏?,
                subtitle: showingMerchants
                    ? 'Í∏∞Î≥∏?Ä ?úÏ≤≠/Íµ∞Ï≤≠ ??ÏßÄ??Ï§ëÏã¨ ?îÎ©¥?ºÎ°ú ?úÏûë?òÍ≥†, ÏßÄ?ÑÎ? ??∏¥ ??`??ÏßÄ???¨Í??????åÎ????åÎßå ?ÑÏû¨ ?îÎ©¥ ?àÏùò Í∞ÄÎßπÏ†ê???§Ïãú Î∂àÎü¨?µÎãà??'
                    : 'Ïπ¥Ïπ¥?§Îßµ ÎßàÏª§Î•??ÑÎ•¥Î©?ÏßÄ?ïÍ?Í¥ëÏ? ?ïÎ≥¥Í∞Ä ÏßÄ????Ïπ¥ÎìúÎ°??¥Î¶¨Í≥? Î∞îÎ°ú ?åÎûò?àÏóê Ï∂îÍ??????àÏñ¥??',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaceMapTabSwitcher(
                      selectedTab: _selectedTab,
                      onChanged: (tab) {
                        setState(() {
                          _selectedTab = tab;
                          _focusedMarkerId = null;
                          if (tab == _PlaceInfoMapTab.merchants &&
                              _searchedViewport == null) {
                            _merchantInitialViewportQueued = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (showingMerchants) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '«ˆ¿Á ${merchantMap.merchantCount}∞≥ ∞°∏Õ¡°',
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
                              child: const Text('¿Ã ¡ˆø™ ¿Á∞Àªˆ'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    PlaceMapView(
                      markers: markers,
                      emptyMessage: showingMerchants
                          ? '?úÏãú??ÏßÄ??ôî??Í∞ÄÎßπÏ†ê Ï¢åÌëúÍ∞Ä ?ÜÏäµ?àÎã§.'
                          : '?úÏãú??ÏßÄ?ïÍ?Í¥ëÏ? Ï¢åÌëúÍ∞Ä ?ÑÏßÅ ?ÜÏäµ?àÎã§.',
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
                          final marker = merchantMap.markers.cast<MerchantMarkerItem?>().firstWhere(
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
                          ? merchantMap.centerLatitude
                          : null,
                      initialCenterLongitude: showingMerchants
                          ? merchantMap.centerLongitude
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
                          '?åÎûò??Î≥¥Í∏∞${tripDetail.selectedPlaces.isNotEmpty ? ' (${tripDetail.selectedPlaces.length})' : ''}',
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
            'ÏßÅÏ†ë ÏΩîÏä§ ÎßåÎì§Í∏?,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ïπ¥Ïπ¥?§Îßµ ÎßàÏª§Î•??åÎü¨ ?êÌïò??Í¥ÄÍ¥ëÏ??Ä ÏßÄ??ôî??Í∞ÄÎßπÏ†ê??Î≥¥Í≥†, ?åÎûò?àÏóê ?¥ÏïÑ ?¨Ìñâ ?ôÏÑ†???ÑÏÑ±??Î≥¥ÏÑ∏??',
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
        buildTab(_PlaceInfoMapTab.designatedPlaces, 'ÏßÄ?ïÍ?Í¥ëÏ?'),
        const SizedBox(width: 10),
        buildTab(_PlaceInfoMapTab.merchants, 'ÏßÄ??ôî??Í∞ÄÎßπÏ†ê'),
      ],
    );
  }
}

String? _placePhotoAsset(String placeName) {
  const mapping = <String, String>{
    '?ÑÎèÑ?Ä??: 'assets/spot/wando/wandotower.jpg',
  };
  return mapping[placeName];
}
