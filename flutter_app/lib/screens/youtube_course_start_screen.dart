import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import 'saved_course_list_screen.dart';
import 'youtube_course_analysis_screen.dart';

class YoutubeCourseStartScreen extends StatefulWidget {
  const YoutubeCourseStartScreen({super.key, required this.tripDetail});

  final TripDetail tripDetail;

  @override
  State<YoutubeCourseStartScreen> createState() =>
      _YoutubeCourseStartScreenState();
}

class _YoutubeCourseStartScreenState extends State<YoutubeCourseStartScreen> {
  static const _primary = Color(0xFF5847E8);
  static const _sampleUrl = 'https://www.youtube.com/watch?v=-c_KCDjGOe0';

  final _urlController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _videoId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (host.contains('youtube.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return queryId;
      final segments = uri.pathSegments;
      for (var index = 0; index < segments.length - 1; index++) {
        if (segments[index] == 'shorts' || segments[index] == 'embed') {
          return segments[index + 1];
        }
      }
    }
    return null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (!mounted || value.isEmpty) return;
    setState(() {
      _urlController.text = value;
      _urlController.selection = TextSelection.collapsed(offset: value.length);
      _errorMessage = null;
    });
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (_videoId(url) == null) {
      setState(() => _errorMessage = '올바른 유튜브 영상 링크를 입력해 주세요.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => YoutubeCourseAnalysisScreen(
              tripDetail: widget.tripDetail,
              youtubeUrl: url,
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _useSample() {
    setState(() {
      _urlController.text = _sampleUrl;
      _urlController.selection = const TextSelection.collapsed(
        offset: _sampleUrl.length,
      );
      _errorMessage = null;
    });
  }

  void _openPending(PendingYoutubeCourseJob job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => YoutubeCourseAnalysisScreen(
              tripDetail: widget.tripDetail,
              jobId: job.jobId,
            ),
      ),
    );
  }

  void _openSavedCourses() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedCourseListScreen(tripDetail: widget.tripDetail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff_rounded, color: _primary),
            SizedBox(width: 8),
            Text(
              '트립메이커',
              style: TextStyle(
                color: _primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: '알림',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final pending =
              controller
                  .pendingYoutubeJobsForTrip(widget.tripDetail.trip.id)
                  .take(2)
                  .toList();
          final saved =
              controller.savedCourses
                  .where(
                    (course) =>
                        course.regionId == widget.tripDetail.trip.regionId,
                  )
                  .take(2)
                  .toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth > 920 ? 880.0 : constraints.maxWidth;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroHeader(
                            regionName: widget.tripDetail.trip.regionName,
                          ),
                          const SizedBox(height: 26),
                          _YoutubeLinkField(
                            controller: _urlController,
                            errorMessage: _errorMessage,
                            onChanged: (_) {
                              setState(() => _errorMessage = null);
                            },
                            onPaste: _paste,
                            onClear: () {
                              setState(() {
                                _urlController.clear();
                                _errorMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          _VideoPreview(
                            videoId: _videoId(_urlController.text),
                            regionName: widget.tripDetail.trip.regionName,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF684EF2),
                                    Color(0xFF4938D5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x345847E8),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: TextButton.icon(
                                onPressed: _analyze,
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text('영상 분석하기'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(58),
                                  textStyle: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _useSample,
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                              ),
                              label: const Text('샘플 영상 보기'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(
                                  color: Color(0xFFD8D4F8),
                                ),
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const _SectionHeading(
                            title: '이렇게 만들어드려요',
                            sparkle: true,
                          ),
                          const SizedBox(height: 14),
                          const _FeatureGrid(),
                          if (pending.isNotEmpty || saved.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _RecentHeader(onAll: _openSavedCourses),
                            const SizedBox(height: 14),
                            for (final job in pending)
                              _RecentProjectCard(
                                title: '${job.regionName} 영상 코스 분석 중',
                                subtitle: '백그라운드에서 장소를 찾고 있어요',
                                status: '생성 중',
                                statusColor: const Color(0xFFF59E0B),
                                icon: Icons.hourglass_top_rounded,
                                onTap: () => _openPending(job),
                              ),
                            for (final course in saved)
                              _RecentProjectCard(
                                title:
                                    course.title.trim().isEmpty
                                        ? '${course.regionName} 여행 코스'
                                        : course.title,
                                subtitle:
                                    '${course.stops.length}개 장소 · '
                                    '${course.createdAt.year}.${course.createdAt.month.toString().padLeft(2, '0')}.${course.createdAt.day.toString().padLeft(2, '0')}',
                                status: '완료',
                                statusColor: const Color(0xFF16A34A),
                                icon: Icons.route_rounded,
                                onTap: _openSavedCourses,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.regionName});

  final String regionName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '영상으로 여행 만들기',
                style: TextStyle(
                  color: AppColors.ink9,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '유튜브 여행 영상을 붙여넣고, $regionName 여행 계획을 만들어보세요.',
                style: const TextStyle(
                  color: AppColors.ink5,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            '1 / 3',
            style: TextStyle(
              color: Color(0xFF5847E8),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _YoutubeLinkField extends StatelessWidget {
  const _YoutubeLinkField({
    required this.controller,
    required this.errorMessage,
    required this.onChanged,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController controller;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'YouTube 링크를 붙여넣어 주세요',
        errorText: errorMessage,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFF1F1F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('붙여넣기'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5847E8),
                  backgroundColor: const Color(0xFFF4F2FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E5EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E5EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF5847E8), width: 1.5),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.videoId, required this.regionName});

  final String? videoId;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    final id = videoId;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E9EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child:
          id == null
              ? const SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ondemand_video_rounded,
                        size: 34,
                        color: Color(0xFFB1B4C2),
                      ),
                      SizedBox(height: 9),
                      Text(
                        '링크를 입력하면 영상 미리보기가 나타나요',
                        style: TextStyle(
                          color: AppColors.ink4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final thumbnail = ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        'https://img.youtube.com/vi/$id/hqdefault.jpg',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const ColoredBox(
                              color: Color(0xFFF1F2F6),
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      ),
                    ),
                  );
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$regionName 여행 영상',
                        style: const TextStyle(
                          color: AppColors.ink9,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Row(
                        children: [
                          Icon(
                            Icons.smart_display_rounded,
                            color: Color(0xFFFF1F1F),
                            size: 20,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'YouTube',
                            style: TextStyle(
                              color: AppColors.ink5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '영상 속 관광지와 식당을 찾아 $regionName 여행 동선으로 구성합니다.',
                        style: const TextStyle(
                          color: AppColors.ink5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [thumbnail, const SizedBox(height: 14), info],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 5, child: thumbnail),
                      const SizedBox(width: 18),
                      Expanded(flex: 6, child: info),
                    ],
                  );
                },
              ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.sparkle = false});

  final String title;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.ink9,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (sparkle) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF8B7AF5),
            size: 19,
          ),
        ],
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.location_on_rounded, '장소 추출', '영상 속 방문지를 추출해 지도에 표시해드려요.'),
      (Icons.calendar_month_rounded, '일정 생성', '영상 순서대로 여행 일정을 구성해요.'),
      (
        Icons.account_balance_wallet_rounded,
        '가격 정보',
        '식당 가격대와 경비 작성에 필요한 정보를 모아요.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final feature in features)
              SizedBox(
                width: width,
                child: _FeatureCard(
                  icon: feature.$1,
                  title: feature.$2,
                  description: feature.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E8EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF5847E8)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink9,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.ink5,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.onAll});

  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _SectionHeading(title: '최근 프로젝트')),
        TextButton.icon(
          onPressed: onAll,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('전체 보기'),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink5),
        ),
      ],
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  const _RecentProjectCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8E9EF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 82,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8E4FF), Color(0xFFD7F3FF)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: const Color(0xFF5847E8), size: 30),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink9,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink4,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
