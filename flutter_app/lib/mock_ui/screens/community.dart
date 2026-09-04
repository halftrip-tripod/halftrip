import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../../core/app_scope.dart';
import '../../models/app_models.dart' show SavedCourse, SavedCourseStop;
import '../../utils/profile_presets.dart';
import '../state/app_state.dart';
import 'course_flow.dart' show CourseSavedScreen, CourseViewScreen;
import 'my_trips_tab.dart' show durationLabelOf;
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

String tagLabel(PostTag t) =>
    switch (t) { PostTag.review => '후기', PostTag.course => '코스', PostTag.ask => '질문', PostTag.info => '정보' };

(Color, Color) tagColors(PostTag t) => switch (t) {
      PostTag.review => (AppColors.p100, AppColors.p700),
      PostTag.course => (AppColors.mintTint, AppColors.mintDeep),
      PostTag.ask => (AppColors.warningTint, const Color(0xFFB8731B)),
      PostTag.info => (AppColors.track, AppColors.ink5),
    };

/// S4-1 커뮤니티 피드 (탭).
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  int _filter = 0;
  int _region = 0; // 0 = 전체
  static const _filters = ['인기', '최신', '후기', '코스', '질문', '정보'];

  @override
  void initState() {
    super.initState();
    // 셸 IndexedStack 자식이 const라 탭 전환만으론 build가 다시 돌지 않는다.
    // "인기 코스 보러 가기" 등이 거는 프리셋 요청을 직접 듣고 rebuild를 트리거해야
    // build 안의 소비 로직이 실행된다 (안 그러면 프리셋이 조용히 무시됨).
    AppState.I.communityRegion.addListener(_onPresetRequest);
    AppState.I.communityFilter.addListener(_onPresetRequest);
    // 탭이 다시 보일 때마다 최신 피드로 갱신 (다른 사용자 글·반응 반영).
    // initState는 앱당 1회라 이것만으론 첫 진입 이후 영영 갱신되지 않는다.
    AppState.I.tabShownTick.addListener(_onTabShown);
    _refreshFeed();
  }

  @override
  void dispose() {
    AppState.I.communityRegion.removeListener(_onPresetRequest);
    AppState.I.communityFilter.removeListener(_onPresetRequest);
    AppState.I.tabShownTick.removeListener(_onTabShown);
    super.dispose();
  }

  void _onTabShown() {
    if (!mounted || AppState.I.shownTab != 3) return;
    _refreshFeed();
  }

  Future<void> _refreshFeed() async {
    await AppState.I.refreshCommunityFromServer();
    if (mounted) setState(() {});
  }

  void _onPresetRequest() {
    // 소비(값→null 초기화) 시에도 리스너가 다시 불리므로 요청이 있을 때만 rebuild.
    if (!mounted) return;
    if (AppState.I.communityRegion.value == null &&
        AppState.I.communityFilter.value == null) {
      return;
    }
    setState(() {});
  }

  List<String> get _regionLabels {
    final names = <String>{for (final p in AppState.I.posts.where((p) => !p.private)) p.region};
    // 지역 마스터 순서 유지
    return ['전체', ...AppState.I.regions.map((r) => r.name).where(names.contains)];
  }

  List<Post> get _list {
    final regions = _regionLabels;
    final all = AppState.I.posts
        .where((p) => !p.private)
        .where((p) => _region == 0 || p.region == regions[_region])
        .toList();
    return switch (_filter) {
      0 => (all..sort((a, b) => b.likes.compareTo(a.likes))),
      1 => all,
      // 종류 필터(후기·코스·질문·정보)는 인기순(좋아요 많은 순)으로 보여준다.
      _ => (all.where((p) => tagLabel(p.tag) == _filters[_filter]).toList()
        ..sort((a, b) => b.likes.compareTo(a.likes))),
    };
  }

  Future<void> _pickRegion() async {
    final labels = _regionLabels;
    var query = '';
    final picked = await showAppSheet<String>(
      context,
      scrollable: true,
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = query.trim();
          final list = labels
              .where((l) => l == '전체' ? q.isEmpty : (q.isEmpty || l.contains(q)))
              .toList();
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('지역 필터',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setSheet(() => query = v),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9),
                  decoration: InputDecoration(
                    hintText: '지역 이름 검색',
                    hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink4),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.ink4),
                    filled: true,
                    fillColor: AppColors.surf,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ]),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Icon(
                      list[i] == '전체' ? Icons.public_rounded : Icons.place_outlined,
                      size: 20,
                      color: AppColors.ink5),
                  title: Text(list[i],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9)),
                  trailing: labels[_region] == list[i]
                      ? const Icon(Icons.check_rounded, size: 20, color: AppColors.p600)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(list[i]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ]);
        },
      ),
    );
    if (picked != null) setState(() => _region = _regionLabels.indexOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    // 다른 화면에서 "○○ 인기 코스 보러 가기"로 진입한 경우 지역 필터 프리셋.
    final requested = AppState.I.communityRegion.value;
    if (requested != null) {
      final idx = _regionLabels.indexOf(requested);
      if (idx > 0) _region = idx;
      AppState.I.communityRegion.value = null;
    }
    // "인기 코스 보러 가기" 등에서 넘어온 종류 필터 프리셋 ('코스' 칩 선택 상태로 진입).
    final requestedFilter = AppState.I.communityFilter.value;
    if (requestedFilter != null) {
      final fi = _filters.indexOf(requestedFilter);
      if (fi >= 0) _filter = fi;
      AppState.I.communityFilter.value = null;
    }

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _refreshFeed,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 100),
        children: [
          Row(children: [
            const Text('커뮤니티',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
            const Spacer(),
            _FilterPill(
              icon: Icons.place_outlined,
              label: _region == 0 ? '지역 전체' : _regionLabels[_region],
              active: _region != 0,
              onTap: _pickRegion,
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: _filters[_filter],
              onTap: () async {
                final f = await pickOption(context, title: '정렬 · 필터', options: _filters);
                if (f != null) setState(() => _filter = _filters.indexOf(f));
              },
            ),
          ]),
          const SizedBox(height: 16),
          if (_list.isEmpty)
            const _EmptyFeed()
          else
            for (final p in _list) ...[
              PostCard(post: p, onChanged: () => setState(() {})),
              const SizedBox(height: 14),
            ],
        ],
        ),
      ),
      // 글쓰기 FAB
      Positioned(
        right: 20,
        bottom: 20,
        child: GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CommunityWriteScreen()))
              .then((_) => setState(() {})),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.p500,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x590EA5E9), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Row(children: [
              Icon(Icons.edit_rounded, size: 17, color: Colors.white),
              SizedBox(width: 6),
              Text('글쓰기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// 커뮤니티 헤더의 필터 트리거 필 (지역·정렬 공용).
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onTap, this.icon, this.active = false});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.p100 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active ? null : AppShadows.soft,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: active ? AppColors.p700 : AppColors.ink5),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.p700 : AppColors.ink7)),
          Icon(Icons.expand_more_rounded,
              size: 17, color: active ? AppColors.p700 : AppColors.ink5),
        ]),
      ),
    );
  }
}

/// 지역상세 등에서 push하는 피드 화면 (탭 밖). [region]을 주면 그 지역 글만.
/// [courseOnly]면 코스 글·코스 첨부 글만 인기순으로 — 여행 상세의
/// "인기 코스 보러 가기"가 탭 전환 없이 이 화면을 push해 뒤로가기로 복귀한다.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key, this.region, this.courseOnly = false});
  final String? region;
  final bool courseOnly;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  @override
  Widget build(BuildContext context) {
    var posts = AppState.I.posts
        .where((p) => !p.private)
        .where((p) => widget.region == null || p.region == widget.region)
        .toList();
    if (widget.courseOnly) {
      posts = posts
          .where((p) => p.tag == PostTag.course || p.courseName != null)
          .toList()
        ..sort((a, b) => b.likes.compareTo(a.likes));
    }
    return DetailScaffold(
      title: widget.courseOnly
          ? '${widget.region ?? ''} 인기 코스'.trim()
          : (widget.region == null ? '커뮤니티' : '${widget.region} 여행 후기'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        if (posts.isEmpty)
          const _EmptyFeed()
        else
          for (final p in posts) PostCard(post: p, onChanged: () => setState(() {})),
      ],
    );
  }
}

/// 피드에 글이 하나도 없을 때. 안내가 없으면 백지라 로딩 실패로 오해한다.
/// 알림 센터의 빈 상태와 같은 톤으로 맞췄다.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surf,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 30,
                color: AppColors.ink4,
              ),
            ),
            const SizedBox(height: 16),
            Text('아직 올라온 글이 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              '첫 글을 남겨보세요. 다녀온 여행 후기나 궁금한 점 모두 좋아요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 커뮤니티 글 카드.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.onChanged, this.tappable = true});
  final Post post;
  final VoidCallback onChanged;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final (tagBg, tagFg) = tagColors(post.tag);
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      onTap: tappable
          ? () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(post: post)))
              .then((_) => onChanged())
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: post.avatarBg,
              child: Text(post.avatarEmoji, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(post.nick,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                ),
                if (post.verified) ...[const SizedBox(width: 6), const _VerifiedBadge()],
              ]),
              const SizedBox(height: 2),
              Text('${post.region} · ${post.timeAgo}${post.edited ? ' · 수정됨' : ''}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(999)),
            child: Text(tagLabel(post.tag),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tagFg)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(post.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
        if (post.photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (final ph in post.photos) ...[
              PostPhoto(ph, width: 74, height: 74),
              const SizedBox(width: 8),
            ],
          ]),
        ],
        if (post.courseName != null) ...[
          const SizedBox(height: 12),
          _AttachedCourse(name: post.courseName!, meta: post.courseMeta ?? ''),
        ],
        const SizedBox(height: 14),
        Row(children: [
          _Stat(
            icon: post.likedByMe ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            color: AppColors.coralDeep,
            count: post.likes,
            onTap: () {
              post.likedByMe = !post.likedByMe;
              post.likes += post.likedByMe ? 1 : -1;
              AppState.I.onPostReaction(post, like: true);
              onChanged();
            },
          ),
          const SizedBox(width: 15),
          _Stat(icon: Icons.chat_bubble_outline_rounded, color: AppColors.ink5, count: post.comments),
          const SizedBox(width: 15),
          _Stat(
            icon: post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            color: post.savedByMe ? AppColors.warning : AppColors.ink4,
            count: post.saves,
            onTap: () {
              post.savedByMe = !post.savedByMe;
              post.saves += post.savedByMe ? 1 : -1;
              AppState.I.onPostReaction(post, save: true);
              onChanged();
            },
          ),
        ]),
      ]),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(999)),
      child: const Row(children: [
        Icon(Icons.check_rounded, size: 11, color: Color(0xFF1B8E4B)),
        SizedBox(width: 3),
        Text('다녀온 여행',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1B8E4B))),
      ]),
    );
  }
}

class _AttachedCourse extends StatelessWidget {
  const _AttachedCourse({required this.name, required this.meta, this.onTap});
  final String name;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.soft),
          child: const Icon(Icons.route_outlined, size: 20, color: AppColors.p600),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const SizedBox(height: 2),
            Text(meta,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.ink4),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.count, this.onTap});
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text('$count',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]),
    );
  }
}

/// S4-2 게시글 상세.
class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.post});
  final Post post;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _Cmt {
  _Cmt({
    this.id,
    this.authorId,
    this.parentId,
    required this.emoji,
    required this.nick,
    required this.time,
    required this.body,
    this.isAuthor = false,
    this.likes = 0,
    this.likedByMe = false,
  });

  final int? id;
  final int? authorId;
  final int? parentId;
  final String emoji;
  final String nick;
  final String time;
  final String body;
  final bool isAuthor;
  int likes;
  bool likedByMe;
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _comment = TextEditingController();
  _Cmt? _replyTo; // 답글 대상 (인스타식 — 루트 댓글)
  late List<_Cmt> _comments = _seedComments();

  /// 첨부 코스 카드 탭 — 코스 상세로 보낸다. 지도·DAY별 일정·저장이 다 거기 있다.
  void _openAttachedCourse(BuildContext context, Post p) {
    if (p.courseStops.isEmpty) {
      showMock(context, '이 글엔 코스 상세 정보가 없어요.');
      return;
    }
    final days = p.courseStops.map((s) => s.day).toSet().length;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseViewScreen(
        course: Course(
          emoji: '🗺️',
          region: p.region,
          province: '',
          title: p.courseName ?? '${p.region} 코스',
          source: CourseSource.manual,
          durationLabel: days > 1 ? '${days - 1}박 $days일' : '당일',
          placeCount: p.courseStops.length,
          refundOk: false,
          savedAgo: p.timeAgo,
          stops: [
            for (final s in p.courseStops)
              CourseStop(
                day: s.day,
                time: s.time,
                emoji: '📍',
                name: s.name,
                tag: s.category.isEmpty ? '관광지' : s.category,
                latitude: s.latitude,
                longitude: s.longitude,
                address: s.address,
                placeId: s.placeId > 0 ? s.placeId : null,
              ),
          ],
        ),
        onSaveToLibrary: () => _saveAttachedCourse(context, p),
      ),
    ));
  }

  /// 첨부 코스를 실코스함(controller.savedCourses)으로 저장.
  /// 정차지 스냅샷이 없는 옛 글은 복원할 코스가 없어 저장을 막는다.
  Future<void> _saveAttachedCourse(BuildContext context, Post p) async {
    if (p.courseStops.isEmpty) {
      showMock(context, '이 글엔 코스 상세 정보가 없어 저장할 수 없어요.');
      return;
    }
    final controller = AppScope.of(context);
    // id가 글 단위로 고정이라 두 번 저장해도 같은 코스를 덮어쓴다(중복 없음).
    await controller.saveCourse(SavedCourse(
      id: 'community-post-${p.serverId ?? p.hashCode}',
      regionId: 0,
      regionName: p.region,
      title: p.courseName!,
      preferences: [if (p.courseMeta != null) p.courseMeta!, '커뮤니티 저장'],
      stops: p.courseStops,
      createdAt: DateTime.now(),
    ));
    if (!context.mounted) return;
    // 저장했으면 바로 내 코스함으로 — 코스 상세(남의 코스)는 더 볼 이유가 없다.
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CourseSavedScreen()));
    showToast(context, '코스를 내 코스함에 저장했어요.');
  }

  List<_Cmt> _seedComments() {
    if (AppState.I.serverMode) {
      _loadServerComments();
      return [];
    }
    return [
      _Cmt(id: -1, emoji: '🐧', nick: '강진가고파', time: '2시간 전', body: '오 동선 저장해갑니다! 가우도 주차는 어디 하셨어요?', likes: 3),
      _Cmt(id: -2, parentId: -1, emoji: '🦊', nick: '여행하는민트', time: '1시간 전', body: '@강진가고파 출렁다리 입구 공영주차장 했어요~ 주말 오전엔 자리 있었어요!', isAuthor: true, likes: 1),
      _Cmt(id: -3, emoji: '🐻', nick: '영월초보', time: '1시간 전', body: '환급 꿀팁 감사해요 🙏 저도 강진 신청했는데 참고할게요!', likes: 1),
    ];
  }

  Future<void> _loadServerComments() async {
    final s = AppState.I;
    final serverId = widget.post.serverId;
    if (!s.serverMode || serverId == null) return;
    try {
      final items = await s.communityRepository!
          .getCommunityComments(serverId, userId: s.communityUserId);
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final c in items)
            _Cmt(
              id: c.id,
              authorId: c.authorId,
              parentId: c.parentId,
              emoji: decodeAvatar(c.authorAvatarPreset).emoji,
              nick: c.authorNickname,
              time: AppState.relativeTime(c.createdAt),
              body: c.body,
              isAuthor: c.isPostAuthor,
              likes: c.likeCount,
              likedByMe: c.likedByMe,
            ),
        ];
      });
    } catch (_) {}
  }

  /// 답글 시작 — 인스타식: 어떤 댓글(답글 포함)에서든 가능, 입력창에 @닉 자동 프리필.
  void _startReply(_Cmt target) {
    setState(() {
      _replyTo = target;
      final mention = '@${target.nick} ';
      if (!_comment.text.startsWith(mention)) {
        _comment.text = mention;
        _comment.selection =
            TextSelection.collapsed(offset: _comment.text.length);
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    final s = AppState.I;
    final serverId = widget.post.serverId;
    final target = _replyTo;
    setState(() {
      _comments.add(_Cmt(
        // 낙관 표시: 루트 밑에 flat (서버도 같은 규칙으로 정규화)
        parentId: target == null ? null : (target.parentId ?? target.id),
        emoji: s.avatarEmoji,
        nick: s.nickname,
        time: '방금',
        body: text,
        isAuthor: widget.post.mine,
      ));
      widget.post.comments += 1;
      _comment.clear();
      _replyTo = null;
    });
    if (s.serverMode && serverId != null) {
      try {
        await s.communityRepository!.addCommunityComment(
            serverId, s.communityUserId!, text,
            parentId: target?.id, mentionUserId: target?.authorId);
        await _loadServerComments(); // 서버 정렬·id 반영
      } catch (_) {}
    }
  }


  Future<void> _openMoreMenu() async {
    final p = widget.post;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p.mine) ...[
            ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.ink7),
                title: const Text('글 수정'),
                onTap: () => Navigator.pop(c, 'edit')),
            ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.coralDeep),
                title: const Text('글 삭제'),
                onTap: () => Navigator.pop(c, 'delete')),
          ] else
            ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.coralDeep),
                title: const Text('신고하기'),
                onTap: () => Navigator.pop(c, 'report')),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await _reportPost();
    } else if (action == 'delete') {
      final ok = await showConfirmDialog(
        context,
        title: '글을 삭제할까요?',
        message: '댓글과 좋아요도 함께 사라지고 되돌릴 수 없어요.',
        confirmLabel: '삭제',
        danger: true,
      );
      if (ok && mounted) await _deleteMyPost();
    } else if (action == 'edit') {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CommunityWriteScreen(editPost: widget.post)));
      if (mounted) setState(() {});
    }
  }

  Future<void> _reportPost() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('신고 사유',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          ),
          for (final r in ['홍보·도배성 글이에요', '욕설·혐오 표현이 있어요', '개인정보가 노출됐어요', '허위 정보예요', '기타'])
            ListTile(dense: true, title: Text(r), onTap: () => Navigator.pop(c, r)),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (!mounted || reason == null) return;
    final s = AppState.I;
    if (s.serverMode && widget.post.serverId != null) {
      try {
        await s.communityRepository!.reportCommunity(
            userId: s.communityUserId!,
            targetType: 'POST',
            targetId: widget.post.serverId!,
            reason: reason);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수됐어요. 검토 후 조치할게요.')));
    }
  }

  Future<void> _deleteMyPost() async {
    final s = AppState.I;
    if (s.serverMode && widget.post.serverId != null) {
      try {
        await s.communityRepository!
            .deleteCommunityPost(widget.post.serverId!, s.communityUserId!);
      } catch (_) {}
    }
    s.posts.remove(widget.post);
    s.update();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('글을 삭제했어요.')));
    }
  }

  Future<void> _deleteComment(_Cmt c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _comments.remove(c);
      widget.post.comments = (widget.post.comments - 1).clamp(0, 1 << 30);
    });
    final s = AppState.I;
    if (s.serverMode && c.id != null && c.id! > 0) {
      try {
        await s.communityRepository!
            .deleteCommunityComment(c.id!, s.communityUserId!);
      } catch (_) {}
    }
  }

  /// 인스타식 댓글 행 — 답글은 들여쓰기. 내 댓글은 길게 눌러 삭제.
  Widget _commentRow(_Cmt c) {
    final isReply = c.parentId != null;
    final myComment = c.nick == AppState.I.nickname;
    return GestureDetector(
      onLongPress: myComment ? () => _deleteComment(c) : null,
      child: Padding(
      padding: EdgeInsets.only(top: 12, left: isReply ? 34 : 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 16, backgroundColor: AppColors.p100,
            child: Text(c.emoji, style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(c.nick,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              if (c.isAuthor) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.p100, borderRadius: BorderRadius.circular(999)),
                  child: const Text('작성자',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.p700)),
                ),
              ],
              const SizedBox(width: 6),
              Text(c.time,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ]),
            const SizedBox(height: 4),
            _mentionText(c.body),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _startReply(c),
              child: const Text('답글 달기',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
            ),
          ]),
        ),
      ]),
      ),
    );
  }

  /// 댓글 본문 — "@닉네임" 토큰을 파란 글씨로 하이라이트.
  Widget _mentionText(String body) {
    const base = TextStyle(
        fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5);
    const mention = TextStyle(
        fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.p600, height: 1.5);
    final spans = <TextSpan>[];
    final pattern = RegExp(r'@\S+');
    var cursor = 0;
    for (final m in pattern.allMatches(body)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, m.start), style: base));
      }
      spans.add(TextSpan(text: m.group(0), style: mention));
      cursor = m.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor), style: base));
    }
    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final (tagBg, tagFg) = tagColors(p.tag);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('게시글'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            onPressed: _openMoreMenu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 20), children: [
            // 본문 섹션 (흰 배경, 디자인 pd-section)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 21, backgroundColor: p.avatarBg,
                  child: Text(p.avatarEmoji, style: const TextStyle(fontSize: 21))),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.nick,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                    if (p.verified) ...[const SizedBox(width: 6), const _VerifiedBadge()],
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(999)),
                      child: Text(tagLabel(p.tag),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tagFg)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text('${p.region} · ${p.timeAgo}${p.edited ? ' · 수정됨' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Text(p.text,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.6)),
            if (p.photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              // 목록과 같은 1:1. 예전엔 높이만 120으로 고정해서 폭이 넓을수록
              // 가로로 늘어난 비율로 보였다.
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (i, ph) in p.photos.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => openPhotoViewer(context, p.photos, i),
                        child: PostPhoto(ph, aspectRatio: 1, radius: 16, fontSize: 44),
                      ),
                    ),
                  ),
              ]),
            ],
            // 글 안에 지도를 다시 그리지 않는다 — 코스 카드를 누르면 코스 상세로 가고,
            // 지도·DAY별 일정·저장은 거기서 한 번에 본다(목록 카드와 같은 동선).
            if (p.courseName != null) ...[
              const SizedBox(height: 16),
              _AttachedCourse(
                name: p.courseName!,
                meta: p.courseMeta ?? '',
                onTap: () => _openAttachedCourse(context, p),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              _Stat(
                icon: p.likedByMe ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                color: AppColors.coralDeep,
                count: p.likes,
                onTap: () => setState(() {
                  p.likedByMe = !p.likedByMe;
                  p.likes += p.likedByMe ? 1 : -1;
                  AppState.I.onPostReaction(p, like: true);
                }),
              ),
              const SizedBox(width: 16),
              _Stat(icon: Icons.chat_bubble_outline_rounded, color: AppColors.ink5, count: widget.post.comments),
              const SizedBox(width: 16),
              _Stat(
                icon: p.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: p.savedByMe ? AppColors.warning : AppColors.ink4,
                count: p.saves,
                onTap: () => setState(() {
                  p.savedByMe = !p.savedByMe;
                  p.saves += p.savedByMe ? 1 : -1;
                  AppState.I.onPostReaction(p, save: true);
                }),
              ),
            ]),
              ]),
            ),
            const SizedBox(height: 10),
            // 댓글 섹션 (흰 배경, 디자인 cmt-section)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('댓글 ${_comments.length}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9)),
            const SizedBox(height: 6),
            for (final c in _comments) _commentRow(c),
              ]),
            ),
          ]),
        ),
        // 답글 대상 배너
        if (_replyTo != null)
          Container(
            color: AppColors.surf,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Text('${_replyTo!.nick}님에게 답글 남기는 중',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
              ),
              GestureDetector(
                onTap: () => setState(() => _replyTo = null),
                child: const Icon(Icons.close_rounded, size: 17, color: AppColors.ink4),
              ),
            ]),
          ),
        // 댓글 입력
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x120F172A), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            child: Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppState.I.avatarBg,
                child: Text(AppState.I.avatarEmoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _comment,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: '댓글을 남겨보세요',
                    hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.ink4),
                    filled: true,
                    fillColor: AppColors.surf,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitComment,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward_rounded, size: 19, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 글쓰기.
/// 글쓰기에서 고른 사진 한 장 — 업로드 전 원본 바이트와 파일명.
class _PickedPhoto {
  const _PickedPhoto(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

/// 고른 사진 썸네일(64) + 우상단 ✕. 등록 중엔 ✕를 감춘다.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.bytes, this.onRemove});
  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(clipBehavior: Clip.none, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover, gaplessPlayback: true),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.ink9, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
      ]),
    );
  }
}

class CommunityWriteScreen extends StatefulWidget {
  const CommunityWriteScreen(
      {super.key, this.regionName, this.tripId, this.editPost});
  final String? regionName;

  /// 특정 여행에서 후기로 진입한 경우의 그 여행 id. 같은 지역에 여행이 여러 개일 때
  /// 인증 배지를 실제 후기 대상 여행으로 특정하기 위해 사용(null이면 지역 기준).
  final int? tripId;

  /// 수정 모드 — 기존 글을 넘기면 프리필·수정 저장.
  final Post? editPost;

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  late int _tag = switch (widget.editPost?.tag) {
    PostTag.course => 1,
    PostTag.ask => 2,
    PostTag.info => 3,
    _ => 0,
  };
  late int _visibility = (widget.editPost?.private ?? false) ? 1 : 0;
  late bool _verify = widget.editPost?.verified ?? true;
  late String _region =
      widget.editPost?.region ?? widget.regionName ?? AppState.I.regions.first.name;
  late final _text = TextEditingController(text: widget.editPost?.text ?? '');

  // 내 코스함에서 고른 첨부 코스 (실데이터). 수정 모드는 기존 스냅샷 유지.
  String? _courseName = null;
  String? _courseMeta = null;
  List<SavedCourseStop> _courseStops = const [];
  bool _courseInitialized = false;

  bool get _isEdit => widget.editPost != null;

  /// 새 글에 붙일 사진 — 기기에서 고른 원본 바이트. 등록 시 서버(Supabase)에 올리고 URL로 바꾼다.
  /// 수정 모드는 기존 사진(URL)을 그대로 두고 추가만 막는다(서버 PATCH가 photos를 안 받음).
  final List<_PickedPhoto> _photos = [];
  static const _maxPhotos = 5;

  /// 등록 진행 중 — 사진 업로드가 수 초 걸릴 수 있어 버튼을 잠그고 스피너를 보인다.
  bool _submitting = false;

  Future<void> _pickPhotos() async {
    if (_photos.length >= _maxPhotos) {
      showMock(context, '사진은 $_maxPhotos장까지 붙일 수 있어요.');
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        limit: _maxPhotos - _photos.length,
      );
      if (picked.isEmpty) return;
      final loaded = <_PickedPhoto>[];
      for (final x in picked.take(_maxPhotos - _photos.length)) {
        loaded.add(_PickedPhoto(await x.readAsBytes(), x.name));
      }
      if (!mounted) return;
      setState(() => _photos.addAll(loaded));
    } catch (e) {
      if (!mounted) return;
      showMock(context, '사진을 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  /// 고른 사진을 서버에 올려 공개 URL 목록으로. 서버 모드가 아니면(목업) 빈 목록.
  Future<List<String>> _uploadPhotos() async {
    final s = AppState.I;
    final repo = s.communityRepository;
    final userId = s.communityUserId;
    if (!s.serverMode || repo == null || userId == null || _photos.isEmpty) {
      return const [];
    }
    final urls = <String>[];
    for (final p in _photos) {
      urls.add(await repo.uploadCommunityPhoto(
          userId: userId, bytes: p.bytes, fileName: p.name));
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final s = AppState.I;
    final text = _text.text.trim();
    if (text.isEmpty) {
      showMock(context, '내용을 입력해주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_isEdit) {
        await _submitEdit(text);
        return;
      }
      List<String> photoUrls;
      try {
        photoUrls = await _uploadPhotos();
      } catch (e) {
        if (!mounted) return;
        showMock(context, '사진 업로드에 실패했어요. 잠시 후 다시 시도해 주세요.');
        return;
      }
      if (!mounted) return;
      s.addPost(Post(
        avatarEmoji: s.avatarEmoji,
        avatarBg: s.avatarBg,
        nick: s.nickname,
        region: _region,
        timeAgo: '방금',
        tag: PostTag.values[_tag],
        text: text,
        photos: photoUrls,
        verified: _verify,
        courseName: _courseName,
        courseMeta: _courseMeta,
        courseStops: _courseStops,
        likes: 0,
        comments: 0,
        saves: 0,
        mine: true,
        private: _visibility == 1,
        title: '$_region ${tagLabel(PostTag.values[_tag])}',
      ));
      Navigator.of(context).pop();
      showToast(context, _visibility == 0 ? '글을 등록했어요. 피드 맨 위에서 확인해보세요!' : '나만보기로 저장했어요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEdit(String text) async {
    final s = AppState.I;
    final post = widget.editPost!;
    final wireType = switch (PostTag.values[_tag]) {
      PostTag.course => 'COURSE',
      PostTag.ask => 'QUESTION',
      PostTag.info => 'INFO',
      _ => 'REVIEW',
    };
    // 낙관 반영 + "수정됨" 표시
    post
      ..tag = PostTag.values[_tag]
      ..region = _region
      ..text = text
      ..title = '$_region ${tagLabel(PostTag.values[_tag])}'
      ..courseName = _courseName
      ..courseMeta = _courseMeta
      ..courseStops = _courseStops
      ..private = _visibility == 1
      ..edited = true;
    s.update();
    if (s.serverMode && post.serverId != null) {
      try {
        await s.communityRepository!.updateCommunityPost(
          postId: post.serverId!,
          userId: s.communityUserId!,
          type: wireType,
          regionName: _region,
          title: post.title,
          body: text,
          courseName: _courseName,
          courseMeta: _courseMeta,
          courseStops: _courseStops,
          // 코스를 뗀 채 저장하면 서버에도 제거를 명시 (필드 생략과 구분).
          clearCourse: _courseName == null,
          visibility: _visibility == 1 ? 'PRIVATE' : 'PUBLIC',
        );
      } catch (_) {}
    } else {
      s.persistCommunity();
    }
    if (mounted) {
      Navigator.of(context).pop();
      showMock(context, '글을 수정했어요.');
    }
  }

  /// 코스 첨부 — 내 코스함(실데이터)에서 이 지역 코스를 골라 스냅샷으로 첨부.
  Widget _buildCourseSection(BuildContext context) {
    if (!_courseInitialized) {
      _courseInitialized = true;
      _courseName = widget.editPost?.courseName;
      _courseMeta = widget.editPost?.courseMeta;
      _courseStops = widget.editPost?.courseStops ?? const [];
    }
    final controller = AppScope.of(context);
    final candidates = controller.savedCourses
        .where((c) => c.regionName == _region)
        .toList();

    if (_courseName != null) {
      return AppCard(
        padding: const EdgeInsets.all(13),
        radius: 15,
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.p50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.route_outlined, size: 20, color: AppColors.p600),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_courseName!,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              const SizedBox(height: 2),
              Text(_courseMeta ?? '',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ]),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _courseName = null;
              _courseMeta = null;
              _courseStops = const [];
            }),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
          ),
        ]),
      );
    }
    if (candidates.isEmpty) {
      return const NoteRow('이 지역에 저장된 코스가 없어요. 내 여행 > 저장 코스에서 만들 수 있어요.');
    }
    return OutlineButton('내 코스함에서 코스 첨부', icon: Icons.add_rounded, onTap: () async {
      final picked = await pickOption(context,
          title: '첨부할 코스',
          options: candidates.map((c) => c.title).toList());
      if (picked == null) return;
      final course = candidates.firstWhere((c) => c.title == picked);
      setState(() {
        _courseName = course.title;
        _courseMeta = '${course.regionName} · ${course.stops.length}곳';
        _courseStops = course.stops;
      });
    });
  }

  /// 다녀온 여행 인증 — 이 지역의 실제 내 여행이 있어야 켤 수 있다 (최종 검증은 서버).
  Widget _buildVerifySection(BuildContext context) {
    final controller = AppScope.of(context);
    // 후기 진입 시 넘어온 tripId가 있으면 그 여행으로 특정한다. 지역만 맞춰 첫 여행을
    // 잡던 기존 로직은 같은 지역에 여행이 여러 개면 엉뚱한 여행을 인증 대상으로 잡았다.
    final regionTrips =
        controller.trips.where((t) => t.regionName == _region).toList();
    var trip = regionTrips.isEmpty ? null : regionTrips.first;
    if (widget.tripId != null) {
      for (final t in controller.trips) {
        if (t.id == widget.tripId) {
          trip = t;
          break;
        }
      }
    }
    if (trip == null) {
      if (_verify) _verify = false;
      return const NoteRow('이 지역에 다녀온 여행이 없어 인증 배지를 붙일 수 없어요.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MenuGroup(children: [
        ToggleRow(
          icon: Icons.shield_outlined,
          label: '${trip.regionName} ${durationLabelOf(trip)} 여행으로 인증',
          value: _verify,
          onChanged: (v) => setState(() => _verify = v),
        ),
      ]),
      if (_verify)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(children: [
            _VerifiedBadge(),
            SizedBox(width: 8),
            Expanded(
              child: Text('내 여행 기록으로 인증 배지가 붙어요.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: _isEdit ? '글 수정' : '글쓰기',
      closeIcon: true,
      cta: CtaBar(children: [
        PrimaryButton(
          _submitting
              ? (_isEdit ? '수정 중…' : (_photos.isEmpty ? '등록 중…' : '사진 올리는 중…'))
              : (_isEdit ? '수정하기' : '등록하기'),
          loading: _submitting,
          onTap: _submit,
        )
      ]),
      children: [
        const _WLabel('글 종류'),
        SegChips(
          labels: const ['후기', '코스', '질문', '정보'],
          selected: _tag,
          onChanged: (i) => setState(() => _tag = i),
        ),
        const _WLabel('내용'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () async {
                final r = await pickOption(context,
                    title: '지역 선택', options: AppState.I.regions.map((r) => r.name).toList());
                if (r != null && r != _region) {
                  setState(() {
                    _region = r;
                    // 지역이 바뀌면 이전 지역 코스 첨부는 무효 — 새 지역에서 다시 선택.
                    _courseName = null;
                    _courseMeta = null;
                    _courseStops = const [];
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.place_outlined, size: 15, color: AppColors.p600),
                  const SizedBox(width: 5),
                  Text(_region,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const Icon(Icons.expand_more_rounded, size: 17, color: AppColors.ink4),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink9, height: 1.5),
              decoration: const InputDecoration(
                hintText: '여행 이야기를 들려주세요',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.ink4),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            // 사진: 수정 모드는 기존 URL 썸네일만, 새 글은 고른 사진 + 추가 타일.
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (_isEdit)
                for (final url in widget.editPost!.photos)
                  PostPhoto(url, width: 64, height: 64, radius: 14, fontSize: 27),
              for (var i = 0; i < _photos.length; i++)
                _PhotoThumb(
                  bytes: _photos[i].bytes,
                  onRemove: _submitting ? null : () => setState(() => _photos.removeAt(i)),
                ),
              if (!_isEdit && _photos.length < _maxPhotos)
                GestureDetector(
                  onTap: _submitting ? null : _pickPhotos,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.ink4),
                      const SizedBox(height: 2),
                      Text(_photos.isEmpty ? '사진' : '${_photos.length}/$_maxPhotos',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink4)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
        const _WLabel('코스 첨부'),
        _buildCourseSection(context),
        const _WLabel('다녀온 여행 인증'),
        _buildVerifySection(context),
        const _WLabel('공개 범위'),
        SegChips(
          labels: const ['공개', '나만보기'],
          selected: _visibility,
          onChanged: (i) => setState(() => _visibility = i),
        ),
      ],
    );
  }
}

class _WLabel extends StatelessWidget {
  const _WLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
    );
  }
}

/// 작성한 글 (내 후기 관리).
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  int _filter = 0;
  static const _filters = ['전체', '후기', '코스', '질문', '정보'];

  @override
  Widget build(BuildContext context) {
    final mine = AppState.I.posts
        .where((p) => p.mine)
        .where((p) => _filter == 0 || tagLabel(p.tag) == _filters[_filter])
        .toList();
    final likes = mine.fold(0, (s, p) => s + p.likes);
    final saves = mine.fold(0, (s, p) => s + p.saves);

    return DetailScaffold(
      title: '작성한 글',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(children: [
            _stat('${mine.length}', '작성한 글'),
            Container(width: 1, height: 36, color: AppColors.line),
            _stat('$likes', '받은 좋아요'),
            Container(width: 1, height: 36, color: AppColors.line),
            _stat('$saves', '저장 수'),
          ]),
        ),
        CatChips(labels: _filters, selected: _filter, onChanged: (i) => setState(() => _filter = i)),
        if (mine.isEmpty) const NoteRow('아직 작성한 글이 없어요. 커뮤니티 탭에서 첫 글을 남겨보세요!'),
        for (final p in mine)
          Opacity(
            opacity: p.private ? .75 : 1,
            child: PostCard(post: p, onChanged: () => setState(() {}), tappable: !p.private),
          ),
      ],
    );
  }

  Widget _stat(String n, String label) => Expanded(
        child: Column(children: [
          Text(n,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ]),
      );
}

/// 저장한 글.
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  int _filter = 0;
  static const _filters = ['전체', '후기', '코스', '질문', '정보'];

  @override
  Widget build(BuildContext context) {
    final saved = AppState.I.posts
        .where((p) => p.savedByMe)
        .where((p) => _filter == 0 || tagLabel(p.tag) == _filters[_filter])
        .toList();

    return DetailScaffold(
      title: '저장한 글',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        CatChips(labels: _filters, selected: _filter, onChanged: (i) => setState(() => _filter = i)),
        if (saved.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text('저장한 글이 없어요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ),
          ),
        for (final p in saved) PostCard(post: p, onChanged: () => setState(() {})),
      ],
    );
  }
}
