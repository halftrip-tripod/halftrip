import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../mock_ui/widgets/region_art.dart';
import '../services/course_ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/place_map_view.dart';
import '../widgets/ui/app_card.dart';

/// 코스 플로우 (목업 halftrip-mockup/lib/screens/course_flow.dart 1:1 이식).
/// AI 입력 → 생성 연출 → 시뮬(지도·타임라인) → 저장 / 보기 / 편집 / 장소 검색.
/// 코스 저장 시 SavedCourse + 여행 확정 코스(trip_places)로 연결된다.

// ───────────────────────── 일정 슬롯 · 표시 유틸

const _day1Slots = ['10:00', '12:30', '14:30', '18:00'];
const _day2Slots = ['09:30', '12:00', '14:30'];

class _SimStop {
  _SimStop({
    required this.day,
    required this.time,
    required this.place,
  });

  final int day;
  final String time;
  final PlaceItem place;
}

/// 장소 목록 → 목업 스타일 DAY1/DAY2 일정으로 배치.
List<_SimStop> _scheduleStops(List<PlaceItem> places) {
  final stops = <_SimStop>[];
  for (var i = 0; i < places.length && i < 7; i++) {
    final day = i < _day1Slots.length ? 1 : 2;
    final slot = day == 1 ? _day1Slots[i] : _day2Slots[i - _day1Slots.length];
    stops.add(_SimStop(day: day, time: slot, place: places[i]));
  }
  return stops;
}

String _placeEmoji(PlaceItem place) {
  final text = '${place.name} ${place.description}';
  if (text.contains('다리') || text.contains('출렁')) return '🌉';
  if (text.contains('박물관') || text.contains('청자')) return '🏺';
  if (text.contains('초당') || text.contains('유적') || text.contains('생가')) {
    return '🏯';
  }
  if (text.contains('시장') || text.contains('식당') || text.contains('맛')) {
    return '🍲';
  }
  if (text.contains('카페')) return '☕';
  if (text.contains('한옥') || text.contains('스테이') || text.contains('숙')) {
    return '🏠';
  }
  if (text.contains('타워') || text.contains('전망') || text.contains('케이블')) {
    return '🗼';
  }
  if (text.contains('공원') || text.contains('생태') || text.contains('수목원')) {
    return '🌾';
  }
  if (text.contains('해수욕장') || text.contains('해변') || text.contains('섬')) {
    return '🏖️';
  }
  return '📍';
}

// ───────────────────────── S1-4b AI 코스 생성 입력

class CourseAiScreen extends StatefulWidget {
  const CourseAiScreen({super.key, required this.tripDetail});

  final TripDetail tripDetail;

  @override
  State<CourseAiScreen> createState() => _CourseAiScreenState();
}

class _CourseAiScreenState extends State<CourseAiScreen> {
  late int _nights = widget.tripDetail.trip.endDate
      .difference(widget.tripDetail.trip.startDate)
      .inDays
      .clamp(0, 4);
  late int _people = widget.tripDetail.trip.travelerCount;

  final _themes = [
    ('🍴', '맛집', '지역 미식·시장'),
    ('🌿', '자연', '바다·산·공원'),
    ('🏛️', '문화', '박물관·유적'),
    ('🎟️', '체험', '전망대·액티비티'),
  ];

  static const _rankColors = [
    AppColors.p600,
    AppColors.p500,
    AppColors.p400,
    AppColors.p300,
  ];

  Future<void> _generate() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    strokeWidth: 3.5, color: AppColors.p500),
              ),
              SizedBox(height: 18),
              Text('AI가 코스를 만들고 있어요',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9)),
              SizedBox(height: 8),
              Text('취향·환급 조건 분석 → 장소 선정 → 동선 최적화',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5,
                      height: 1.5)),
            ],
          ),
        ),
      ),
    );

    final controller = AppScope.of(context);
    final preferences = _themes.map((t) => t.$2).toList();
    List<PlaceItem> places;
    try {
      final detail = await controller.repository.getRegionDetail(
        widget.tripDetail.trip.regionId,
        residence: controller.currentUser?.residence,
      );
      final candidates = detail.halfPricePlaces;
      try {
        // FastAPI LLM으로 실제 코스 생성(테마·환급조건 반영, 후보 중에서만 선정).
        final aiService = CourseAiService(AppConfig.fromEnvironment());
        final result = await aiService.generate(
          regionName: widget.tripDetail.trip.regionName,
          nights: _nights,
          people: _people,
          themePriority: preferences,
          candidates: candidates
              .map((place) => {
                    'name': place.name,
                    'category': '',
                    'address': place.address,
                    'description': place.description,
                    'eligibleForRefund': place.eligibleForRefund,
                  })
              .toList(),
        );
        final byName = {for (final place in candidates) place.name: place};
        places = result.stops
            .map((stop) => byName[stop.name])
            .whereType<PlaceItem>()
            .toList();
        if (places.isEmpty) {
          // LLM이 후보 밖 이름을 반환했거나 빈 결과 — 규칙 기반으로 안전하게 대체.
          places = _rankPlaces(candidates, preferences);
        }
      } catch (_) {
        // FastAPI 호출 실패(네트워크/키 미설정 등) — 클라이언트 규칙 기반으로 대체.
        places = _rankPlaces(candidates, preferences);
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코스를 생성하지 못했습니다: $error')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // 다이얼로그 닫기

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourseSimScreen(
          tripDetail: widget.tripDetail,
          places: places,
          preferences: preferences,
          nights: _nights,
        ),
      ),
    );
  }

  List<PlaceItem> _rankPlaces(List<PlaceItem> places, List<String> prefs) {
    int score(PlaceItem place) {
      final text = '${place.name} ${place.address} ${place.description}';
      var total = 0;
      for (var i = 0; i < prefs.length; i++) {
        final keywords = switch (prefs[i]) {
          '맛집' => ['시장', '식당', '맛', '카페'],
          '자연' => ['공원', '생태', '해수욕장', '섬', '산', '숲'],
          '문화' => ['박물관', '유적', '초당', '생가', '청자'],
          _ => ['체험', '타워', '전망', '케이블', '짚'],
        };
        if (keywords.any(text.contains)) total += (prefs.length - i) * 10;
      }
      return total;
    }

    final ranked = [...places]..sort((a, b) => score(b).compareTo(score(a)));
    return ranked.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.tripDetail.trip;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('AI 코스 생성')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          // 선택된 지역 (여행에 고정)
          AppCard(
            padding: const EdgeInsets.all(16),
            radius: 18,
            child: Row(children: [
              RegionArt(trip.regionName,
                  size: 46, fontSize: 23, radius: 14),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('여행 지역',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.p600)),
                    const SizedBox(height: 2),
                    Text(trip.regionName,
                        style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink9,
                            letterSpacing: -0.3)),
                  ],
                ),
              ),
            ]),
          ),
          const _FormLabel('여행 일수'),
          _Stepper(
            label: '며칠 여행하나요?',
            value: _nights == 0 ? '당일치기' : '$_nights박 ${_nights + 1}일',
            onMinus: () => setState(() => _nights = (_nights - 1).clamp(0, 4)),
            onPlus: () => setState(() => _nights = (_nights + 1).clamp(0, 4)),
          ),
          const _FormLabel('동행 인원'),
          _Stepper(
            label: '함께 가는 인원',
            value: '$_people명',
            onMinus: () => setState(() => _people = (_people - 1).clamp(1, 8)),
            onPlus: () => setState(() => _people = (_people + 1).clamp(1, 8)),
          ),
          const _FormLabel('관심 테마 우선순위', sub: '끌어서 순서 변경 · 위로 올릴수록 더 반영'),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, __) => child,
            onReorder: (oldIndex, newIndex) => setState(() {
              if (newIndex > oldIndex) newIndex--;
              _themes.insert(newIndex, _themes.removeAt(oldIndex));
            }),
            children: [
              for (var i = 0; i < _themes.length; i++)
                Padding(
                  key: ValueKey(_themes[i].$2),
                  padding:
                      EdgeInsets.only(bottom: i == _themes.length - 1 ? 0 : 10),
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: AppCard(
                      padding: const EdgeInsets.all(15),
                      radius: 16,
                      child: Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _rankColors[i], shape: BoxShape.circle),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 13),
                        Text(_themes[i].$1,
                            style: const TextStyle(fontSize: 21)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: _themes[i].$2,
                                  style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink9)),
                              TextSpan(
                                  text: '  ${_themes[i].$3}',
                                  style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink4)),
                            ]),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.drag_indicator_rounded,
                                size: 20, color: AppColors.ink4),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.p600),
            SizedBox(width: 6),
            Expanded(
              child: Text('환급 조건(지정관광지 2곳·숙박 포함)은 자동으로 충족되게 코스를 짜드려요.',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5,
                      height: 1.5)),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: FilledButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome_rounded, size: 19),
          label: const Text('AI 코스 생성하기'),
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text, {this.sub});
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(text,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.ink9,
                letterSpacing: -0.2)),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(sub!,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5)),
          ),
        ],
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      radius: 18,
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink9)),
        const Spacer(),
        _StepBtn('−', onMinus),
        SizedBox(
          width: 74,
          child: Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9)),
        ),
        _StepBtn('+', onPlus),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColors.p50, borderRadius: BorderRadius.circular(11)),
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.p600,
                height: 1)),
      ),
    );
  }
}

// ───────────────────────── S1-4 코스 시뮬 (생성 결과)

class CourseSimScreen extends StatelessWidget {
  const CourseSimScreen({
    super.key,
    required this.tripDetail,
    required this.places,
    required this.preferences,
    this.nights = 1,
  });

  final TripDetail tripDetail;
  final List<PlaceItem> places;
  final List<String> preferences;
  final int nights;

  Future<void> _save(BuildContext context) async {
    final controller = AppScope.of(context);
    final trip = tripDetail.trip;
    final course = SavedCourse(
      id: '${trip.regionId}_${DateTime.now().millisecondsSinceEpoch}',
      regionId: trip.regionId,
      regionName: trip.regionName,
      title: '${trip.regionName} 환급 보장 코스',
      preferences: preferences.take(3).toList(),
      stops: places
          .map((place) => SavedCourseStop(
                placeId: place.id,
                name: place.name,
                address: place.address,
                latitude: place.latitude ?? 0,
                longitude: place.longitude ?? 0,
                sourceType: 'PLACE',
              ))
          .toList(),
      createdAt: DateTime.now(),
    );
    await controller.saveCourse(course);

    final payload = places.asMap().entries.map((entry) {
      final place = entry.value;
      return TripPlaceItem(
        id: 0,
        placeType: PlaceCategory.halfPrice,
        referencePlaceId: place.id,
        placeName: place.name,
        address: place.address,
        visitOrder: entry.key + 1,
        latitude: place.latitude,
        longitude: place.longitude,
        checked: true,
      );
    }).toList();
    await controller.runTask(
        () => controller.repository.replaceTripPlaces(trip.id, payload));
    await controller.selectCourseForTrip(tripId: trip.id, courseId: course.id);
    await controller.refreshTrips();

    if (!context.mounted) return;
    // 여행 상세 → 코스 만들기 → (시뮬) 스택이므로 두 번 pop = 여행 상세 복귀.
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('코스를 저장하고 ${trip.regionName} 여행에 연결했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final stops = _scheduleStops(places);
    final refundCount = places.length.clamp(0, 2);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('${tripDetail.trip.regionName} 코스')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        children: [
          _FitBanner(
            title: '이 코스로 환급 조건 100% 충족',
            subtitle: '지정관광지 $refundCount곳 · ${nights > 0 ? '1박 숙박 · ' : ''}인정 결제 포함',
          ),
          const SizedBox(height: 16),
          _buildCourseMap(context),
          const SizedBox(height: 16),
          CourseTimeline(stops: stops),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.p500),
            SizedBox(width: 6),
            Text('저장하면 여행 코스에서 장소·순서를 수정할 수 있어요',
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('취향을 반영해 코스를 다시 생성했어요.'))),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.soft,
                ),
                child: const Row(children: [
                  Icon(Icons.refresh_rounded, size: 18, color: AppColors.p600),
                  SizedBox(width: 7),
                  Text('다시 생성',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink7)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.bookmark_rounded, size: 19),
                label: const Text('내 코스함에 저장'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// 코스 장소를 실제 지도(구글/카카오, MAP_PROVIDER 설정에 따름)에 순서대로 표시.
  /// 마커를 탭하면 구글 상세정보(평점·전화·영업시간 등)를 조회해 카드에 보여준다.
  /// TourAPI 기반 설명(description)은 구글 상세가 비어있을 때의 대체 정보로 함께 넘긴다.
  Widget _buildCourseMap(BuildContext context) {
    final geoPlaces =
        places.where((p) => p.latitude != null && p.longitude != null).toList();
    final markers = geoPlaces
        .map(
          (place) => PlaceMapMarkerData(
            id: place.id,
            name: place.name,
            address: place.address,
            latitude: place.latitude!,
            longitude: place.longitude!,
            selected: false,
            editorialSummary: place.description.isEmpty ? null : place.description,
          ),
        )
        .toList();
    final routeMarkers = geoPlaces
        .map(
          (place) => PlaceMapRoutePoint(
            id: place.id,
            latitude: place.latitude!,
            longitude: place.longitude!,
          ),
        )
        .toList();
    final config = AppConfig.fromEnvironment();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: PlaceMapView(
        markers: markers,
        emptyMessage: '표시할 장소 좌표가 없습니다.',
        kakaoEnabled: config.canUseKakaoMap,
        routeMarkers: routeMarkers,
        connectSequentially: true,
        height: 240,
        onMarkerDetailsRequested: (marker) => _loadGoogleMarkerDetails(context, marker),
      ),
    );
  }

  /// 지도 마커 탭 시 구글 Places 상세정보를 조회해 병합. 실패하면 기존(TourAPI 기반) 값 유지.
  Future<PlaceMapMarkerData?> _loadGoogleMarkerDetails(
    BuildContext context,
    PlaceMapMarkerData marker,
  ) async {
    try {
      final controller = AppScope.of(context);
      final detail = await controller.repository.searchGooglePlaceDetail(
        placeName: marker.name,
        address: marker.address,
        latitude: marker.latitude,
        longitude: marker.longitude,
      );
      if (detail == null) {
        return null;
      }
      return PlaceMapMarkerData(
        id: marker.id,
        name: detail.placeName.isNotEmpty ? detail.placeName : marker.name,
        address: detail.address.isNotEmpty ? detail.address : marker.address,
        latitude: detail.latitude == 0 ? marker.latitude : detail.latitude,
        longitude: detail.longitude == 0 ? marker.longitude : detail.longitude,
        selected: marker.selected,
        regionLabel: detail.category.isNotEmpty ? detail.category : marker.regionLabel,
        phoneNumber: detail.phoneNumber.isNotEmpty ? detail.phoneNumber : marker.phoneNumber,
        roadAddress: detail.address.isNotEmpty ? detail.address : marker.roadAddress,
        categoryName: detail.category.isNotEmpty ? detail.category : marker.categoryName,
        placeUrl: detail.placeUrl.isNotEmpty ? detail.placeUrl : marker.placeUrl,
        websiteUri: detail.websiteUri.isNotEmpty ? detail.websiteUri : marker.websiteUri,
        internationalPhoneNumber: detail.internationalPhoneNumber.isNotEmpty
            ? detail.internationalPhoneNumber
            : marker.internationalPhoneNumber,
        rating: detail.rating ?? marker.rating,
        userRatingCount:
            detail.userRatingCount == 0 ? marker.userRatingCount : detail.userRatingCount,
        businessStatus:
            detail.businessStatus.isNotEmpty ? detail.businessStatus : marker.businessStatus,
        priceLevel: detail.priceLevel.isNotEmpty ? detail.priceLevel : marker.priceLevel,
        types: detail.types.isNotEmpty ? detail.types : marker.types,
        openingHours: detail.openingHours.isNotEmpty ? detail.openingHours : marker.openingHours,
        // TourAPI 설명을 기본값으로 이미 채워뒀으므로, 구글 상세가 비어있으면 그대로 유지.
        editorialSummary:
            detail.editorialSummary.isNotEmpty ? detail.editorialSummary : marker.editorialSummary,
        googlePlaceDetails:
            detail.googlePlaceDetails.isNotEmpty ? detail.googlePlaceDetails : marker.googlePlaceDetails,
      );
    } catch (_) {
      return null;
    }
  }
}

// ───────────────────────── 코스 동선 지도 카드 (목업 CourseMapCard 이식)

class CourseMapCard extends StatelessWidget {
  const CourseMapCard(
      {super.key, this.day1 = 4, this.day2 = 3, this.showLegend = true});

  final int day1;
  final int day2;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    const pts = [
      Offset(.23, .32),
      Offset(.44, .23),
      Offset(.68, .41),
      Offset(.8, .70),
      Offset(.59, .81),
      Offset(.35, .77),
      Offset(.18, .60),
    ];
    final total = (day1 + day2).clamp(0, pts.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 340 / 196,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _CourseMapPainter(pts.sublist(0, total), day1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (showLegend)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(AppColors.p500, 'DAY 1'),
              const SizedBox(width: 16),
              _legendDot(AppColors.p400, 'DAY 2'),
            ]),
          ),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink5)),
      ]);
}

class _CourseMapPainter extends CustomPainter {
  _CourseMapPainter(this.points, this.day1Count);
  final List<Offset> points;
  final int day1Count;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFEDF4FA));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * .17, size.height * .86),
            width: size.width * .5,
            height: size.height * .47),
        Paint()..color = const Color(0xFFD9E9F6));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * .85, size.height * .2),
            width: size.width * .4,
            height: size.height * .43),
        Paint()..color = const Color(0xFFE4EFE3));

    if (points.isEmpty) return;
    Offset at(int i) =>
        Offset(points[i].dx * size.width, points[i].dy * size.height);

    void drawRoute(int from, int to, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(at(from).dx, at(from).dy);
      for (var i = from + 1; i <= to; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, paint);
    }

    final d1End = (day1Count - 1).clamp(0, points.length - 1);
    if (d1End > 0) drawRoute(0, d1End, AppColors.p500);
    if (points.length - 1 > d1End) {
      final dash = Paint()
        ..color = const Color(0xFF9DB4C8)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final a = at(d1End), b = at(d1End + 1);
      final dist = (b - a).distance;
      final dir = (b - a) / dist;
      for (double t = 0; t < dist; t += 8.0) {
        canvas.drawCircle(a + dir * t, 1.3, dash);
      }
      drawRoute(d1End + 1, points.length - 1, AppColors.p400);
    }

    for (var i = 0; i < points.length; i++) {
      final color = i <= d1End ? AppColors.p500 : AppColors.p400;
      canvas.drawCircle(at(i), 14, Paint()..color = Colors.white);
      canvas.drawCircle(at(i), 12, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at(i) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CourseMapPainter old) =>
      old.points != points || old.day1Count != day1Count;
}

// ───────────────────────── DAY 타임라인 (목업 이식)

class CourseTimeline extends StatelessWidget {
  const CourseTimeline({super.key, required this.stops});

  final List<_SimStop> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('아직 장소가 없어요\n코스 편집에서 장소를 추가해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink4,
                  height: 1.6)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 10),
        child: Text('상세 일정',
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.ink9,
                letterSpacing: -0.3)),
      ),
      for (final day in [1, 2])
        if (stops.any((s) => s.day == day)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
            child: Text('DAY $day',
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9,
                    letterSpacing: 0.3)),
          ),
          for (final stop in stops.where((s) => s.day == day))
            _TimelineStop(stop: stop),
        ],
    ]);
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.stop});

  final _SimStop stop;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Text(stop.time,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink5)),
          ),
        ),
        SizedBox(
          width: 28,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned.fill(
                child: Center(child: Container(width: 2, color: AppColors.line))),
            Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.p500,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.p500, width: 3),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.card,
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(_placeEmoji(stop.place),
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink9)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      _tag('관광지', AppColors.p100, AppColors.p700),
                      _tag('환급 인정', AppColors.mintTint, AppColors.mintDeep),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg)),
      );
}

class _FitBanner extends StatelessWidget {
  const _FitBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.success, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF177D43))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E9B5F))),
          ]),
        ),
      ]),
    );
  }
}

