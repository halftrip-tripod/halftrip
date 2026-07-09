import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui/pill.dart';
import '../widgets/place_map_view.dart';

enum CourseBuildMode { ai, manual }

class RegionCourseBuilderScreen extends StatefulWidget {
  const RegionCourseBuilderScreen({
    super.key,
    required this.regionId,
    required this.regionName,
    this.initialCourse,
    this.tripId,
    this.initialTripPlaces,
    this.initialMode = CourseBuildMode.ai,
  });

  final int regionId;
  final String regionName;
  final SavedCourse? initialCourse;
  final int? tripId;
  final List<TripPlaceItem>? initialTripPlaces;
  final CourseBuildMode initialMode;

  @override
  State<RegionCourseBuilderScreen> createState() =>
      _RegionCourseBuilderScreenState();
}

class _RegionCourseBuilderScreenState extends State<RegionCourseBuilderScreen> {
  static const _preferenceOptions = <String>[
    '자연',
    '힐링',
    '체험',
    '문화',
    '맛집',
    '사진',
  ];

  Future<RegionDetail>? _future;
  bool _initialized = false;
  late CourseBuildMode _mode;
  late List<String> _preferences;
  late List<SavedCourseStop> _plannerStops;
  int? _highlightedPlaceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _mode = widget.initialMode;
    _preferences = widget.initialCourse?.preferences.toList() ??
        [..._preferenceOptions];
    _plannerStops = widget.initialCourse?.stops.toList() ??
        (widget.initialTripPlaces ?? const <TripPlaceItem>[])
            .map(
              (item) => SavedCourseStop(
                placeId: item.referencePlaceId,
                name: item.placeName,
                address: item.address,
                latitude: item.latitude ?? 0,
                longitude: item.longitude ?? 0,
                sourceType: item.placeType.wireName,
              ),
            )
            .toList();
    _future = AppScope.of(context).repository.getRegionDetail(
      widget.regionId,
      residence: AppScope.of(context).currentUser?.residence,
    );
    _initialized = true;
  }

  List<PlaceMapMarkerData> _buildMarkers(RegionDetail detail) {
    return detail.halfPricePlaces
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) => PlaceMapMarkerData(
            id: place.id,
            name: place.name,
            address: place.address,
            latitude: place.latitude!,
            longitude: place.longitude!,
            selected: _plannerStops.any((item) => item.placeId == place.id),
          ),
        )
        .toList();
  }

  void _addOrRemoveStop(PlaceItem place) {
    setState(() {
      final exists = _plannerStops.any((item) => item.placeId == place.id);
      if (exists) {
        _plannerStops =
            _plannerStops.where((item) => item.placeId != place.id).toList();
      } else {
        _plannerStops = [
          ..._plannerStops,
          SavedCourseStop(
            placeId: place.id,
            name: place.name,
            address: place.address,
            latitude: place.latitude ?? 0,
            longitude: place.longitude ?? 0,
            sourceType: 'PLACE',
          ),
        ];
      }
    });
  }

  void _highlightPlace(int placeId) {
    setState(() {
      _highlightedPlaceId = placeId;
    });
  }

  Future<void> _generateAiCourse(RegionDetail detail) async {
    // AI 생성 연출 — 목업 코스 시뮬의 로딩 다이얼로그.
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
              Text(
                'AI가 코스를 만들고 있어요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '취향·환급 조건 분석 → 장소 선정 → 동선 최적화',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pop();

    final scored = detail.halfPricePlaces
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) => (
            place: place,
            score: _scorePlace(place, _preferences),
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final selected = <PlaceItem>[];
    for (final item in scored) {
      if (selected.any((element) => element.id == item.place.id)) {
        continue;
      }
      selected.add(item.place);
      if (selected.length >= 4) {
        break;
      }
    }

    if (selected.length < 2) {
      final fallback = detail.halfPricePlaces
          .where((place) => place.latitude != null && place.longitude != null)
          .take(3)
          .toList();
      selected
        ..clear()
        ..addAll(fallback);
    }

    setState(() {
      _plannerStops = selected
          .map(
            (place) => SavedCourseStop(
              placeId: place.id,
              name: place.name,
              address: place.address,
              latitude: place.latitude ?? 0,
              longitude: place.longitude ?? 0,
              sourceType: 'PLACE',
            ),
          )
          .toList();
      _mode = CourseBuildMode.manual;
      _highlightedPlaceId = _plannerStops.isEmpty ? null : _plannerStops.first.placeId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('취향을 반영한 추천 코스를 플래너에 담았습니다.')),
    );
  }

  Future<void> _saveCourse() async {
    if (_plannerStops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스에는 최소 2곳 이상 담아주세요.')),
      );
      return;
    }

    final formatter = DateFormat('M월 d일');
    final course = SavedCourse(
      id: widget.initialCourse?.id ??
          '${widget.regionId}_${DateTime.now().millisecondsSinceEpoch}',
      regionId: widget.regionId,
      regionName: widget.regionName,
      title: widget.initialCourse?.title ??
          '${widget.regionName} 코스 ${formatter.format(DateTime.now())}',
      preferences: _preferences.take(3).toList(),
      stops: _plannerStops,
      createdAt: DateTime.now(),
    );

    final controller = AppScope.of(context);
    await controller.saveCourse(course);
    if (widget.tripId != null) {
      final payload = _plannerStops.asMap().entries.map((entry) {
        final stop = entry.value;
        final sourceType = stop.sourceType.toUpperCase();
        final placeType = sourceType == PlaceCategory.digitalTourCard.wireName
            ? PlaceCategory.digitalTourCard
            : sourceType == PlaceCategory.merchant.wireName
                ? PlaceCategory.merchant
                : PlaceCategory.halfPrice;
        return TripPlaceItem(
          id: 0,
          placeType: placeType,
          referencePlaceId: stop.placeId,
          placeName: stop.name,
          address: stop.address,
          visitOrder: entry.key + 1,
          latitude: stop.latitude,
          longitude: stop.longitude,
          checked: true,
        );
      }).toList();
      await controller.runTask(
        () => controller.repository.replaceTripPlaces(widget.tripId!, payload),
      );
      await controller.selectCourseForTrip(
        tripId: widget.tripId!,
        courseId: course.id,
      );
      await controller.refreshTrips();
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.tripId == null
              ? '내 코스함에 저장했습니다.'
              : '내 코스함과 여행 플래너에 저장했습니다.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  int _scorePlace(PlaceItem place, List<String> preferences) {
    final keywords = _placeTags(place);
    var total = 0;
    for (var index = 0; index < preferences.length; index++) {
      final preference = preferences[index];
      if (keywords.contains(preference)) {
        total += (preferences.length - index) * 10;
      }
    }
    return total;
  }

  Set<String> _placeTags(PlaceItem place) {
    final text = '${place.name} ${place.address} ${place.description}';
    final tags = <String>{};
    if (_containsAny(text, ['해수욕장', '해안', '섬', '수목원', '생태', '산', '공원', '숲'])) {
      tags.addAll(['자연', '힐링']);
    }
    if (_containsAny(text, ['박물관', '기념관', '전시관', '유적', '향교', '서원', '관아'])) {
      tags.addAll(['문화', '체험']);
    }
    if (_containsAny(text, ['체험', '치유', '모노레일', '케이블카', '전망대', '타워', '축제'])) {
      tags.addAll(['체험', '사진']);
    }
    if (_containsAny(text, ['시장', '몰', '카페', '맛', '먹', '식당'])) {
      tags.add('맛집');
    }
    if (tags.isEmpty) {
      tags.addAll(['자연', '문화']);
    }
    return tags;
  }

  bool _containsAny(String source, List<String> keywords) {
    return keywords.any(source.contains);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final config = AppConfig.fromEnvironment();

    return AppShell(
      title: '${widget.regionName} 코스 만들기',
      modeName: controller.modeName,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: FilledButton.icon(
              onPressed: _saveCourse,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: const Text('내 코스함 저장'),
            ),
          ),
        ),
      ],
      child: FutureBuilder<RegionDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final detail = snapshot.data!;
          final markers = _buildMarkers(detail);
          final highlighted = markers.cast<PlaceMapMarkerData?>().firstWhere(
                (item) => item?.id == _highlightedPlaceId,
                orElse: () => null,
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _HeroCourseCard(
                regionName: widget.regionName,
                stopCount: _plannerStops.length,
                preferenceSummary: _preferences.take(3).join(' · '),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '코스 생성 방식',
                subtitle: 'AI 추천으로 초안을 만든 뒤 직접 수정하거나, 처음부터 직접 코스를 짤 수 있어요.',
                child: SegmentedButton<CourseBuildMode>(
                  segments: const [
                    ButtonSegment(
                      value: CourseBuildMode.ai,
                      icon: Icon(Icons.auto_awesome_rounded),
                      label: Text('AI 추천'),
                    ),
                    ButtonSegment(
                      value: CourseBuildMode.manual,
                      icon: Icon(Icons.edit_road_rounded),
                      label: Text('직접 만들기'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (_mode == CourseBuildMode.ai)
                _AiPreferenceSection(
                  preferences: _preferences,
                  onGenerate: () => _generateAiCourse(detail),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final moved = _preferences.removeAt(oldIndex);
                      _preferences.insert(newIndex, moved);
                    });
                  },
                )
              else
                _ManualBuilderSection(
                  markers: markers,
                  highlighted: highlighted,
                  kakaoEnabled: config.canUseKakaoMap,
                  onMarkerTap: (placeId) {
                    _highlightPlace(placeId);
                  },
                  onMarkerDoubleTap: (placeId) {
                    final place = detail.halfPricePlaces.cast<PlaceItem?>().firstWhere(
                          (item) => item?.id == placeId,
                          orElse: () => null,
                        );
                    if (place == null) {
                      return;
                    }
                    _highlightPlace(placeId);
                    _addOrRemoveStop(place);
                  },
                  onListTap: (placeId) {
                    _highlightPlace(placeId);
                  },
                  onListDoubleTap: (placeId) {
                    final place = detail.halfPricePlaces.cast<PlaceItem?>().firstWhere(
                          (item) => item?.id == placeId,
                          orElse: () => null,
                        );
                    if (place == null) {
                      return;
                    }
                    _highlightPlace(placeId);
                    _addOrRemoveStop(place);
                  },
                  onToggleSelection: (placeId) {
                    final place = detail.halfPricePlaces.cast<PlaceItem?>().firstWhere(
                          (item) => item?.id == placeId,
                          orElse: () => null,
                        );
                    if (place == null) {
                      return;
                    }
                    _addOrRemoveStop(place);
                  },
                ),
              const SizedBox(height: 18),
              _PlannerEditorSection(
                stops: _plannerStops,
                onRemove: (stop) {
                  setState(() {
                    _plannerStops =
                        _plannerStops.where((item) => item.placeId != stop.placeId).toList();
                  });
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final moved = _plannerStops.removeAt(oldIndex);
                    _plannerStops.insert(newIndex, moved);
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCourseCard extends StatelessWidget {
  const _HeroCourseCard({
    required this.regionName,
    required this.stopCount,
    required this.preferenceSummary,
  });

  final String regionName;
  final int stopCount;
  final String preferenceSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.route_outlined, size: 24, color: AppColors.p600),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$regionName 나만의 코스',
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
                  '취향 우선순위 ${preferenceSummary.isEmpty ? '미설정' : preferenceSummary}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Pill('$stopCount곳'),
        ],
      ),
    );
  }
}

class _AiPreferenceSection extends StatelessWidget {
  const _AiPreferenceSection({
    required this.preferences,
    required this.onGenerate,
    required this.onReorder,
  });

  final List<String> preferences;
  final VoidCallback onGenerate;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'AI 코스 생성',
      subtitle: '드래그로 취향 우선순위를 정하면, 현재 지역의 지정관광지 중 두 곳 이상을 포함한 코스를 추천합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: preferences.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final item = preferences[index];
              return Container(
                key: ValueKey(item),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.p500,
                      foregroundColor: Colors.white,
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const Icon(Icons.drag_indicator_rounded, color: AppColors.ink4),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI가 코스 생성하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBuilderSection extends StatelessWidget {
  const _ManualBuilderSection({
    required this.markers,
    required this.highlighted,
    required this.kakaoEnabled,
    required this.onMarkerTap,
    required this.onMarkerDoubleTap,
    required this.onListTap,
    required this.onListDoubleTap,
    required this.onToggleSelection,
  });

  final List<PlaceMapMarkerData> markers;
  final PlaceMapMarkerData? highlighted;
  final bool kakaoEnabled;
  final ValueChanged<int> onMarkerTap;
  final ValueChanged<int> onMarkerDoubleTap;
  final ValueChanged<int> onListTap;
  final ValueChanged<int> onListDoubleTap;
  final ValueChanged<int> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '직접 코스 짜보기',
      subtitle: '카카오맵 마커를 눌러 위치를 보고, 더블클릭하면 바로 개인 플래너에 추가됩니다.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapSection = Column(
            children: [
              PlaceMapView(
                markers: markers,
                emptyMessage: '등록된 지정관광지 좌표가 없습니다.',
                kakaoEnabled: kakaoEnabled,
                highlightedMarkerId: highlighted?.id,
                onMarkerTap: onMarkerTap,
                onMarkerDoubleTap: onMarkerDoubleTap,
                height: 460,
              ),
              if (highlighted != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.p50,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        highlighted!.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        highlighted!.address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF475569),
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

          final listSection = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 장소',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '한 번 클릭은 위치 확인, 두 번 클릭은 플래너 추가입니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 460,
                  child: ListView.separated(
                    itemCount: markers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final marker = markers[index];
                      final isHighlighted = highlighted?.id == marker.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onListTap(marker.id),
                        onDoubleTap: () => onListDoubleTap(marker.id),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isHighlighted ? AppColors.p50 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: marker.selected
                                    ? AppColors.p500
                                    : AppColors.track,
                                foregroundColor: marker.selected
                                    ? Colors.white
                                    : AppColors.ink5,
                                child: Text('${index + 1}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      marker.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      marker.address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF64748B),
                                            height: 1.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => onToggleSelection(marker.id),
                                child: Text(marker.selected ? '제거' : '추가'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          if (constraints.maxWidth >= 1100) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: mapSection),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: listSection),
              ],
            );
          }

          return Column(
            children: [
              mapSection,
              const SizedBox(height: 16),
              listSection,
            ],
          );
        },
      ),
    );
  }
}

class _PlannerEditorSection extends StatelessWidget {
  const _PlannerEditorSection({
    required this.stops,
    required this.onRemove,
    required this.onReorder,
  });

  final List<SavedCourseStop> stops;
  final ValueChanged<SavedCourseStop> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '개인 플래너',
      subtitle: 'AI가 만든 코스도 여기로 내려와서 그대로 수정할 수 있습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stops.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Text('아직 담은 장소가 없습니다. 지도에서 두 번 클릭해 추가해 주세요.'),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return Container(
                  key: ValueKey(stop.placeId),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.p500,
                        foregroundColor: Colors.white,
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stop.address,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF64748B),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemove(stop),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const Icon(Icons.drag_indicator_rounded, color: AppColors.ink4),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
