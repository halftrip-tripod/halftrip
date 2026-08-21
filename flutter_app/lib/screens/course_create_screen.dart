import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import 'course_flow_screens.dart';
import 'region_course_builder_screen.dart';
import 'youtube_course_start_screen.dart';

/// 코스 만들기 방식 선택 (S1-4a) — 디자인: halftrip-design/course-create.html
/// ① AI 추천 ② 유튜브 영상 ③ 직접 만들기. 어느 방식이든 결과는 코스 편집으로 수렴.
class CourseCreateScreen extends StatelessWidget {
  const CourseCreateScreen({super.key, required this.tripDetail});

  final TripDetail tripDetail;

  void _openBuilder(BuildContext context, CourseBuildMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => RegionCourseBuilderScreen(
              regionId: tripDetail.trip.regionId,
              regionName: tripDetail.trip.regionName,
              tripId: tripDetail.trip.id,
              initialTripPlaces: tripDetail.selectedPlaces,
              initialMode: mode,
            ),
      ),
    );
  }

  Future<void> _openYoutubeInput(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubeCourseStartScreen(tripDetail: tripDetail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('코스 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '어떤 방식으로\n'),
                TextSpan(text: '코스', style: TextStyle(color: AppColors.p600)),
                TextSpan(text: '를 만들까요?'),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.ink9,
              letterSpacing: -1,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '만든 코스는 저장한 뒤 자유롭게 수정할 수 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink5,
            ),
          ),
          const SizedBox(height: 18),
          _MakeCard(
            icon: Icons.auto_awesome_rounded,
            iconBg: AppColors.p50,
            iconFg: AppColors.p600,
            title: 'AI 추천 코스',
            desc: '환급 조건 · 여행 취향에 맞는 코스를 자동으로 생성해요',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseAiScreen(tripDetail: tripDetail),
                  ),
                ),
          ),
          const SizedBox(height: 14),
          _MakeCard(
            icon: Icons.play_circle_fill_rounded,
            iconBg: AppColors.coralTint,
            iconFg: const Color(0xFFE0322B),
            title: '유튜브 영상으로 만들기',
            desc: '여행 브이로그 링크를 붙여넣으면 영상 속 장소로 코스를 완성해요',
            onTap: () => _openYoutubeInput(context),
          ),
          const SizedBox(height: 14),
          _MakeCard(
            icon: Icons.edit_rounded,
            iconBg: AppColors.mintTint,
            iconFg: AppColors.mintDeep,
            title: '직접 만들기',
            desc: '가고 싶은 장소를 검색해서 내 마음대로 코스를 구성해요',
            onTap: () => _openBuilder(context, CourseBuildMode.manual),
          ),
        ],
      ),
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 27, color: iconFg),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink9,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
        ],
      ),
    );
  }
}
