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
import 'tour_place_detail.dart';

// ───────────────────────── 코스 영속화 변환 (목업 Course ↔ 실스토어 SavedCourse)
// 코스의 원본 저장소는 controller.savedCourses(기기 영속) 하나다. 목업 Course는
// 화면 표시용 뷰모델일 뿐 — 코스함·여행 코스 보기 모두 실스토어에서 변환해 그린다.

/// 코스 스톱의 아이콘 — 태그(카테고리)에서 파생. 편집·저장·뷰 어디서나 같은 규칙으로
/// 그려야 "저장하니 음식점이 관광지 아이콘으로 바뀌는" 불일치가 안 생긴다.
/// 태그가 있으면 그에 맞게, 없으면 기본 핀(📍).
String courseStopEmoji(String tag) {
  if (tag.contains('맛집') || tag.contains('음식') || tag.contains('식당')) return '🍽️';
  if (tag.contains('카페')) return '☕';
  if (tag.contains('숙') || tag.contains('호텔') || tag.contains('펜션') || tag.contains('리조트')) {
    return '🏨';
  }
  if (tag.contains('관광주민증') || tag.contains('디지털')) return '🎫';
  if (tag.contains('자연')) return '🌿';
  if (tag.contains('역사') || tag.contains('문화')) return '🏛️';
  if (tag.contains('레포츠') || tag.contains('체험')) return '⛰️';
  if (tag.contains('쇼핑')) return '🛍️';
  if (tag.contains('축제') || tag.contains('공연') || tag.contains('행사')) return '🎪';
  if (tag.contains('관광') || tag.contains('환급') || tag.contains('명소')) return '🏞️';
  return '📍';
}

/// 목업 Course 스톱 → 영속 스톱. DAY·카테고리를 보존해야 다시 열었을 때 일정·아이콘이 산다.
List<SavedCourseStop> savedStopsFromCourse(List<CourseStop> stops) => [
      for (final s in stops)
        SavedCourseStop(
          placeId: s.placeId ?? 0,
          name: s.name,
          address: s.address ?? '',
          latitude: s.latitude ?? 0,
          longitude: s.longitude ?? 0,
          sourceType: s.refund ? 'HALF_PRICE' : 'MERCHANT',
          day: s.day,
          time: s.time,
          category: s.tag, // 관광지/맛집/숙소 원본 보존 (refund 불리언으로 뭉개지 않게)
        ),
    ];

/// 영속 SavedCourse → 표시용 Course.
Course courseFromSaved(
  SavedCourse saved, {
  CourseSource source = CourseSource.manual,
  String savedAgo = '',
}) {
  var emoji = '🗺️';
  for (final r in AppState.I.regions) {
    if (r.name == saved.regionName) {
      emoji = r.emoji;
      break;
    }
  }
  final dayCount = saved.stops.map((s) => s.day).toSet().length;
  return Course(
    emoji: emoji,
    region: saved.regionName,
    province: '',
    title: saved.title,
    source: source,
    durationLabel: dayCount >= 2 ? '${dayCount - 1}박 $dayCount일' : '당일치기',
    placeCount: saved.stops.length,
    refundOk: false,
    savedAgo: savedAgo,
    stops: [
      for (final s in saved.stops)
        () {
          // 카테고리 우선 복원 — 예전 저장분(category 빈값)만 sourceType으로 폴백.
          final cat = s.category.isNotEmpty
              ? s.category
              : switch (s.sourceType.toUpperCase()) {
                  'MERCHANT' => '가맹점',
                  'DIGITAL_TOUR_CARD' => '디지털 관광주민증',
                  _ => '관광지',
                };
          return CourseStop(
            day: s.day,
            time: s.time,
            emoji: courseStopEmoji(cat),
            name: s.name,
            tag: cat,
            refund: s.sourceType.toUpperCase() != 'MERCHANT',
            stay: cat.contains('숙'),
            latitude: s.latitude == 0 ? null : s.latitude,
            longitude: s.longitude == 0 ? null : s.longitude,
            address: s.address.isEmpty ? null : s.address,
            placeId: s.placeId == 0 ? null : s.placeId,
          );
        }(),
    ],
  );
}

// ───────────────────────── AI 코스 생성 유틸 (실서버 후보 → 일정 배치)

/// AI 코스 후보 하나 — 지정관광지·TourAPI 관광지·맛집을 한 형태로 모은다.
class _AiCand {
  _AiCand({
    required this.name,
    required this.category,
    required this.address,
    required this.description,
    required this.refund,
    this.latitude,
    this.longitude,
    this.placeId = 0,
  });
  final String name;
  final String category; // 관광지/맛집/숙소 …
  final String address;
  final String description;
  final bool refund; // 환급 인정(지정관광지)
  final double? latitude;
  final double? longitude;
  final int placeId;

  Map<String, dynamic> toAiJson() => {
        'name': name,
        'category': category,
        'address': address,
        'description': description,
        'eligibleForRefund': refund,
      };
}

String _aiNormName(String s) => s.replaceAll(RegExp(r'\s+|\(.*\)'), '').trim();

CourseStop _aiCandToStop(_AiCand c, int day) => CourseStop(
      day: day,
      time: '',
      emoji: courseStopEmoji(c.category),
      name: c.name,
      tag: c.category.isEmpty ? '관광지' : c.category,
      refund: c.refund,
      stay: c.category.contains('숙'),
      latitude: c.latitude,
      longitude: c.longitude,
      address: c.address.isEmpty ? null : c.address,
      placeId: c.placeId == 0 ? null : c.placeId,
    );

/// 취향 우선순위 기반 규칙 정렬 (LLM 실패/빈 결과 시 대체).
/// 환급 인정 관광지 2곳은 반드시 앞쪽에 포함해 환급 조건을 보장한다.
List<_AiCand> _rankAiCands(List<_AiCand> cands, List<String> prefs, int nights) {
  int score(_AiCand c) {
    final text = '${c.name} ${c.category} ${c.address} ${c.description}';
    var total = c.refund ? 5 : 0; // 환급 인정 약간 가산
    for (var i = 0; i < prefs.length; i++) {
      final keywords = switch (prefs[i]) {
        '맛집' => ['맛집', '시장', '식당', '맛', '카페', '음식'],
        '자연' => ['자연', '공원', '생태', '해수욕장', '섬', '산', '숲', '해변'],
        '문화' => ['문화', '역사', '박물관', '유적', '초당', '생가', '청자'],
        _ => ['체험', '레포츠', '타워', '전망', '케이블', '짚'],
      };
      if (keywords.any(text.contains)) total += (prefs.length - i) * 10;
    }
    return total;
  }

  final ranked = [...cands]..sort((a, b) => score(b).compareTo(score(a)));
  final maxStops = ((nights + 1) * 4).clamp(4, 20);
  final picked = ranked.take(maxStops).toList();
  // 환급 인정 관광지 2곳 보장 — 부족하면 뒤에서 끌어와 채운다.
  final refundInPicked = picked.where((c) => c.refund).length;
  if (refundInPicked < 2) {
    final more = ranked.where((c) => c.refund && !picked.contains(c)).take(2 - refundInPicked);
    picked.addAll(more);
  }
  return picked;
}

/// AI 후보 수집 — 지정관광지(환급) + TourAPI 관광지·맛집을 이름 기준으로 병합.
/// 맛집이 빠져 있던 문제의 근본 픽스: 취향 1순위가 맛집이어도 후보에 맛집이 있어야 뽑힌다.
Future<List<_AiCand>> _buildAiCandidates(dynamic controller, int regionId) async {
  final repo = controller.repository;
  final cands = <_AiCand>[];
  final seen = <String>{};

  void add(_AiCand c) {
    final key = _aiNormName(c.name);
    if (key.isEmpty || seen.contains(key)) return;
    seen.add(key);
    cands.add(c);
  }

  // ① 지정관광지(환급 인정) — 좌표·설명 보유.
  try {
    final detail = await repo.getPlaceInfoDetail(regionId);
    for (final p in detail.halfPricePlaces) {
      add(_AiCand(
        name: p.name, category: '관광지', address: p.address,
        description: p.description, refund: true,
        latitude: p.latitude, longitude: p.longitude, placeId: p.id,
      ));
    }
  } catch (_) {}

  // ② TourAPI 관광지·맛집 — 지정과 이름이 겹치면 지정(환급) 쪽 유지.
  for (final type in const ['관광지', '맛집']) {
    try {
      final tour = await repo.getRegionAttractions(regionId, type: type);
      for (final a in tour) {
        add(_AiCand(
          name: a.title,
          category: a.category.isEmpty ? type : a.category,
          address: a.address,
          description: '',
          refund: a.eligibleForRefund,
          latitude: a.latitude,
          longitude: a.longitude,
        ));
      }
    } catch (_) {}
  }
  return cands;
}

/// 생성 결과에 환급 인정 관광지가 2곳 미만이면 후보에서 채워 넣는다 (DAY1 뒤쪽에 추가).
List<CourseStop> _ensureAiRefund(List<CourseStop> stops, List<_AiCand> cands) {
  final refundCount = stops.where((s) => s.refund).length;
  if (refundCount >= 2) return stops;
  final have = {for (final s in stops) _aiNormName(s.name)};
  final extras = cands
      .where((c) => c.refund && !have.contains(_aiNormName(c.name)))
      .take(2 - refundCount)
      .map((c) => _aiCandToStop(c, 1));
  return [...stops, ...extras];
}

/// 후보 목록 → nights 기준으로 DAY 배분 (하루 약 4곳). 취향·환급 반영은 상위에서 이미 정렬됨.
List<CourseStop> _scheduleAiCands(List<_AiCand> cands, int nights) {
  final days = nights + 1;
  final perDay = (cands.length / days).ceil().clamp(2, 5);
  final stops = <CourseStop>[];
  var day = 1, inDay = 0;
  for (final c in cands) {
    if (inDay >= perDay && day < days) {
      day++;
      inDay = 0;
    }
    stops.add(_aiCandToStop(c, day));
    inDay++;
  }
  return stops;
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
      Navigator.of(context).push(MaterialPageRoute(
          settings: const RouteSettings(name: kCourseCreationFlowRoute),
          builder: (_) => builder(region)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: kCourseCreationFlowRoute),
        builder: (_) => CourseRegionScreen(onPicked: builder)));
  }

  /// 코스함(실스토어)의 같은 지역 코스 중 하나를 골라 이 여행의 확정 코스로 연결한다.
  Future<void> _pickFromSaved(BuildContext context, Trip trip) async {
    final controller = AppScope.of(context);
    // 원본은 기기 영속 코스함 — 인메모리 목업(AppState.I.courses)이 아니라 실스토어를 보여준다.
    final saved = controller.savedCourses
        .where((c) => c.regionName == trip.region)
        .toList();
    final candidates = [for (final s in saved) courseFromSaved(s)];
    final picked = await showAppSheet<int>(
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
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('이 지역으로 저장한 코스가 아직 없어요.',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink5)),
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
                onTap: () => Navigator.of(ctx).pop(i),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
    if (picked == null || !context.mounted) return;
    final pickedSaved = saved[picked];
    // 실스토어 기준으로 여행-코스 연결 (여행 상세가 selectedCourseForTrip으로 읽는다).
    await controller.selectCourseForTrip(
        tripId: trip.backendId ?? 0, courseId: pickedSaved.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // 방식 선택 화면 닫고 여행 상세 복귀
    showMock(context, '코스함의 "${pickedSaved.title}" 코스를 이 여행에 연결했어요.');
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
          onTap: () {
            // 여행에서 만들면 그 여행 기간, 아니면 당일치기 기본(1박2일 고정 금지).
            final nights = forTrip?.nights;
            final duration = nights == null || nights == 0
                ? '당일치기'
                : '$nights박 ${nights + 1}일';
            _go(context, (r) => CourseEditScreen(
                  course: Course(
                    emoji: r.emoji, region: r.name, province: r.province,
                    title: '${r.name} 나만의 코스', source: CourseSource.manual,
                    durationLabel: duration,
                    placeCount: 0, refundOk: false,
                    savedAgo: '방금 저장', stops: [],
                  ),
                  isNew: true,
                  forTrip: forTrip,
                ));
          },
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
                MaterialPageRoute(
                    settings:
                        const RouteSettings(name: kCourseCreationFlowRoute),
                    builder: (_) => widget.onPicked(r))),
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
      // 후보 = 지정관광지(환급) + TourAPI 관광지 + 맛집. category·좌표 포함해 취향/동선 반영.
      final cands = await _buildAiCandidates(controller, matched.first.id);
      if (cands.isEmpty) {
        throw Exception('추천할 장소 데이터가 없습니다.');
      }
      try {
        // FastAPI LLM으로 실제 코스 생성 — 테마 우선순위·환급조건·일수(nights) 반영.
        final aiService = CourseAiService(AppConfig.fromEnvironment());
        final result = await aiService.generate(
          regionName: widget.region.name,
          nights: _nights,
          people: _people,
          themePriority: preferences,
          candidates: cands.map((c) => c.toAiJson()).toList(),
        );
        final byName = {for (final c in cands) _aiNormName(c.name): c};
        final sorted = [...result.stops]..sort((a, b) =>
            a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
        final built = <CourseStop>[];
        for (final rs in sorted) {
          final cand = byName[_aiNormName(rs.name)];
          if (cand == null) continue; // 후보 밖 이름은 버림
          // 카테고리는 LLM이 주면 우선, 아니면 후보값. 일차는 nights 범위로 클램프.
          final cat = rs.category.isNotEmpty ? rs.category : cand.category;
          built.add(_aiCandToStop(
            _AiCand(
              name: cand.name, category: cat, address: cand.address,
              description: cand.description, refund: cand.refund,
              latitude: cand.latitude, longitude: cand.longitude, placeId: cand.placeId,
            ),
            rs.day.clamp(1, _nights + 1),
          ));
        }
        stops = built.isNotEmpty
            ? built
            : _scheduleAiCands(_rankAiCands(cands, preferences, _nights), _nights);
      } catch (_) {
        // FastAPI 호출 실패(네트워크/키 미설정 등) — 클라이언트 규칙 기반 대체.
        stops = _scheduleAiCands(_rankAiCands(cands, preferences, _nights), _nights);
      }
      // 환급 인정 관광지 2곳 보장.
      stops = _ensureAiRefund(stops, cands);
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
          PrimaryButton('내 코스함에 저장', icon: Icons.bookmark_rounded, onTap: () async {
            final courseStops = stops.isEmpty ? gangjinStops() : stops;
            final c = Course(
              emoji: region.emoji, region: region.name, province: region.province,
              title: '${region.name} 환급 보장 코스', source: CourseSource.ai,
              durationLabel: nights == 0 ? '당일치기' : '$nights박 ${nights + 1}일',
              placeCount: courseStops.length, refundOk: true, savedAgo: '방금 저장',
              stops: courseStops,
            );
            if (forTrip != null) {
              // 여행 연결 경로 — 여행 상세(_openCourseCreate)가 실스토어 저장까지 맡는다.
              forTrip!.course = c;
              AppState.I.update();
              // 여행 상세 → 코스 만들기 → (시뮬) 스택이므로 두 번 pop = 여행 상세 복귀.
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              showMock(context, '코스를 저장하고 ${forTrip!.name} 여행에 연결했어요.');
              return;
            }
            // 코스함 경로 — 원본은 실스토어(기기 영속)에 저장. 지역 id는 이름으로 해석.
            final controller = AppScope.of(context);
            var regionId = 0;
            try {
              final regions = await controller.repository.getRegions();
              for (final r in regions) {
                if (r.name == region.name) {
                  regionId = r.id;
                  break;
                }
              }
            } catch (_) {}
            await controller.saveCourse(SavedCourse(
              id: 'gen-${DateTime.now().millisecondsSinceEpoch}',
              regionId: regionId,
              regionName: region.name,
              title: c.title,
              preferences: const [],
              stops: savedStopsFromCourse(courseStops),
              createdAt: DateTime.now(),
            ));
            if (!context.mounted) return;
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
      height: 188,
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
          for (final (i, s) in list.where((s) => s.day == day).indexed)
            _CourseStopRow(
              stop: s,
              number: i + 1,
              selected: (s.placeId ?? s.name.hashCode) == selectedStopId,
              onTap: onStopTap == null ? null : () => onStopTap!(s),
            ),
        ],
    ]);
  }
}

/// 코스 보기 (읽기 전용) — 저장 코스·여행 코스에서 진입.
/// 지도·DAY 토글·타임라인 연동은 생성 결과 화면(CourseSimScreen)과 같은 구성.
/// 편집 진입: 코스함에서는 하단 풀버튼, 여행 상세에서 열 땐(editInAppBar) 우측 상단 연필.
class CourseViewScreen extends StatefulWidget {
  const CourseViewScreen({
    super.key,
    required this.course,
    this.onMore,
    this.onEdited,
    this.onDelete,
  });
  final Course course;

  /// 우측 상단 ⋯ — 여행 코스일 때만: 등록취소/코스함삭제 시트.
  final VoidCallback? onMore;

  /// 편집기(CourseEditScreen)에서 돌아온 뒤 호출 — 실스토어에 변경을 반영할 때 쓴다.
  final VoidCallback? onEdited;

  /// 우측 상단 삭제 — 코스함에서 볼 때(⋯ 없이 바로 삭제).
  final VoidCallback? onDelete;

  @override
  State<CourseViewScreen> createState() => _CourseViewScreenState();
}

class _CourseViewScreenState extends State<CourseViewScreen> {
  /// 지도에 표시할 일차 (1박2일이면 DAY 1/2 토글).
  int _mapDay = 1;

  /// 상세 일정에서 탭한 장소 — 지도를 그 핀으로 이동시키고 정보창을 연다.
  int? _focusStopId;

  /// 편집은 어느 진입이든 통일된 CourseEditScreen 하나로.
  void _openEdit() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CourseEditScreen(course: widget.course)))
        .then((_) {
      widget.onEdited?.call();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final days = c.stops.map((s) => s.day).toSet().toList()..sort();
    final mapStops =
        c.stops.where((s) => days.length < 2 || s.day == _mapDay).toList();
    return DetailScaffold(
      title: c.title,
      // 수정은 우측 상단 연필로 통일. 여행 코스면 ⋯(등록취소/삭제), 코스함이면 삭제 아이콘.
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 21),
          tooltip: '코스 수정',
          onPressed: _openEdit,
        ),
        if (widget.onMore != null)
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            tooltip: '더보기',
            onPressed: widget.onMore,
          )
        else if (widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
            tooltip: '코스 삭제',
            onPressed: widget.onDelete,
          ),
      ],
      children: [
        if (c.refundOk)
          const FitBanner(
              title: '이 코스로 환급 조건 100% 충족', subtitle: '지정관광지 2곳 · 1박 숙박 · 인정 결제 포함'),
        // 지도 + 일차 토글 + 일정을 한 덩어리로 — 스캐폴드 기본 간격이 사이에 안 끼게.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c.stops.isNotEmpty) ...[
            _buildStopsMap(context, mapStops, focusId: _focusStopId),
            if (days.length >= 2) ...[
              const SizedBox(height: 8),
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
          ],
          _TimelineSection(
            stops: c.stops,
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

/// 코스 일정 항목 — 뷰·편집 공용. 앞의 [number] 원은 지도 핀 번호와 일치한다.
/// [editable]이면 삭제(×)·드래그 핸들을 붙인다. 시간은 표시하지 않는다.
class _CourseStopRow extends StatelessWidget {
  const _CourseStopRow({
    super.key,
    required this.stop,
    required this.number,
    this.editable = false,
    this.selected = false,
    this.index,
    this.onTap,
    this.onDelete,
  });
  final CourseStop stop;

  /// 1부터 시작하는 방문 순번 (DAY별로 리셋 — 지도 핀 번호와 동일).
  final int number;
  final bool editable;

  /// 지도 연동에서 이 장소가 선택된 상태 — 파란 테두리·틴트.
  final bool selected;

  /// 편집 모드에서 드래그 핸들에 쓸 인덱스.
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tag = stop.tag;
    final isFood = tag.contains('맛집') || tag.contains('음식') || tag.contains('식당');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // 지도 핀과 같은 번호 원 — 카드 밖 왼쪽.
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle),
          child: Text('$number',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? AppColors.p50 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: selected ? Border.all(color: AppColors.p500, width: 1.4) : null,
                boxShadow: AppShadows.soft,
              ),
              child: Row(children: [
                // 이동(드래그) 핸들 — 카드 안 왼쪽.
                if (editable && index != null) ...[
                  ReorderableDragStartListener(
                    index: index!,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.ink4),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                EmojiBox(courseStopEmoji(tag), size: 38, fontSize: 19, color: AppColors.surf, radius: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      // 카테고리 칩 — 태그가 있으면 그대로. '환급 인정'은 아래 민트 칩으로만 보여 중복 방지.
                      if (tag.isNotEmpty && tag != '환급 인정')
                        _tag(tag, isFood ? const Color(0xFFFFF1E0) : AppColors.p100,
                            isFood ? const Color(0xFFB8731B) : AppColors.p700),
                      if (stop.refund)
                        _tag(stop.stay ? '숙박 필수 ✓' : '환급 인정', AppColors.mintTint, AppColors.mintDeep),
                    ]),
                  ]),
                ),
                // 삭제(×) — 카드 안 오른쪽.
                if (editable) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
                    ),
                  ),
                ],
              ]),
            ),
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

  /// 저장 시각 표기 — 목업의 savedAgo 문자열을 실데이터로 대체.
  String _savedAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 저장';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전 저장';
    if (diff.inDays < 1) return '${diff.inHours}시간 전 저장';
    return '${diff.inDays}일 전 저장';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    // 원본은 실스토어(기기 영속) — 새로고침해도 남는 목록. 목업 코스는 안 섞는다.
    final savedList = controller.savedCourses;
    // 칩 순서는 지역 마스터 순서로 고정 — 코스 저장 순서에 따라 튀지 않게.
    final regions = AppState.I.regions
        .map((r) => r.name)
        .where((name) => savedList.any((c) => c.regionName == name))
        .toList();
    for (final c in savedList) {
      if (!regions.contains(c.regionName)) regions.add(c.regionName);
    }
    final labels = [
      '전체 ${savedList.length}',
      for (final r in regions)
        '$r ${savedList.where((c) => c.regionName == r).length}'
    ];
    final list = _filter == 0
        ? savedList
        : savedList.where((c) => c.regionName == regions[_filter - 1]).toList();

    return DetailScaffold(
      title: '저장 코스함',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: AppColors.p600),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  settings:
                      const RouteSettings(name: kCourseCreationFlowRoute),
                  builder: (_) => const CourseCreateScreen()))
              .then((_) => setState(() {})),
        ),
      ],
      children: [
        CatChips(labels: labels, selected: _filter, onChanged: (i) => setState(() => _filter = i)),
        if (savedList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(18)),
            child: const Text('저장한 코스가 없어요. 우측 상단 +로 코스를 만들어보세요.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5)),
          ),
        for (final saved in list)
          _savedCourseCard(context, controller, saved),
      ],
    );
  }

  Widget _savedCourseCard(
      BuildContext context, dynamic controller, SavedCourse saved) {
    final c = courseFromSaved(saved, savedAgo: _savedAgo(saved.createdAt));
    return _SavedCourseCardBody(
      course: c,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => Builder(builder: (viewContext) {
                    return CourseViewScreen(
                      course: c,
                      onEdited: () => controller.saveCourse(SavedCourse(
                        id: saved.id,
                        regionId: saved.regionId,
                        regionName: saved.regionName,
                        title: c.title,
                        preferences: saved.preferences,
                        stops: savedStopsFromCourse(c.stops),
                        createdAt: saved.createdAt,
                      )),
                      // 코스함 진입 — 우측 상단 삭제로 바로 코스함에서 제거.
                      onDelete: () async {
                        await controller.deleteSavedCourse(saved.id);
                        if (viewContext.mounted) {
                          Navigator.of(viewContext).pop();
                        }
                      },
                    );
                  })))
          .then((_) => setState(() {})),
    );
  }
}

class _SavedCourseCardBody extends StatelessWidget {
  const _SavedCourseCardBody({required this.course, required this.onTap});
  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = course;
    return AppCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            onTap: onTap,
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
  /// 지도에 표시할 일차 (1박2일이면 DAY 1/2 토글).
  int _mapDay = 1;

  /// 리스트에서 탭한 장소 — 지도를 그 핀 중심으로 이동시키고 정보창을 연다.
  int? _focusStopId;

  /// 코스가 며칠짜리인지 — 여행이면 여행 기간, 아니면 durationLabel/담긴 일차에서 유추.
  int _dayCount(Course c, Trip? trip) {
    if (trip != null) return trip.nights + 1;
    var maxDay = 1;
    for (final s in c.stops) {
      if (s.day > maxDay) maxDay = s.day;
    }
    final m = RegExp(r'(\d+)\s*박\s*(\d+)\s*일').firstMatch(c.durationLabel);
    final labelDays = m != null ? int.parse(m.group(2)!) : 1;
    return labelDays > maxDay ? labelDays : maxDay;
  }

  /// 리스트 행 탭 → 지도의 해당 핀을 가운데로 + 정보창 열기.
  void _focusStop(CourseStop s) {
    if (s.latitude == null || s.longitude == null) return;
    setState(() {
      final days = widget.course.stops.map((e) => e.day).toSet();
      if (days.length >= 2) _mapDay = s.day;
      _focusStopId = s.placeId ?? s.name.hashCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    // 환급 인정 관광지(지정관광지)를 몇 곳 담았는지. 반값여행은 보통 2곳 인증이 조건.
    final refundCount = c.stops.where((s) => s.refund).length;
    final refundOk = refundCount >= 2;
    // 코스 기간에 맞춰 DAY 수 결정 — 여행이면 여행 일정, 아니면 코스 기간/담긴 일차. (1박2일 고정 아님)
    final dayCount = _dayCount(c, widget.forTrip);
    final days = [for (var d = 1; d <= dayCount; d++) d];
    final activeDay = days.contains(_mapDay) ? _mapDay : 1;
    // 상단 지도 — 선택한 일차의 장소만 순서대로.
    final mapStops = c.stops.where((s) => s.day == activeDay).toList();

    return DetailScaffold(
      title: '코스 편집',
      cta: CtaBar(children: [
        PrimaryButton(widget.isNew ? '코스 저장' : '변경사항 저장', onTap: () async {
          final trip = widget.forTrip;
          if (trip != null) {
            // 여행 연결 경로 — 여행의 확정 코스로.
            if (widget.isNew) AppState.I.addCourse(c);
            trip.course = c;
            AppState.I.update();
            // 편집 → 방식 선택까지 닫고 여행 상세로 복귀.
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            showMock(context, '코스를 저장하고 여행에 연결했어요.');
            return;
          }
          if (widget.isNew) {
            // 새 코스는 기기 영속 스토어(코스함)에 저장해야 CourseSavedScreen에 뜬다.
            // (예전엔 인메모리 AppState에만 담아서 코스함에 안 보였음)
            final controller = AppScope.of(context);
            var regionId = 0;
            try {
              final regions = await controller.repository.getRegions();
              for (final r in regions) {
                if (r.name == c.region) {
                  regionId = r.id;
                  break;
                }
              }
            } catch (_) {}
            await controller.saveCourse(SavedCourse(
              id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
              regionId: regionId,
              regionName: c.region,
              title: c.title,
              preferences: const [],
              stops: savedStopsFromCourse(c.stops),
              createdAt: DateTime.now(),
            ));
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CourseSavedScreen()));
            showMock(context, '코스를 코스함에 저장했어요.');
            return;
          }
          // 기존 코스 편집: 뷰로 돌아가면 onEdited가 영속 반영.
          AppState.I.update();
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
        // 환급 인정 관광지 포함 여부 — 담은 스톱 중 지정관광지 개수로 판단(숙박은 미판정).
        if (c.stops.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: refundOk ? AppColors.successTint : const Color(0xFFFFF6E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(refundOk ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 17, color: refundOk ? AppColors.success : AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  refundOk
                      ? '환급 인정 관광지 $refundCount곳 포함'
                      : '환급 인정 관광지 $refundCount/2곳',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: refundOk ? const Color(0xFF177D43) : const Color(0xFF9A6800)),
                ),
              ),
            ]),
          ),
        // 상단 지도 + 일차 토글(1박2일 고정) — 뷰 화면과 동일 구성. 추가·이동 시 즉시 반영.
        if (c.stops.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildStopsMap(context, mapStops, focusId: _focusStopId),
            if (dayCount >= 2) ...[
              const SizedBox(height: 8),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final d in days) ...[
                      if (d != 1) const SizedBox(width: 8),
                      _DayChip(
                        label: 'DAY $d',
                        active: activeDay == d,
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
          ]),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Row(children: [
              Text('DAY $day · 6.1${3 + day} (${day == 1 ? '토' : '일'})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.2)),
              const Spacer(),
              Text('${c.stops.where((s) => s.day == day).length}곳',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
            ]),
          ),
          _reorderableDayList(day),
          GestureDetector(
            onTap: () async {
              final added = await Navigator.of(context).push<List<CourseStop>>(
                  MaterialPageRoute(builder: (_) => CourseSearchScreen(day: day, regionName: c.region)));
              if (added != null && added.isNotEmpty) setState(() => c.stops.addAll(added));
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

  /// DAY 안에서 장소 순서를 드래그로 바꾼다. 순서만 이동(시간 개념 없음) → 지도도 그 순서로 갱신.
  void _reorderDay(int day, int oldIndex, int newIndex) {
    setState(() {
      final c = widget.course;
      final dayStops = c.stops.where((s) => s.day == day).toList();
      if (newIndex > oldIndex) newIndex--;
      dayStops.insert(newIndex, dayStops.removeAt(oldIndex));
      final before = c.stops.where((s) => s.day < day).toList();
      final after = c.stops.where((s) => s.day > day).toList();
      c.stops
        ..clear()
        ..addAll([...before, ...dayStops, ...after]);
    });
  }

  Widget _reorderableDayList(int day) {
    final dayStops = widget.course.stops.where((s) => s.day == day).toList();
    if (dayStops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text('아직 담은 장소가 없어요.',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, _) => child,
      onReorder: (o, n) => _reorderDay(day, o, n),
      padding: const EdgeInsets.only(top: 10),
      children: [
        for (var i = 0; i < dayStops.length; i++)
          _CourseStopRow(
            key: ObjectKey(dayStops[i]),
            stop: dayStops[i],
            number: i + 1,
            editable: true,
            index: i,
            selected: (dayStops[i].placeId ?? dayStops[i].name.hashCode) == _focusStopId,
            onTap: () => _focusStop(dayStops[i]),
            onDelete: () => setState(() {
              widget.course.stops.remove(dayStops[i]);
              _focusStopId = null;
            }),
          ),
      ],
    );
  }
}

/// 장소 검색 (코스에 추가) — TourAPI 관광지/맛집/숙소 실시간.
class CourseSearchScreen extends StatefulWidget {
  const CourseSearchScreen({super.key, required this.day, required this.regionName});
  final int day;
  final String regionName;

  @override
  State<CourseSearchScreen> createState() => _CourseSearchScreenState();
}

class _CourseSearchScreenState extends State<CourseSearchScreen> {
  static const _cats = ['전체', '관광지', '맛집', '숙소'];
  int _cat = 0;
  int? _regionId;
  bool _regionResolved = false;
  String _query = '';
  List<PlaceItem> _designated = const [];
  final List<TourAttraction> _selected = [];
  Future<List<TourAttraction>>? _future;
  final _searchCtl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _resolveAndLoad();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _resolveAndLoad() async {
    final repo = AppScope.of(context).repository;
    try {
      final regions = await repo.getRegions();
      final match = regions.where(
          (r) => widget.regionName.startsWith(r.name) || r.name.startsWith(widget.regionName));
      _regionId = match.isNotEmpty
          ? match.first.id
          : (regions.isNotEmpty ? regions.first.id : null);
      // 환급 인정 관광지(지정관광지)도 검색에 섞기 위해 미리 로드.
      if (_regionId != null) {
        _designated = (await repo.getPlaceInfoDetail(_regionId!)).halfPricePlaces;
      }
    } catch (_) {
      _regionId = null;
    }
    _regionResolved = true;
    _reload();
  }

  void _reload() {
    final id = _regionId;
    final type = _cat == 0 ? null : _cats[_cat];
    setState(() {
      _future = id == null
          ? Future.value(const <TourAttraction>[])
          : _loadMerged(id, type, _query.isEmpty ? null : _query);
    });
  }

  /// TourAPI 결과에 환급 인정 관광지(지정관광지)를 섞는다. 이름이 겹치면 하나로(TourAPI 쪽에 환급 표시).
  Future<List<TourAttraction>> _loadMerged(int regionId, String? type, String? keyword) async {
    final tour = await AppScope.of(context)
        .repository
        .getRegionAttractions(regionId, type: type, keyword: keyword);
    // 지정관광지는 관광지 성격 → 전체/관광지 탭에서만 섞는다.
    if (type != null && type != '관광지') return tour;
    var designated = _designated;
    if (keyword != null && keyword.isNotEmpty) {
      designated = designated.where((d) => d.name.contains(keyword)).toList();
    }
    if (designated.isEmpty) return tour;
    final designatedNames = {for (final d in designated) _norm(d.name)};
    final matched = <String>{};
    final tourMarked = tour.map((r) {
      final key = _norm(r.title);
      if (designatedNames.contains(key)) {
        matched.add(key);
        return r.copyWith(eligibleForRefund: true);
      }
      return r;
    }).toList();
    final designatedOnly = designated
        .where((d) => !matched.contains(_norm(d.name)))
        .map((d) => TourAttraction(
              contentId: '',
              contentTypeId: '12',
              title: d.name,
              address: d.address,
              category: '환급 인정',
              tel: '',
              latitude: d.latitude,
              longitude: d.longitude,
              eligibleForRefund: true,
            ));
    return [...designatedOnly, ...tourMarked];
  }

  String _norm(String s) => s.replaceAll(RegExp(r'\s+|\(.*\)'), '').trim();

  /// 선택 식별 키 — contentId가 없는 지정관광지는 이름+주소로 구분(빈 contentId 충돌 방지).
  String _key(TourAttraction a) =>
      a.contentId.isNotEmpty ? a.contentId : '${a.title}|${a.address}';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'DAY ${widget.day}에 장소 추가',
      cta: CtaBar(children: [
        PrimaryButton(_selected.isEmpty ? '장소를 선택하세요' : '${_selected.length}곳 추가하고 돌아가기',
            disabled: _selected.isEmpty,
            onTap: () {
              Navigator.of(context).pop(<CourseStop>[
                for (final a in _selected)
                  CourseStop(
                    day: widget.day,
                    time: '',
                    emoji: courseStopEmoji(a.category),
                    name: a.title,
                    tag: a.category,
                    refund: a.eligibleForRefund,
                    stay: a.category.contains('숙'),
                    latitude: a.latitude,
                    longitude: a.longitude,
                    address: a.address,
                  ),
              ]);
            }),
      ]),
      children: [
        // 검색바 — 흰 카드 배경 + 넉넉한 높이
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.card),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 20, color: AppColors.ink4),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtl,
                onSubmitted: (v) {
                  _query = v.trim();
                  _reload();
                },
                onChanged: (v) => _query = v.trim(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink9),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '관광지·맛집·숙소 검색',
                  hintStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink4),
                ),
              ),
            ),
          ]),
        ),
        CatChips(
          labels: _cats,
          selected: _cat,
          onChanged: (i) {
            setState(() => _cat = i);
            _reload();
          },
        ),
        FutureBuilder<List<TourAttraction>>(
          future: _future,
          builder: (context, snapshot) {
            if (!_regionResolved || snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final results = snapshot.data ?? const <TourAttraction>[];
            if (results.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('검색 결과가 없어요.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                ),
              );
            }
            final markers = <PlaceMapMarkerData>[
              for (var i = 0; i < results.length; i++)
                if (results[i].latitude != null && results[i].longitude != null)
                  PlaceMapMarkerData(
                    id: i,
                    name: results[i].title,
                    address: results[i].address,
                    latitude: results[i].latitude!,
                    longitude: results[i].longitude!,
                    selected: _selected.any((s) => _key(s) == _key(results[i])),
                  ),
            ];
            return Column(children: [
              if (markers.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: PlaceMapView(
                    // 선택 집합이 바뀌면 재마운트 — 웹 구글맵이 마커 아이콘 변경(하늘→코랄)을
                    // 제자리 업데이트로는 반영하지 못해서 통째로 다시 그린다.
                    key: ValueKey(
                        'search-map-${markers.length}-${_selected.map(_key).join(',').hashCode}'),
                    markers: markers,
                    numberedMarkers: true,
                    emptyMessage: '지도에 표시할 위치가 없어요.',
                    kakaoEnabled: AppConfig.fromEnvironment().canUseKakaoMap,
                    height: 188,
                  ),
                ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Row(children: [
                  const Text('검색 결과',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
                  const Spacer(),
                  Text('${results.length}곳',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
                ]),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < results.length; i++)
                _ResultRow(
                  index: i,
                  regionId: _regionId,
                  attraction: results[i],
                  selected: _selected.any((s) => _key(s) == _key(results[i])),
                  onAdd: () => setState(() {
                    final existing =
                        _selected.indexWhere((s) => _key(s) == _key(results[i]));
                    if (existing >= 0) {
                      _selected.removeAt(existing);
                    } else {
                      _selected.add(results[i]);
                    }
                  }),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

/// 코스 검색 결과 행 — 번호 + 이름/카테고리·주소 + 추가(＋/✓). 이름 탭 시 TourAPI 상세.
class _ResultRow extends StatelessWidget {
  const _ResultRow(
      {required this.index,
      required this.attraction,
      required this.selected,
      required this.onAdd,
      this.regionId});
  final int index;
  final TourAttraction attraction;
  final bool selected;
  final VoidCallback onAdd;
  final int? regionId;

  @override
  Widget build(BuildContext context) {
    final a = attraction;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle),
          child: Text('${index + 1}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TourPlaceDetailScreen(attraction: a, regionId: regionId))),
            behavior: HitTestBehavior.opaque,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                ),
                if (a.eligibleForRefund) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.mintTint, borderRadius: BorderRadius.circular(999)),
                    child: const Text('환급 인정',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.mintDeep)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text('${a.category.isEmpty ? '' : '${a.category} · '}${a.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(12)),
            child: Icon(selected ? Icons.check_rounded : Icons.add_rounded,
                size: 21, color: AppColors.p600),
          ),
        ),
      ]),
    );
  }
}
