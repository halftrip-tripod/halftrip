import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../../core/app_scope.dart';
import '../../utils/profile_presets.dart';
import '../state/app_state.dart';
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
    // 서버 모드: 탭 진입마다 최신 피드로 갱신 (다른 사용자 글 반영).
    AppState.I.refreshCommunityFromServer().then((_) {
      if (mounted) setState(() {});
    });
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
      _ => all.where((p) => tagLabel(p.tag) == _filters[_filter]).toList(),
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

    return Stack(children: [
      ListView(
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
          for (final p in _list) ...[
            PostCard(post: p, onChanged: () => setState(() {})),
            const SizedBox(height: 14),
          ],
        ],
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
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key, this.region});
  final String? region;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final posts = AppState.I.posts
        .where((p) => !p.private)
        .where((p) => widget.region == null || p.region == widget.region);
    return DetailScaffold(
      title: widget.region == null ? '커뮤니티' : '${widget.region} 여행 후기',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        for (final p in posts) PostCard(post: p, onChanged: () => setState(() {})),
      ],
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
              EmojiBox(ph, size: 74, fontSize: 30, color: AppColors.surf),
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
          const Spacer(),
          Text(post.region,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink4)),
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
  const _AttachedCourse({required this.name, required this.meta});
  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      await _deleteMyPost();
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
              Row(children: [
                for (final ph in p.photos)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(16)),
                        child: Text(ph, style: const TextStyle(fontSize: 44)),
                      ),
                    ),
                  ),
              ]),
            ],
            if (p.courseName != null) ...[
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _AttachedCourse(name: p.courseName!, meta: p.courseMeta ?? ''),
                  const SizedBox(height: 10),
                  const CourseMapCard(),
                  const SizedBox(height: 10),
                  OutlineButton('내 코스함에 저장',
                      icon: Icons.bookmark_add_outlined,
                      onTap: () {
                        final r = AppState.I.regionByName(p.region);
                        AppState.I.addCourse(Course(
                          emoji: r.emoji,
                          region: r.name,
                          province: r.province,
                          title: p.courseName!,
                          source: CourseSource.manual,
                          durationLabel: '1박 2일',
                          placeCount: 7,
                          refundOk: true,
                          savedAgo: '방금 저장',
                          stops: gangjinStops(),
                        ));
                        showMock(context, '코스를 내 코스함에 저장했어요. 내 여행 > 저장 코스에서 확인!');
                      }),
                ]),
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
class CommunityWriteScreen extends StatefulWidget {
  const CommunityWriteScreen({super.key, this.regionName, this.editPost});
  final String? regionName;

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
      widget.editPost?.region ?? widget.regionName ?? '강진';
  late final _text = TextEditingController(text: widget.editPost?.text ?? '');

  // 내 코스함에서 고른 첨부 코스 (실데이터). 수정 모드는 기존 스냅샷 유지.
  String? _courseName = null;
  String? _courseMeta = null;
  bool _courseInitialized = false;

  bool get _isEdit => widget.editPost != null;

  void _submit() {
    final s = AppState.I;
    final text = _text.text.trim();
    if (text.isEmpty) {
      showMock(context, '내용을 입력해주세요.');
      return;
    }
    if (_isEdit) {
      _submitEdit(text);
      return;
    }
    s.addPost(Post(
      avatarEmoji: s.avatarEmoji,
      avatarBg: s.avatarBg,
      nick: s.nickname,
      region: _region,
      timeAgo: '방금',
      tag: PostTag.values[_tag],
      text: text,
      verified: _verify,
      courseName: _courseName,
      courseMeta: _courseMeta,
      likes: 0,
      comments: 0,
      saves: 0,
      mine: true,
      private: _visibility == 1,
      title: '$_region ${tagLabel(PostTag.values[_tag])}',
    ));
    Navigator.of(context).pop();
    showMock(context, _visibility == 0 ? '글을 등록했어요. 피드 맨 위에서 확인해보세요!' : '나만보기로 저장했어요.');
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
        );
        if (post.private != (widget.editPost!.private)) {}
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
      });
    });
  }

  /// 다녀온 여행 인증 — 이 지역의 실제 내 여행이 있어야 켤 수 있다 (최종 검증은 서버).
  Widget _buildVerifySection(BuildContext context) {
    final controller = AppScope.of(context);
    final trips =
        controller.trips.where((t) => t.regionName == _region).toList();
    if (trips.isEmpty) {
      if (_verify) _verify = false;
      return const NoteRow('이 지역에 다녀온 여행이 없어 인증 배지를 붙일 수 없어요.');
    }
    final trip = trips.first;
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
        PrimaryButton(_isEdit ? '수정하기' : '등록하기', onTap: _submit)
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
                if (r != null) setState(() => _region = r);
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
            Row(children: [
              const EmojiBox('🌉', size: 64, fontSize: 27, color: AppColors.surf),
              const SizedBox(width: 8),
              const EmojiBox('🏯', size: 64, fontSize: 27, color: AppColors.surf),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showMock(context, '사진 첨부는 목업에서 생략했어요.'),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line, width: 1.5),
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.ink4),
                    SizedBox(height: 2),
                    Text('사진', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink4)),
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
        .where((p) => p.mine || true) // 목업: 전체 글을 내 글처럼 노출
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
