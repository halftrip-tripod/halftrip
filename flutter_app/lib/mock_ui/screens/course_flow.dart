import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/youtube_course_start_screen.dart';
import '../../services/course_ai_service.dart';
import '../../widgets/place_map_view.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'trip_picker_sheet.dart';

// ───────────────────────── AI 코스 생성 유틸 (실서버 후보 → 일정 배치)

const _day1Slots = ['10:00', '12:30', '14:30', '18:00'];
const _day2Slots = ['09:30', '12:00', '14:30'];

/// 실서버 후보(PlaceItem) 목록 → DAY1/DAY2 일정으로 배치.
List<CourseStop> _scheduleAiStops(List<PlaceItem> places) {
  final stops = <CourseStop>[];
  for (var i = 0; i < places.length && i < 7; i++) {
    final day = i < _day1Slots.length ? 1 : 2;
    final time = day == 1 ? _day1Slots[i] : _day2Slots[i - _day1Slots.length];
    final place = places[i];
    stops.add(CourseStop(
      day: day,
      time: time,
      emoji: _aiPlaceEmoji(place),
      name: place.name,
      tag: '관광지',
      refund: place.eligibleForRefund,
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address,
      placeId: place.id,
    ));
  }
  return stops;
}

String _aiPlaceEmoji(PlaceItem place) {
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

/// 취향 키워드 매칭 규칙 기반 대체 정렬 (LLM 실패/빈 결과 시).
List<PlaceItem> _rankAiPlaces(
    List<PlaceItem> places, List<String> prefs) {
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

/// S1-4a 코스 만들기 (방식 선택).
/// [forTrip]이 있으면 여행 지역·일정이 고정된 상태로 시작 (지역 선택 단계 생략),
/// 만든 코스는 그 여행의 확정 코스로 연결된다.
class CourseCreateScreen extends StatelessWidget {
  const CourseCreateScreen({super.key, this.forTrip, this.onYoutubeForTrip});
  final Trip? forTrip;

  /// 실여행 컨텍스트에서 유튜브 분석을 실서버 플로우로 태울 때 주입 (없으면 목업 연출).
  final VoidCallback? onYoutubeForTrip;

  void _go(BuildContext context, Widget Function(Region) builder) {
    if (forTrip != null) {
      final region = AppState.I.regionByName(forTrip!.region);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder(region)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseRegionScreen(onPicked: builder)));
  }

  /// 코스함의 같은 지역 코스 중 하나를 골라 이 여행의 확정 코스로 연결한다.
  Future<void> _pickFromSaved(BuildContext context, Trip trip) async {
    final candidates =
        AppState.I.courses.where((c) => c.region == trip.region).toList();
    final picked = await showAppSheet<Course>(
      context,
      scrollable: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('코스함에서 가져오기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9)),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (ctx, i) {
              final c = candidates[i];
              return ListTile(
                leading: EmojiBox(c.emoji, size: 40, fontSize: 20),
                title: Text(c.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink9)),
                subtitle: Text('${c.durationLabel} · ${c.placeCount}곳',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.ink4),
                onTap: () => Navigator.of(ctx).pop(c),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
    if (picked == null || !context.mounted) return;
    trip.course = picked;
    AppState.I.update();
    Navigator.of(context).pop(); // 방식 선택 화면 닫고 여행 상세 복귀
    showMock(context, '코스함의 "${picked.title}" 코스를 이 여행에 연결했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final trip = forTrip;
    return DetailScaffold(
      title: '코스 만들기',
      children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: '어떤 방식으로\n'),
            TextSpan(text: '코스', style: TextStyle(color: AppColors.p600)),
            TextSpan(text: '를 만들까요?'),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
        ),
        Text(
          trip != null ? '만든 코스는 이 여행의 확정 코스로 연결돼요' : '만든 코스는 저장한 뒤 자유롭게 수정할 수 있어요',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5),
        ),
        if (trip != null)
          AppCard(
            padding: const EdgeInsets.all(16),
            radius: 18,
            child: Row(children: [
              EmojiBox(trip.emoji, size: 46, fontSize: 23),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('코스를 만들 여행',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.p600)),
                  const SizedBox(height: 2),
                  Text(trip.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                  const SizedBox(height: 2),
                  Text(trip.dateLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                ]),
              ),
            ]),
          ),
        // 코스함에 이 지역 코스가 이미 있으면 새로 만들지 않고 가져올 수 있게.
        if (trip != null &&
            AppState.I.courses.any((c) => c.region == trip.region))
          _MakeCard(
            icon: Icons.bookmark_rounded,
            iconBg: AppColors.warningTint,
            iconFg: const Color(0xFFB8731B),
            title: '코스함에서 가져오기',
            desc: '보관함의 코스 중에서 골라서 등록해요',
            onTap: () => _pickFromSaved(context, trip),
          ),
        _MakeCard(
          icon: Icons.auto_awesome_rounded,
          iconBg: AppColors.p50,
          iconFg: AppColors.p600,
          title: 'AI 추천 코스',
          desc: '환급 조건 · 여행 취향에 맞는 코스를 자동으로 생성해요',
          onTap: () => _go(context, (r) => CourseAiScreen(region: r, forTrip: forTrip)),
        ),
        _MakeCard(
          icon: Icons.play_circle_fill_rounded,
          iconBg: AppColors.coralTint,
          iconFg: const Color(0xFFE0322B),
          title: '유튜브 영상으로 만들기',
          desc: '여행 브이로그 링크를 붙여넣으면 영상 속 장소로 코스를 완성해요',
          // 여행 없이도 실분석 — 지역 선택 후 실서버 유튜브 분석으로 바로 간다.
          // (코스는 지역 귀속 — 서버 잡 tripId 옵셔널화와 세트, 2026-08-15)
          onTap: onYoutubeForTrip ??
              () => _go(context,
                  (r) => YoutubeCourseStartScreen(regionName: r.name)),
        ),
        _MakeCard(
          icon: Icons.edit_rounded,
          iconBg: AppColors.mintTint,
          iconFg: AppColors.mintDeep,
          title: '직접 만들기',
          desc: '가고 싶은 장소를 검색해서 내 마음대로 코스를 구성해요',
          // 저장 전에는 아무것도 만들지 않는다 — 그냥 뒤로 나가면 코스가 남지 않게
          // 초안만 들고 편집 화면으로 가고, "변경사항 저장"에서 코스함 추가·여행 연결.
          onTap: () => _go(context, (r) => CourseEditScreen(
                course: Course(
                  emoji: r.emoji, region: r.name, province: r.province,
                  title: '${r.name} 나만의 코스', source: CourseSource.manual,
                  durationLabel: '1박 2일', placeCount: 0, refundOk: false,
                  savedAgo: '방금 저장', stops: [],
                ),
                isNew: true,
                forTrip: forTrip,
              )),
        ),
      ],
    );
  }
}

class _MakeCard extends StatelessWidget {
  const _MakeCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(17)),
          child: Icon(icon, size: 27, color: iconFg),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 5),
            Text(desc,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.45)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
      ]),
    );
  }
}

/// 지역 선택 (코스 공통 첫 단계).
class CourseRegionScreen extends StatefulWidget {
  const CourseRegionScreen({super.key, required this.onPicked});
  final Widget Function(Region) onPicked;

  @override
  State<CourseRegionScreen> createState() => _CourseRegionScreenState();
}

class _CourseRegionScreenState extends State<CourseRegionScreen> {
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final q = _query.trim();
    final list = switch (_filter) {
      0 => s.regions.where((r) => r.status == RegionStatus.open),
      1 => s.regions.where((r) => r.status == RegionStatus.soon),
      2 => s.regions.where((r) => r.favorite.value),
      _ => s.regions,
    }
        .where((r) => q.isEmpty || r.name.contains(q) || r.province.contains(q))
        .toList();

    return DetailScaffold(
      title: '여행 지역 선택',
      children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: '어느 지역으로\n'),
            TextSpan(text: '코스', style: TextStyle(color: AppColors.p600)),
            TextSpan(text: '를 만들까요?'),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
        ),
        const Text('반값여행 접수 중인 지역 위주로 보여드려요',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9),
          decoration: InputDecoration(
            hintText: '지역 이름 검색 (예: 강진, 영월)',
            hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.ink4),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        CatChips(
          labels: const ['접수중', '오픈예정', '관심 지역', '전체'],
          selected: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        for (final r in list)
          AppCard(
            padding: const EdgeInsets.all(15),
            radius: 18,
            onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => widget.onPicked(r))),
            child: Row(children: [
              EmojiBox(r.emoji, size: 46, fontSize: 23),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 3),
                  Text('${r.province} · 지정관광지 ${5 + r.name.length}곳',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                ]),
              ),
              Pill(r.status == RegionStatus.open ? '접수중' : '오픈예정',
                  tone: r.status == RegionStatus.open ? PillTone.sky : PillTone.gray),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
            ]),
          ),
      ],
    );
  }
}

/// S1-4b AI 코스 생성 입력.
class CourseAiScreen extends StatefulWidget {
  const CourseAiScreen({super.key, required this.region, this.forTrip});
  final Region region;
  final Trip? forTrip;

  @override
  State<CourseAiScreen> createState() => _CourseAiScreenState();
}

class _CourseAiScreenState extends State<CourseAiScreen> {
  // 여행에서 진입하면 여행 일정·인원을 그대로 프리필.
  late int _nights = widget.forTrip?.nights ?? 1;
  late int _people = widget.forTrip?.people ?? 2;
  final _themes = [
    ('🍴', '맛집', '지역 미식·시장'),
    ('🌿', '자연', '바다·산·공원'),
    ('🏛️', '문화', '박물관·유적'),
    ('🎟️', '체험', '전망대·액티비티'),
  ];

  static const _rankColors = [AppColors.p600, AppColors.p500, AppColors.p400, AppColors.p300];

  void _generate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GeneratingDialog(
          title: 'AI가 코스를 만들고 있어요', steps: ['취향·환급 조건 분석', '장소 선정', '동선 최적화']),
    );

    final controller = AppScope.of(context);
    final preferences = _themes.map((t) => t.$2).toList();
    List<CourseStop> stops = const [];
    String? errorMessage;
    try {
      // mock_ui의 Region엔 백엔드 id가 없어 이름으로 실제 지역을 찾는다.
      final regions = await controller.repository.getRegions();
      final matched = regions.where((r) => r.name == widget.region.name);
      if (matched.isEmpty) {
        throw Exception('연결된 지역 정보를 찾을 수 없습니다.');
      }
      final detail = await controller.repository.getRegionDetail(
        matched.first.id,
        residence: controller.currentUser?.residence,
      );
      final candidates = detail.halfPricePlaces;
      if (candidates.isEmpty) {
        throw Exception('추천할 장소 데이터가 없습니다.');
      }
      List<PlaceItem> places;
      try {
        // FastAPI LLM으로 실제 코스 생성(테마·환급조건 반영, 후보 중에서만 선정).
        final aiService = CourseAiService(AppConfig.fromEnvironment());
        final result = await aiService.generate(
          regionName: widget.region.name,
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
          places = _rankAiPlaces(candidates, preferences);
        }
      } catch (_) {
        // FastAPI 호출 실패(네트워크/키 미설정 등) — 클라이언트 규칙 기반으로 대체.
        places = _rankAiPlaces(candidates, preferences);
      }
      stops = _scheduleAiStops(places);
    } catch (error) {
      errorMessage = '$error';
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // 다이얼로그 닫기

    if (errorMessage != null || stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코스를 생성하지 못했습니다: ${errorMessage ?? "추천할 장소가 없습니다."}')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => CourseSimScreen(
            region: widget.region,
            nights: _nights,
            forTrip: widget.forTrip,
            stops: stops)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.region;
    return DetailScaffold(
      title: 'AI 코스 생성',
      cta: CtaBar(children: [
        PrimaryButton('AI 코스 생성하기', icon: Icons.auto_awesome_rounded, onTap: _generate),
      ]),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          radius: 18,
          child: Row(children: [
            EmojiBox(r.emoji, size: 46, fontSize: 23),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('여행 지역',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.p600)),
                const SizedBox(height: 2),
                Text('${r.name} · ${r.province}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
              ]),
            ),
            if (widget.forTrip == null)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text('변경',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
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
          proxyDecorator: (child, _, _) => child,
          onReorder: (oldIndex, newIndex) => setState(() {
            if (newIndex > oldIndex) newIndex--;
            _themes.insert(newIndex, _themes.removeAt(oldIndex));
          }),
          children: [
            for (var i = 0; i < _themes.length; i++)
              Padding(
                key: ValueKey(_themes[i].$2),
                padding: EdgeInsets.only(bottom: i == _themes.length - 1 ? 0 : 10),
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
                        decoration: BoxDecoration(color: _rankColors[i], shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      const SizedBox(width: 13),
                      Text(_themes[i].$1, style: const TextStyle(fontSize: 21)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: _themes[i].$2,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                            TextSpan(
                                text: '  ${_themes[i].$3}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                          ]),
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.ink4),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        const NoteRow('환급 조건(지정관광지 2곳·숙박 포함)은 자동으로 충족되게 코스를 짜드려요.'),
      ],
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
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.2)),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Text(sub!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        ],
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
        const Spacer(),
        _StepBtn('−', onMinus),
        SizedBox(
          width: 74,
          child: Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9)),
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
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(11)),
        child: Text(label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.p600, height: 1)),
      ),
    );
  }
}

class _GeneratingDialog extends StatelessWidget {
  const _GeneratingDialog({required this.title, required this.steps});
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3.5, color: AppColors.p500),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          const SizedBox(height: 8),
          Text(steps.join(' → '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5)),
        ]),
      ),
    );
  }
}

/// S1-6 유튜브 코스 추출 (입력 → 분석 → 완성).
class CourseYoutubeScreen extends StatefulWidget {
  const CourseYoutubeScreen({super.key, required this.region, this.forTrip});
  final Region region;
  final Trip? forTrip;

  @override
  State<CourseYoutubeScreen> createState() => _CourseYoutubeScreenState();
}

class _CourseYoutubeScreenState extends State<CourseYoutubeScreen> {
  int _stage = 0; // 0 입력 / 1 분석 / 2 완성
  int _doneSteps = 1;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _stage = 1);
    _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) return;
      setState(() => _doneSteps++);
      if (_doneSteps >= 4) {
        t.cancel();
        final c = Course(
          emoji: widget.region.emoji,
          region: widget.region.name,
          province: widget.region.province,
          title: '${widget.region.name} 유튜브 추천 코스',
          source: CourseSource.youtube,
          durationLabel: '1박 2일',
          placeCount: 6,
          refundOk: true,
          savedAgo: '방금 저장',
          stops: gangjinStops(),
        );
        AppState.I.addCourse(c);
        widget.forTrip?.course = c;
        AppState.I.update();
        setState(() => _stage = 2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '유튜브로 코스 만들기',
      cta: switch (_stage) {
        0 => CtaBar(children: [PrimaryButton('코스 만들기', onTap: _start)]),
        1 => const CtaBar(children: [PrimaryButton('생성 중…', disabled: true)]),
        _ => CtaBar(children: [
            PrimaryButton('코스 편집하기', icon: Icons.edit_rounded, onTap: () {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => CourseEditScreen(course: AppState.I.courses.first)));
            }),
          ]),
      },
      children: switch (_stage) {
        0 => _inputStage(),
        1 => _analyzingStage(),
        _ => _doneStage(),
      },
    );
  }

  List<Widget> _inputStage() {
    final r = widget.region;
    return [
      const Text.rich(
        TextSpan(children: [
          TextSpan(text: '영상 링크만 붙여넣으면\n'),
          TextSpan(text: '코스까지', style: TextStyle(color: AppColors.p600)),
          TextSpan(text: ' 만들어드려요'),
        ]),
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
      ),
      const Text('자막·화면 속 장소를 찾아 자동으로 코스를 짜드려요',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
      AppCard(
        padding: const EdgeInsets.all(16),
        radius: 18,
        child: Row(children: [
          EmojiBox(r.emoji, size: 46, fontSize: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('여행 지역',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.p600)),
              const SizedBox(height: 2),
              Text('${r.name} · ${r.province}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9)),
            ]),
          ),
          if (widget.forTrip == null)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text('변경',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
            ),
        ]),
      ),
      AppCard(
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.play_circle_fill_rounded, size: 19, color: Color(0xFFE0322B)),
            SizedBox(width: 8),
            Text('유튜브 영상 링크',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
          ]),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.link_rounded, size: 18, color: AppColors.ink4),
              SizedBox(width: 10),
              Expanded(
                child: Text('youtu.be/Kx8q2vR1pAo',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink9)),
              ),
              Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
            ]),
          ),
          const Divider(height: 30),
          const _YtVideoRow(),
        ]),
      ),
      const NoteRow('영상 속 장소로 코스를 자동 생성해 코스함에 저장해요. 저장 후 자유롭게 수정할 수 있어요.'),
    ];
  }

  List<Widget> _analyzingStage() {
    const steps = ['영상 정보 불러오기', '자막·화면에서 장소 추출 중…', '환급 인정 관광지와 매칭', '동선 짜고 코스 완성'];
    return [
      const Text.rich(
        TextSpan(children: [
          TextSpan(text: '영상', style: TextStyle(color: AppColors.p600)),
          TextSpan(text: '으로 코스를\n만들고 있어요'),
        ]),
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(16)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.p600),
          SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('다른 화면을 둘러봐도 괜찮아요',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.p700, height: 1.45)),
              SizedBox(height: 4),
              Text('코스는 백그라운드에서 계속 만들어지고, 완료되면 알림으로 알려드려요.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.45)),
            ]),
          ),
        ]),
      ),
      const AppCard(padding: EdgeInsets.all(14), radius: 18, child: _YtVideoRow()),
      AppCard(
        radius: 20,
        child: Column(children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < _doneSteps
                        ? AppColors.p100
                        : (i == _doneSteps ? AppColors.p500 : AppColors.track),
                    shape: BoxShape.circle,
                  ),
                  child: i < _doneSteps
                      ? const Icon(Icons.check_rounded, size: 14, color: AppColors.p600)
                      : (i == _doneSteps
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : null),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(steps[i],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: i < _doneSteps
                            ? AppColors.ink9
                            : (i == _doneSteps ? AppColors.p700 : AppColors.ink4),
                      )),
                ),
              ]),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _doneStage() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(14)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bookmark_rounded, size: 16, color: AppColors.p600),
          SizedBox(width: 7),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '영상으로 만든 코스를 '),
              TextSpan(text: '코스함', style: TextStyle(fontWeight: FontWeight.w900)),
              TextSpan(text: '에 저장했어요'),
            ]),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p700),
          ),
        ]),
      ),
      const FitBanner(title: '이 코스로 환급 조건 100% 충족', subtitle: '지정관광지 2곳 · 1박 숙박 · 인정 결제 포함'),
      const CourseMapCard(),
      const _TimelineSection(),
    ];
  }
}

class _YtVideoRow extends StatelessWidget {
  const _YtVideoRow();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 96,
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF374151)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Stack(alignment: Alignment.center, children: [
          Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
          Positioned(
            right: 5,
            bottom: 5,
            child: Text('14:22',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ),
      const SizedBox(width: 13),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('전남 강진 1박2일 여행 브이로그 🍲 가우도 출렁다리부터 다산초당까지',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink9, height: 1.35)),
          SizedBox(height: 5),
          Text('여행하는 미루 · 조회수 12만',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        ]),
      ),
    ]);
  }
}

/// S1-4 코스 시뮬 (생성 결과).
class CourseSimScreen extends StatefulWidget {
  const CourseSimScreen({
    super.key,
    required this.region,
    this.nights = 1,
    this.forTrip,
    this.stops = const [],
  });
  final Region region;
  final int nights;
  final Trip? forTrip;
  /// AI가 실제 후보(TourAPI 지정관광지) 중에서 뽑은 장소 목록. 좌표를 포함한다.
  final List<CourseStop> stops;

  @override
  State<CourseSimScreen> createState() => _CourseSimScreenState();
}

class _CourseSimScreenState extends State<CourseSimScreen> {
  /// 지도에 표시할 일차 (1박2일이면 DAY 1/2 토글).
  int _mapDay = 1;

  /// 상세 일정에서 탭한 장소 — 지도를 그 핀으로 이동시키고 정보창을 연다.
  int? _focusStopId;

  Region get region => widget.region;
  int get nights => widget.nights;
  Trip? get forTrip => widget.forTrip;
  List<CourseStop> get stops => widget.stops;

  @override
  Widget build(BuildContext context) {
    // 코스에 실제로 존재하는 일차 목록 (당일치기면 [1]).
    final days = stops.map((s) => s.day).toSet().toList()..sort();
    final mapStops =
        stops.where((s) => days.length < 2 || s.day == _mapDay).toList();
    return DetailScaffold(
      title: '${region.name} 코스',
      cta: CtaBar(
        note: forTrip != null
            ? '저장하면 이 여행의 확정 코스로 연결돼요'
            : '저장하면 내 코스함에서 장소·시간을 수정할 수 있어요',
        children: [
          GhostButton(
            label: '다시 생성',
            icon: Icons.refresh_rounded,
            onTap: () => showMock(context, '취향을 반영해 코스를 다시 생성했어요. (목업)'),
          ),
          PrimaryButton('내 코스함에 저장', icon: Icons.bookmark_rounded, onTap: () {
            final c = Course(
              emoji: region.emoji, region: region.name, province: region.province,
              title: '${region.name} 환급 보장 코스', source: CourseSource.ai,
              durationLabel: nights == 0 ? '당일치기' : '$nights박 ${nights + 1}일',
              placeCount: stops.length, refundOk: true, savedAgo: '방금 저장',
              stops: stops.isEmpty ? gangjinStops() : stops,
            );
            AppState.I.addCourse(c);
            if (forTrip != null) {
              forTrip!.course = c;
              AppState.I.update();
              // 여행 상세 → 코스 만들기 → (시뮬) 스택이므로 두 번 pop = 여행 상세 복귀.
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              showMock(context, '코스를 저장하고 ${forTrip!.name} 여행에 연결했어요.');
              return;
            }
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CourseSavedScreen()));
            showMock(context, '코스를 코스함에 저장했어요.');
          }),
        ],
      ),
      children: [
        // 지도 + 일차 토글 + 일정을 한 덩어리로 — 스캐폴드 기본 간격(16)이 사이에 안 끼게.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStopsMap(context, mapStops, focusId: _focusStopId),
          if (days.length >= 2) ...[
            const SizedBox(height: 8),
            // 일차가 많아 가로를 넘치면 스크롤, 적으면 중앙 정렬.
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final d in days) ...[
                    if (d != days.first) const SizedBox(width: 8),
                    _DayChip(
                      label: 'DAY $d',
                      active: _mapDay == d,
                      onTap: () => setState(() {
                        _mapDay = d;
                        _focusStopId = null;
                      }),
                    ),
                  ],
                ]),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _TimelineSection(
            stops: stops,
            selectedStopId: _focusStopId,
            onStopTap: (s) {
              if (s.latitude == null || s.longitude == null) return;
              setState(() {
                if (days.length >= 2) _mapDay = s.day;
                _focusStopId = s.placeId ?? s.name.hashCode;
              });
            },
          ),
        ]),
      ],
    );
  }
}

/// 코스 지도의 일차 선택 칩.
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.p600 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active ? null : AppShadows.soft,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : AppColors.ink5,
            )),
      ),
    );
  }
}

/// 코스 스톱의 실제 좌표를 지도(구글/카카오)에 순서대로 표시. 좌표가 없으면 장식용 목업 지도로 대체.
/// [focusId]가 있으면 그 핀을 중심으로 이동하고 정보창을 연 상태로 그린다.
Widget _buildStopsMap(BuildContext context, List<CourseStop> stops,
    {int? focusId}) {
  final geoStops = stops.where((s) => s.latitude != null && s.longitude != null).toList();
  if (geoStops.isEmpty) {
    return const CourseMapCard();
  }
  final markers = geoStops
      .map((stop) => PlaceMapMarkerData(
            id: stop.placeId ?? stop.name.hashCode,
            name: stop.name,
            address: stop.address ?? '',
            latitude: stop.latitude!,
            longitude: stop.longitude!,
            selected: false,
            editorialSummary: stop.tag,
          ))
      .toList();
  final routeMarkers = geoStops
      .map((stop) => PlaceMapRoutePoint(
            id: stop.placeId ?? stop.name.hashCode,
            latitude: stop.latitude!,
            longitude: stop.longitude!,
          ))
      .toList();
  final focusStop = focusId == null
      ? null
      : geoStops
          .cast<CourseStop?>()
          .firstWhere((s) => (s!.placeId ?? s.name.hashCode) == focusId,
              orElse: () => null);
  final config = AppConfig.fromEnvironment();
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: PlaceMapView(
      // 포커스가 바뀌면 지도를 새로 그려 그 핀 중심으로 이동시킨다.
      key: ValueKey('course-map-$focusId'),
      markers: markers,
      emptyMessage: '표시할 장소 좌표가 없습니다.',
      kakaoEnabled: config.canUseKakaoMap,
      routeMarkers: routeMarkers,
      connectSequentially: true,
      height: 280,
      highlightedMarkerId: focusId,
      initialCenterLatitude: focusStop?.latitude,
      initialCenterLongitude: focusStop?.longitude,
      onMarkerDetailsRequested: (marker) => _loadAiMarkerDetails(context, marker),
    ),
  );
}

/// 지도 마커 탭 시 구글 Places 상세정보를 조회해 병합. 실패하면 기존(TourAPI 기반) 값 유지.
Future<PlaceMapMarkerData?> _loadAiMarkerDetails(
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
      editorialSummary:
          detail.editorialSummary.isNotEmpty ? detail.editorialSummary : marker.editorialSummary,
      googlePlaceDetails:
          detail.googlePlaceDetails.isNotEmpty ? detail.googlePlaceDetails : marker.googlePlaceDetails,
    );
  } catch (_) {
    return null;
  }
}

/// DAY별 타임라인.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({this.stops, this.onStopTap, this.selectedStopId});
  final List<CourseStop>? stops;

  /// 장소 탭 콜백 — 시뮬 화면에서 지도 이동·정보창 열기에 쓴다.
  final void Function(CourseStop)? onStopTap;

  /// 선택된 장소 id — 해당 행을 파란 테두리·틴트로 표시.
  final int? selectedStopId;

  @override
  Widget build(BuildContext context) {
    final list = stops ?? gangjinStops();
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('아직 장소가 없어요\n코스 편집에서 장소를 추가해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink4, height: 1.6)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 10),
        child: Text('상세 일정',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
      ),
      for (final day in [1, 2])
        if (list.any((s) => s.day == day)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
            child: Text('DAY $day · 6.1${3 + day} (${day == 1 ? '토' : '일'})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: .3)),
          ),
          for (final s in list.where((s) => s.day == day))
            onStopTap == null
                ? TimelineStop(stop: s)
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onStopTap!(s),
                    child: TimelineStop(
                      stop: s,
                      selected:
                          (s.placeId ?? s.name.hashCode) == selectedStopId,
                    ),
                  ),
        ],
    ]);
  }
}

/// 코스 보기 (읽기 전용) — 저장 코스·여행 코스에서 진입, 편집은 CTA로.
class CourseViewScreen extends StatefulWidget {
  const CourseViewScreen({super.key, required this.course});
  final Course course;

  @override
  State<CourseViewScreen> createState() => _CourseViewScreenState();
}

class _CourseViewScreenState extends State<CourseViewScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    return DetailScaffold(
      title: c.title,
      cta: CtaBar(children: [
        PrimaryButton('코스 편집하기', icon: Icons.edit_rounded, onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => CourseEditScreen(course: c)))
              .then((_) => setState(() {}));
        }),
      ]),
      children: [
        if (c.refundOk)
          const FitBanner(
              title: '이 코스로 환급 조건 100% 충족', subtitle: '지정관광지 2곳 · 1박 숙박 · 인정 결제 포함'),
        if (c.stops.isNotEmpty) _buildStopsMap(context, c.stops),
        _TimelineSection(stops: c.stops),
      ],
    );
  }
}

class TimelineStop extends StatelessWidget {
  const TimelineStop({super.key, required this.stop, this.selected = false});
  final CourseStop stop;

  /// 지도 연동 등에서 이 장소가 선택된 상태 — 파란 테두리·틴트로 표시.
  final bool selected;

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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink5)),
          ),
        ),
        SizedBox(
          width: 28,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned.fill(child: Center(child: Container(width: 2, color: AppColors.line))),
            Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: stop.refund ? AppColors.p500 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: stop.refund ? AppColors.p500 : AppColors.p200, width: 3),
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
                color: selected ? AppColors.p50 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: selected
                    ? Border.all(color: AppColors.p500, width: 1.4)
                    : null,
                boxShadow: AppShadows.card),
            child: Row(children: [
              EmojiBox(stop.emoji, size: 40, fontSize: 20, color: AppColors.surf, radius: 13),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stop.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    _tag(stop.tag, stop.tag == '맛집' ? const Color(0xFFFFF1E0) : AppColors.p100,
                        stop.tag == '맛집' ? const Color(0xFFB8731B) : AppColors.p700),
                    if (stop.refund)
                      _tag(stop.stay ? '숙박 필수 ✓' : '환급 인정', AppColors.mintTint, AppColors.mintDeep),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      );
}

/// S1-7 저장 코스함.
class CourseSavedScreen extends StatefulWidget {
  const CourseSavedScreen({super.key});

  @override
  State<CourseSavedScreen> createState() => _CourseSavedScreenState();
}

class _CourseSavedScreenState extends State<CourseSavedScreen> {
  int _filter = 0;

  /// 저장 코스함에는 여행 컨텍스트가 없다. 유튜브 실분석은 TripDetail이 필요하므로
  /// 연결할 여행을 먼저 고르게 하고, 그 여행으로 실서버 플로우를 태운다.
  /// (여행을 못 고르면 목업 연출로 떨어지지 않고 그대로 중단한다.)
  Future<void> _openYoutubeWithTripPick() async {
    final controller = AppScope.of(context);
    // 내 여행 탭을 거치지 않고 홈·알림에서 바로 들어오면 목록이 비어 있을 수 있다.
    if (controller.trips.isEmpty) {
      try {
        await controller.refreshTrips();
      } catch (_) {
        // 아래 빈 목록 안내로 처리한다.
      }
    }
    if (!mounted) return;

    // 정산 신청이 끝난 여행은 코스를 새로 붙일 수 없으므로 제외한다.
    final candidates =
        controller.trips.where((t) => !t.settlementApplied).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('코스를 연결할 여행이 없어요. 내 여행에서 여행을 먼저 만들어 주세요.'),
        ),
      );
      return;
    }

    final picked = await pickTripSheet(context, trips: candidates);
    if (picked == null || !mounted) return;

    final TripDetail detail;
    try {
      detail = await controller.repository.getTripDetail(picked.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubeCourseStartScreen(tripDetail: detail),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    // 칩 순서는 지역 마스터 순서로 고정 — 코스 저장 순서에 따라 튀지 않게.
    final regions = s.regions
        .map((r) => r.name)
        .where((name) => s.courses.any((c) => c.region == name))
        .toList();
    final labels = ['전체 ${s.courses.length}', for (final r in regions) '$r ${s.courses.where((c) => c.region == r).length}'];
    final list = _filter == 0
        ? s.courses
        : s.courses.where((c) => c.region == regions[_filter - 1]).toList();

    return DetailScaffold(
      title: '저장 코스함',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: AppColors.p600),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => CourseCreateScreen(
                        onYoutubeForTrip: _openYoutubeWithTripPick,
                      )))
              .then((_) => setState(() {})),
        ),
      ],
      children: [
        CatChips(labels: labels, selected: _filter, onChanged: (i) => setState(() => _filter = i)),
        for (final c in list)
          AppCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CourseViewScreen(course: c)))
                .then((_) => setState(() {})),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                EmojiBox(c.emoji, size: 46, fontSize: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Pill(
                        switch (c.source) {
                          CourseSource.ai => 'AI 추천',
                          CourseSource.youtube => '유튜브',
                          CourseSource.manual => '직접',
                        },
                        tone: switch (c.source) {
                          CourseSource.ai => PillTone.sky,
                          CourseSource.youtube => PillTone.yt,
                          CourseSource.manual => PillTone.mint,
                        },
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text('${c.province} · ${c.region}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(c.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${c.durationLabel} · ${c.placeCount}곳'),
                  if (c.refundOk)
                    const TextSpan(
                        text: ' · 환급 조건 충족 ✓',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
                ]),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink5),
              ),
              const Divider(height: 22),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.ink4),
                const SizedBox(width: 6),
                Text(c.savedAgo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                const Spacer(),
                const Text('코스 열기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
                const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.p600),
              ]),
            ]),
          ),
      ],
    );
  }
}

/// S2-4 / 코스 편집 (플래너).
class CourseEditScreen extends StatefulWidget {
  const CourseEditScreen(
      {super.key, required this.course, this.isNew = false, this.forTrip});
  final Course course;

  /// 새 코스 초안 편집이면 true — "변경사항 저장"에서야 코스함에 추가된다.
  final bool isNew;

  /// 여행에서 진입한 경우 저장 시 이 여행의 확정 코스로 연결한다.
  final Trip? forTrip;

  @override
  State<CourseEditScreen> createState() => _CourseEditScreenState();
}

class _CourseEditScreenState extends State<CourseEditScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final refundCount = c.stops.where((s) => s.refund && !s.stay).length;
    final hasStay = c.stops.any((s) => s.stay);
    final ok = refundCount >= 2 && hasStay;

    return DetailScaffold(
      title: '코스 편집',
      cta: CtaBar(children: [
        PrimaryButton('변경사항 저장', onTap: () {
          // 새 코스는 저장 시점에야 코스함에 추가·여행에 연결된다.
          if (widget.isNew) AppState.I.addCourse(c);
          final trip = widget.forTrip;
          if (trip != null) {
            trip.course = c;
            AppState.I.update();
            // 편집 → 방식 선택까지 닫고 여행 상세로 복귀.
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            showMock(context, '코스를 저장하고 여행에 연결했어요.');
            return;
          }
          if (widget.isNew) AppState.I.update();
          Navigator.of(context).pop();
          showMock(context, '코스를 저장했어요.');
        }),
      ]),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          radius: 18,
          child: Row(children: [
            Expanded(
              child: Text(c.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
            ),
            GestureDetector(
              onTap: _renameCourse,
              child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.ink4),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: ok ? AppColors.successTint : const Color(0xFFFFF6E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 17, color: ok ? AppColors.success : AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok
                    ? '환급 조건 충족 · 지정관광지 $refundCount곳 · 1박 포함'
                    : '환급 조건 미충족 · 지정관광지 $refundCount/2곳${hasStay ? '' : ' · 숙박 없음'}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: ok ? const Color(0xFF177D43) : const Color(0xFF9A6800)),
              ),
            ),
          ]),
        ),
        for (final day in [1, 2]) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Row(children: [
              Text('DAY $day · 6.1${3 + day} (${day == 1 ? '토' : '일'})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.2)),
              const Spacer(),
              Text('${c.stops.where((s) => s.day == day).length}곳 · 이동 ${day == 1 ? 38 : 22}분',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
            ]),
          ),
          _reorderableDayList(day),
          GestureDetector(
            onTap: () async {
              final added = await Navigator.of(context).push<CourseStop>(
                  MaterialPageRoute(builder: (_) => CourseSearchScreen(day: day)));
              if (added != null) setState(() => c.stops.add(added));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.p50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.p200, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_rounded, size: 17, color: AppColors.p600),
                const SizedBox(width: 7),
                Text('DAY $day에 장소 추가',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _renameCourse() async {
    final ctl = TextEditingController(text: widget.course.title);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('코스 이름', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surf,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => widget.course.title = name);
    AppState.I.update();
  }

  /// DAY 안에서 장소 순서를 드래그로 바꾼다. 시간 슬롯은 자리에 남고 장소만 이동.
  void _reorderDay(int day, int oldIndex, int newIndex) {
    setState(() {
      final c = widget.course;
      final dayStops = c.stops.where((s) => s.day == day).toList();
      if (newIndex > oldIndex) newIndex--;
      final slotTimes = dayStops.map((s) => s.time).toList();
      dayStops.insert(newIndex, dayStops.removeAt(oldIndex));
      for (var i = 0; i < dayStops.length; i++) {
        dayStops[i].time = slotTimes[i];
      }
      final before = c.stops.where((s) => s.day < day).toList();
      final after = c.stops.where((s) => s.day > day).toList();
      c.stops
        ..clear()
        ..addAll([...before, ...dayStops, ...after]);
    });
  }

  Widget _reorderableDayList(int day) {
    final dayStops = widget.course.stops.where((s) => s.day == day).toList();
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, _) => child,
      onReorder: (o, n) => _reorderDay(day, o, n),
      children: [
        for (var i = 0; i < dayStops.length; i++)
          KeyedSubtree(
            key: ObjectKey(dayStops[i]),
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: _editStop(dayStops[i], i),
            ),
          ),
      ],
    );
  }

  Widget _editStop(CourseStop s, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: s.stay ? AppColors.mintTint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.ink4),
          ),
        ),
        const SizedBox(width: 8),
        EmojiBox(s.emoji, size: 40, fontSize: 20, color: s.stay ? Colors.white : AppColors.surf, radius: 13),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const SizedBox(height: 5),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(999)),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 11, color: AppColors.p700),
                  const SizedBox(width: 4),
                  Text(s.time,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.p700)),
                ]),
              ),
              const SizedBox(width: 5),
              if (s.refund)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.mintTint, borderRadius: BorderRadius.circular(999)),
                  child: Text(s.stay ? '숙박 필수 ✓' : '환급 인정',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.mintDeep)),
                ),
            ]),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => widget.course.stops.remove(s)),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
          ),
        ),
      ]),
    );
  }
}

/// 장소 검색 (코스에 추가).
class CourseSearchScreen extends StatefulWidget {
  const CourseSearchScreen({super.key, required this.day});
  final int day;

  @override
  State<CourseSearchScreen> createState() => _CourseSearchScreenState();
}

class _CourseSearchScreenState extends State<CourseSearchScreen> {
  int _cat = 0;
  int? _added;

  static const _results = [
    ('백련사', '사찰 · 강진군 도암면 만덕리', true, '🛕'),
    ('다산초당', '관광지 · 강진군 도암면 만덕리', false, '🏯'),
    ('가우도 오션뷰 카페', '카페 · 강진군 대구면 저두리', false, '☕'),
    ('병영 설성식당', '한정식 · 강진군 병영면 성동리', false, '🍖'),
    ('영랑생가', '관광지 · 강진군 강진읍 남성리', true, '🏡'),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'DAY ${widget.day}에 장소 추가',
      cta: CtaBar(children: [
        PrimaryButton(_added == null ? '장소를 선택하세요' : '1곳 추가하고 돌아가기',
            disabled: _added == null,
            onTap: () {
              final r = _results[_added!];
              Navigator.of(context).pop(CourseStop(
                day: widget.day,
                time: '16:00',
                emoji: r.$4,
                name: r.$1,
                tag: r.$2.split(' ').first,
                refund: r.$3,
              ));
            }),
      ]),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.card),
          child: const Row(children: [
            Icon(Icons.search_rounded, size: 20, color: AppColors.ink4),
            SizedBox(width: 10),
            Text('강진 가볼만한 곳',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9)),
          ]),
        ),
        CatChips(
          labels: const ['전체', '관광지', '맛집', '카페', '숙소'],
          selected: _cat,
          onChanged: (i) => setState(() => _cat = i),
        ),
        Container(
          height: 188,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFEDF4FA), borderRadius: BorderRadius.circular(18)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.map_outlined, size: 40, color: AppColors.p400),
            SizedBox(height: 8),
            Text('강진군 일대 · 검색 결과 지도 (목업)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(children: [
            const Text('검색 결과',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
            const Spacer(),
            Text('${_results.length}곳',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
          ]),
        ),
        for (var i = 0; i < _results.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: _added == i ? AppColors.p50 : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: _added == i
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_results[i].$1,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text(_results[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                    ),
                    if (_results[i].$3) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.mintTint, borderRadius: BorderRadius.circular(999)),
                        child: const Text('환급 인정',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.mintDeep)),
                      ),
                    ],
                  ]),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() => _added = _added == i ? null : i),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _added == i ? AppColors.success : AppColors.p50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_added == i ? Icons.check_rounded : Icons.add_rounded,
                      size: 21, color: _added == i ? Colors.white : AppColors.p600),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
