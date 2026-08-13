import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import 'saved_course_list_screen.dart';
import 'youtube_course_analysis_screen.dart';

/// 시안 색. 스포이드로 뽑은 값이라 AppColors 토큰과 별개로 둔다.
const _brandBlue = AppColors.p500;
const _pageBg = AppColors.bg;
const _fieldLine = Color(0xFFE6EAF0);
const _rowLine = Color(0xFFF1F4F8);

const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x0F1B3A5B), blurRadius: 18, offset: Offset(0, 5)),
];

/// 유튜브 링크에서 영상 ID를 뽑는다. watch / youtu.be / shorts / embed 를 받는다.
String? youtubeVideoId(String raw) {
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

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays == 1) return '어제';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}.$month.$day';
}

class YoutubeCourseStartScreen extends StatefulWidget {
  const YoutubeCourseStartScreen({super.key, required this.tripDetail});

  final TripDetail tripDetail;

  @override
  State<YoutubeCourseStartScreen> createState() =>
      _YoutubeCourseStartScreenState();
}

class _YoutubeCourseStartScreenState extends State<YoutubeCourseStartScreen> {
  final _urlController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
    if (youtubeVideoId(url) == null) {
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
    final regionName = widget.tripDetail.trip.regionName;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink7,
        title: const Text('코스 생성',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
                  .take(3 - pending.length)
                  .toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth > 640 ? 560.0 : constraints.maxWidth;
              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 36),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Hero(regionName: regionName),
                          const SizedBox(height: 20),
                          _LinkInputCard(
                            controller: _urlController,
                            errorMessage: _errorMessage,
                            regionName: regionName,
                            onChanged: () {
                              setState(() => _errorMessage = null);
                            },
                            onPaste: _paste,
                            onAnalyze: _analyze,
                          ),
                          const SizedBox(height: 16),
                          _RecentCard(
                            pending: pending,
                            saved: saved,
                            onAll: _openSavedCourses,
                            onOpenPending: _openPending,
                            onOpenSaved: (_) => _openSavedCourses(),
                          ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.regionName});

  final String regionName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '유튜브 영상을\n'),
                      TextSpan(
                        text: '코스로 만들어요',
                        style: TextStyle(color: _brandBlue),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: AppColors.ink9,
                    fontSize: 27,
                    height: 1.32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '영상 속 장소와 동선을 찾아\n여행 코스로 정리해드려요.',
                  style: const TextStyle(
                    color: AppColors.ink5,
                    fontSize: 12.5,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        const _PlayBadge(),
      ],
    );
  }
}

/// 시안의 입체 유튜브 배지. 뒤에 반투명 카드 두 장을 겹쳐 두께를 만든다.
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            top: 6,
            child: Transform.rotate(
              angle: -0.20,
              child: _card(const Color(0xFFD9E7F7), 78, 74),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 4,
            child: Transform.rotate(
              angle: 0.24,
              child: _card(const Color(0xFFEFE6F6), 78, 74),
            ),
          ),
          Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 78,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B6B), Color(0xFFF01A1A)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4DF01A1A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _LinkInputCard extends StatelessWidget {
  const _LinkInputCard({
    required this.controller,
    required this.errorMessage,
    required this.regionName,
    required this.onChanged,
    required this.onPaste,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final String? errorMessage;
  final String regionName;
  final VoidCallback onChanged;
  final VoidCallback onPaste;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final videoId = youtubeVideoId(controller.text);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '유튜브 링크를 입력하세요',
            style: TextStyle(
              color: AppColors.ink9,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onAnalyze(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink9,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'https://www.youtube.com/watch?v=...',
              hintStyle: const TextStyle(
                color: AppColors.ink4,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              errorText: errorMessage,
              errorStyle: const TextStyle(fontSize: 11.5),
              // 시안의 고리 아이콘 자리를 붙여넣기 버튼으로 쓴다.
              // 모바일에서 링크를 손으로 치게 두면 안 된다.
              suffixIcon: IconButton(
                onPressed: onPaste,
                icon: const Icon(Icons.link_rounded, size: 20),
                color: AppColors.ink4,
                tooltip: '클립보드에서 붙여넣기',
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 44),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(14, 15, 4, 15),
              border: _fieldBorder(_fieldLine),
              enabledBorder: _fieldBorder(_fieldLine),
              focusedBorder: _fieldBorder(_brandBlue, width: 1.3),
              errorBorder: _fieldBorder(AppColors.danger),
              focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.3),
            ),
          ),
          // 링크가 들어오기 전에는 자리를 차지하지 않는다.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child:
                videoId == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _VideoPreview(
                        videoId: videoId,
                        regionName: regionName,
                      ),
                    ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome_rounded, size: 17),
              iconAlignment: IconAlignment.end,
              label: const Text('분석하기'),
              style: FilledButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.videoId, required this.regionName});

  final String videoId;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Thumbnail(videoId: videoId, width: 78, height: 52),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '영상을 찾았어요',
                      style: TextStyle(
                        color: AppColors.ink9,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$regionName 코스로 정리할 준비가 됐어요.',
                  style: const TextStyle(
                    color: AppColors.ink5,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.videoId,
    required this.width,
    required this.height,
    this.fallbackIcon = Icons.route_rounded,
  });

  final String? videoId;
  final double width;
  final double height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCEBFA), Color(0xFFCFE9F7)],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(fallbackIcon, color: _brandBlue, size: 22),
    );
    final id = videoId;
    if (id == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.network(
        'https://img.youtube.com/vi/$id/mqdefault.jpg',
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.pending,
    required this.saved,
    required this.onAll,
    required this.onOpenPending,
    required this.onOpenSaved,
  });

  final List<PendingYoutubeCourseJob> pending;
  final List<SavedCourse> saved;
  final VoidCallback onAll;
  final ValueChanged<PendingYoutubeCourseJob> onOpenPending;
  final ValueChanged<SavedCourse> onOpenSaved;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final job in pending)
        _RecentRow(
          videoId: youtubeVideoId(job.youtubeUrl),
          fallbackIcon: Icons.hourglass_top_rounded,
          title: '${job.regionName} 영상 코스',
          time: _relativeTime(job.createdAt),
          detailIcon: Icons.autorenew_rounded,
          detail: '분석 중',
          onTap: () => onOpenPending(job),
        ),
      for (final course in saved)
        _RecentRow(
          videoId: null,
          fallbackIcon: Icons.route_rounded,
          title:
              course.title.trim().isEmpty
                  ? '${course.regionName} 여행 코스'
                  : course.title,
          time: _relativeTime(course.createdAt),
          detailIcon: Icons.place_rounded,
          detail: '장소 ${course.stops.length}개',
          onTap: () => onOpenSaved(course),
        ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 12, rows.isEmpty ? 18 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '최근 분석',
                  style: TextStyle(
                    color: AppColors.ink9,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // 볼 이력이 없으면 빈 목록으로 보내지 않는다.
              if (rows.isNotEmpty)
                TextButton.icon(
                  onPressed: onAll,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded, size: 17),
                  label: const Text('전체 보기'),
                  style: TextButton.styleFrom(
                    foregroundColor: _brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const SizedBox(height: 36),
            ],
          ),
          if (rows.isEmpty)
            const _RecentEmpty()
          else
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, thickness: 1, color: _rowLine),
              rows[index],
            ],
        ],
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 2),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.ondemand_video_rounded,
              color: AppColors.ink4,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 분석한 영상이 없어요',
                  style: TextStyle(
                    color: AppColors.ink7,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '위에 유튜브 링크를 넣으면 여기에 쌓여요.',
                  style: TextStyle(
                    color: AppColors.ink4,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.videoId,
    required this.fallbackIcon,
    required this.title,
    required this.time,
    required this.detailIcon,
    required this.detail,
    required this.onTap,
  });

  final String? videoId;
  final IconData fallbackIcon;
  final String title;
  final String time;
  final IconData detailIcon;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            _Thumbnail(
              videoId: videoId,
              width: 52,
              height: 52,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(width: 12),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.ink4,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: AppColors.ink4,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(detailIcon, size: 12, color: AppColors.ink4),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink4,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.ink4,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
