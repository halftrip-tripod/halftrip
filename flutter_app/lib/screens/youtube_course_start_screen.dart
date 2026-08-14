import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import 'youtube_course_analysis_screen.dart';

/// 시안 색. 스포이드로 뽑은 값이라 AppColors 토큰과 별개로 둔다.
const _brandBlue = AppColors.p500;
const _pageBg = AppColors.bg;
const _rowDivider = Color(0xFFF1F4F8);

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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink7,
        title: const Text('유튜브 코스 생성',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
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
                          const _Hero(),
                          const SizedBox(height: 20),
                          _LinkInputCard(
                            controller: _urlController,
                            errorMessage: _errorMessage,
                            onChanged: () {
                              setState(() => _errorMessage = null);
                            },
                            onPaste: _paste,
                            onAnalyze: _analyze,
                          ),
                          const SizedBox(height: 16),
                          // 시안의 하단 안내 — 분석 결과는 코스함에 쌓이므로
                          // 별도 "최근 분석" 목록은 두지 않는다(코스함과 중복).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(Icons.info_outline_rounded,
                                    size: 16, color: _brandBlue),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  '자막·화면에 장소 정보가 없으면 추출되지 않을 수 있어요.',
                                  style: const TextStyle(
                                    color: AppColors.ink5,
                                    fontSize: 12.5,
                                    height: 1.55,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '유튜브 링크를 넣으면\n'),
                      TextSpan(
                        text: '코스로 만들어드려요',
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
              ),
            ),
            SizedBox(width: 4),
            _PlayBadge(),
          ],
        ),
        const SizedBox(height: 6),
        // 마크 옆이 아니라 전체 폭에 두어 한 줄로 나오게 한다.
        const Text(
          '영상 속 장소와 동선을 찾아 코스와 계획표로 정리해드려요.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.ink5,
            fontSize: 12.5,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
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
      width: 74,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 3,
            top: 4,
            child: Transform.rotate(
              angle: -0.20,
              child: _card(const Color(0xFFD9E7F7), 48, 44),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 3,
            child: Transform.rotate(
              angle: 0.24,
              child: _card(const Color(0xFFEFE6F6), 48, 44),
            ),
          ),
          Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 48,
              height: 43,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B6B), Color(0xFFF01A1A)],
                ),
                borderRadius: BorderRadius.circular(13),
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
                size: 25,
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
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _LinkInputCard extends StatelessWidget {
  const _LinkInputCard({
    required this.controller,
    required this.errorMessage,
    required this.onChanged,
    required this.onPaste,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final String? errorMessage;
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
          // 시안의 카드 헤더 — 빨간 유튜브 점 + 타이틀.
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFF01A1A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 9),
              const Text(
                '유튜브 영상 링크',
                style: TextStyle(
                  color: AppColors.ink9,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onAnalyze(),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
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
              // 시안처럼 고리 아이콘은 왼쪽. 오른쪽은 상태에 따라
              // 붙여넣기(비어 있을 때) / 지우기(링크 있을 때) 버튼.
              prefixIcon: const Icon(Icons.link_rounded,
                  size: 19, color: AppColors.ink4),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 40),
              suffixIcon: controller.text.trim().isEmpty
                  ? IconButton(
                      onPressed: onPaste,
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      color: AppColors.ink4,
                      tooltip: '클립보드에서 붙여넣기',
                    )
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                      color: AppColors.ink4,
                      tooltip: '지우기',
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 44),
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              contentPadding: const EdgeInsets.fromLTRB(0, 14, 4, 14),
              border: _fieldBorder(Colors.transparent),
              enabledBorder: _fieldBorder(Colors.transparent),
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
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          Container(height: 1, color: _rowDivider),
                          const SizedBox(height: 14),
                          _VideoPreview(videoId: videoId),
                        ],
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

/// 링크 미리보기 — 시안처럼 큰 썸네일 + 제목 + 채널명.
/// 제목·채널명은 유튜브 oEmbed(키 불필요)로 가져온다. 영상 길이·조회수는
/// YouTube Data API(서버 키)가 필요해 서버 엔드포인트가 열리면 채운다.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.videoId});

  final String videoId;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  /// oEmbed 결과 캐시 — 같은 영상 재입력 시 재조회하지 않는다.
  static final Map<String, (String, String)> _metaCache = {};

  String? _title;
  String? _channel;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _title = null;
      _channel = null;
      _loadMeta();
    }
  }

  Future<void> _loadMeta() async {
    final id = widget.videoId;
    final cached = _metaCache[id];
    if (cached != null) {
      setState(() {
        _title = cached.$1;
        _channel = cached.$2;
      });
      return;
    }
    try {
      final uri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final title = json['title'] as String? ?? '';
      final channel = json['author_name'] as String? ?? '';
      if (title.isEmpty) return;
      _metaCache[id] = (title, channel);
      if (!mounted || widget.videoId != id) return;
      setState(() {
        _title = title;
        _channel = channel;
      });
    } catch (_) {
      // 조회 실패(웹 CORS·네트워크) — 기본 문구로 폴백.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Thumbnail(videoId: widget.videoId, width: 118, height: 78),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title ?? '영상을 찾았어요',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink9,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _channel?.isNotEmpty == true
                    ? _channel!
                    : '코스로 정리할 준비가 됐어요.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink5,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.videoId,
    required this.width,
    required this.height,
  });

  final String? videoId;
  final double width;
  final double height;

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
      child: const Icon(Icons.route_rounded, color: _brandBlue, size: 22),
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
