import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../mock_ui/widgets/region_art.dart';
import '../theme/app_colors.dart';
import '../widgets/place_map_view.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';

/// 확정 코스 플래너 (S2-4) — 디자인: halftrip-design/course-edit.html
/// 지도 동선 + 방문 순서 편집(드래그·삭제). 실시간 저장 유지.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.tripId, this.title});

  /// 헤더 제목 — 지난여행 진입 등에서 '다녀온 코스'나 저장 코스명으로 덮어쓸 수 있다.
  final String? title;

  final int tripId;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  int? _highlightedPlaceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
    _initialized = true;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
    });
  }

  List<TripPlaceItem> _rebuildPlaces(List<TripPlaceItem> places) {
    return places.asMap().entries.map((entry) {
      final item = entry.value;
      return TripPlaceItem(
        id: item.id,
        placeType: item.placeType,
        referencePlaceId: item.referencePlaceId,
        placeName: item.placeName,
        address: item.address,
        visitOrder: entry.key + 1,
        latitude: item.latitude,
        longitude: item.longitude,
        checked: item.checked,
      );
    }).toList();
  }

  Future<void> _savePlaces(
    List<TripPlaceItem> places, {
    required TripSummary trip,
    required String snackBarMessage,
  }) async {
    final controller = AppScope.of(context);
    final payload = _rebuildPlaces(places);
    await controller.runTask(
      () => controller.repository.replaceTripPlaces(widget.tripId, payload),
    );
    await controller.syncTripPlacesToSelectedCourse(
      tripId: widget.tripId,
      regionId: trip.regionId,
      regionName: trip.regionName,
      places: payload,
    );
    await controller.refreshTrips();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackBarMessage)),
    );
    await _refresh();
  }

  Future<void> _removePlace(
    List<TripPlaceItem> places,
    TripPlaceItem target,
    TripSummary trip,
  ) async {
    final updated = places
        .where(
          (item) =>
              !(item.placeType == target.placeType &&
                  item.referencePlaceId == target.referencePlaceId),
        )
        .toList();

    if (_highlightedPlaceId == target.referencePlaceId) {
      setState(() {
        _highlightedPlaceId =
            updated.isEmpty ? null : updated.first.referencePlaceId;
      });
    }

    await _savePlaces(
      updated,
      trip: trip,
      snackBarMessage: '플래너에서 장소를 제거했어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.fromEnvironment();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.title ??
            AppScope.of(context)
                .selectedCourseForTrip(widget.tripId)
                ?.title ??
            '코스 플래너'),
      ),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tripDetail = snapshot.data!;
          final places = [...tripDetail.selectedPlaces]
            ..sort((a, b) => a.visitOrder.compareTo(b.visitOrder));

          final markers = places
              .where((item) => item.latitude != null && item.longitude != null)
              .map(
                (item) => PlaceMapMarkerData(
                  id: item.referencePlaceId,
                  name: item.placeName,
                  address: item.address,
                  latitude: item.latitude!,
                  longitude: item.longitude!,
                  selected: true,
                  regionLabel: tripDetail.trip.regionName,
                  imageAssetPath: _placePhotoAsset(item.placeName),
                ),
              )
              .toList();

          final routeMarkers = places
              .where((item) => item.latitude != null && item.longitude != null)
              .map(
                (item) => PlaceMapRoutePoint(
                  id: item.referencePlaceId,
                  latitude: item.latitude!,
                  longitude: item.longitude!,
                ),
              )
              .toList();

          final highlightedMarker = markers.cast<PlaceMapMarkerData?>().firstWhere(
                (item) => item?.id == _highlightedPlaceId,
                orElse: () => null,
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _PlannerHeaderCard(trip: tripDetail.trip, count: places.length),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                radius: 20,
                child: PlaceMapView(
                  markers: markers,
                  routeMarkers: routeMarkers,
                  connectSequentially: true,
                  emptyMessage: '아직 추가된 장소가 없어요. 코스 만들기에서 장소를 먼저 담아 주세요.',
                  kakaoEnabled: config.canUseKakaoMap,
                  highlightedMarkerId: highlightedMarker?.id,
                  onMarkerTap: (placeId) {
                    setState(() {
                      _highlightedPlaceId = placeId;
                    });
                  },
                  onMarkerDoubleTap: (placeId) {
                    setState(() {
                      _highlightedPlaceId = placeId;
                    });
                  },
                  height: 420,
                ),
              ),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  '방문 순서',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text(
                  '끌어서 순서를 바꾸면 지도 동선도 함께 바뀌어요.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5,
                  ),
                ),
              ),
              if (places.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '아직 추가된 일정이 없어요. 코스 만들기에서 장소를 먼저 담아 주세요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5,
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, _, __) => child,
                  itemCount: places.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }

                    final reordered = [...places];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);

                    await _savePlaces(
                      reordered,
                      trip: tripDetail.trip,
                      snackBarMessage: '방문 순서를 변경했어요.',
                    );
                  },
                  itemBuilder: (context, index) {
                    final item = places[index];
                    final isHighlighted =
                        item.referencePlaceId == _highlightedPlaceId;

                    return KeyedSubtree(
                      key: ValueKey(
                        '${item.placeType.wireName}_${item.referencePlaceId}',
                      ),
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _highlightedPlaceId = item.referencePlaceId;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isHighlighted ? AppColors.p50 : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppShadows.soft,
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Icon(Icons.drag_indicator_rounded,
                                        size: 20, color: AppColors.ink4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.p500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.placeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink9,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.ink5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removePlace(
                                      places, item, tripDetail.trip),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded,
                                        size: 18, color: AppColors.ink4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 플래너 헤더 — 지역·일정·장소/인원 메타 (디자인 tripcard 톤).
class _PlannerHeaderCard extends StatelessWidget {
  const _PlannerHeaderCard({
    required this.trip,
    required this.count,
  });

  final TripSummary trip;
  final int count;

  @override
  Widget build(BuildContext context) {
    final period =
        '${trip.startDate.month}.${trip.startDate.day} ~ ${trip.endDate.month}.${trip.endDate.day}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RegionArt(trip.regionName,
                  size: 48, fontSize: 24, radius: 15),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.regionName} 여행 동선',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink9,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$period · ${trip.travelerCount}명',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5,
                      ),
                    ),
                  ],
                ),
              ),
              Pill('$count곳'),
            ],
          ),
        ],
      ),
    );
  }
}

String? _placePhotoAsset(String placeName) {
  const mapping = <String, String>{
    '완도타워': 'assets/spot/wando/wandotower.jpg',
  };
  return mapping[placeName];
}

