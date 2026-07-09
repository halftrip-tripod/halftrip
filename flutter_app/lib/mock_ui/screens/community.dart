import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
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
              Text('${post.region} · ${post.timeAgo}',
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

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _comment = TextEditingController();
  final List<(String, String, String, String, bool)> _comments = [
    ('🐧', '강진가고파', '2시간 전', '오 동선 저장해갑니다! 가우도 주차는 어디 하셨어요?', false),
    ('🦊', '여행하는민트', '1시간 전', '@강진가고파 출렁다리 입구 공영주차장 했어요~ 주말 오전엔 자리 있었어요!', true),
    ('🐻', '영월초보', '1시간 전', '환급 꿀팁 감사해요 🙏 저도 강진 신청했는데 참고할게요!', false),
  ];

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
                  Text('${p.region} · ${p.timeAgo}',
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
                }),
              ),
              const SizedBox(width: 16),
              _Stat(icon: Icons.chat_bubble_outline_rounded, color: AppColors.ink5, count: _comments.length),
              const SizedBox(width: 16),
              _Stat(
                icon: p.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: p.savedByMe ? AppColors.warning : AppColors.ink4,
                count: p.saves,
                onTap: () => setState(() {
                  p.savedByMe = !p.savedByMe;
                  p.saves += p.savedByMe ? 1 : -1;
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
            for (final c in _comments)
              Padding(
                padding: EdgeInsets.only(top: 12, left: c.$5 ? 34 : 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 16, backgroundColor: AppColors.p100,
                      child: Text(c.$1, style: const TextStyle(fontSize: 15))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(c.$2,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                        if (c.$5) ...[
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
                        Text(c.$3,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
                      ]),
                      const SizedBox(height: 4),
                      Text(c.$4,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
                    ]),
                  ),
                ]),
              ),
              ]),
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
                onTap: () {
                  if (_comment.text.trim().isEmpty) return;
                  setState(() {
                    _comments.add((AppState.I.avatarEmoji, AppState.I.nickname, '방금', _comment.text.trim(), false));
                    _comment.clear();
                  });
                },
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
  const CommunityWriteScreen({super.key, this.regionName});
  final String? regionName;

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  int _tag = 0;
  int _visibility = 0;
  bool _verify = true;
  bool _attachCourse = true;
  late String _region = widget.regionName ?? '강진';
  final _text = TextEditingController();

  void _submit() {
    final s = AppState.I;
    final text = _text.text.trim().isEmpty
        ? '가우도 출렁다리 노을 진짜 최고였어요. 다산초당이랑 묶어서 도는 동선 강추! (목업 기본 문구)'
        : _text.text.trim();
    s.addPost(Post(
      avatarEmoji: s.avatarEmoji,
      avatarBg: s.avatarBg,
      nick: s.nickname,
      region: _region,
      timeAgo: '방금',
      tag: PostTag.values[_tag],
      text: text,
      verified: _verify,
      courseName: _attachCourse ? '$_region 환급 보장 코스' : null,
      courseMeta: _attachCourse ? '1박 2일 · 7곳' : null,
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

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '글쓰기',
      closeIcon: true,
      cta: CtaBar(children: [PrimaryButton('등록하기', onTap: _submit)]),
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
        if (_attachCourse)
          AppCard(
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
                  Text('$_region 환급 보장 코스',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 2),
                  const Text('1박 2일 · 7곳',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() => _attachCourse = false),
                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
              ),
            ]),
          )
        else
          OutlineButton('내 코스함에서 코스 첨부',
              icon: Icons.add_rounded, onTap: () => setState(() => _attachCourse = true)),
        const _WLabel('다녀온 여행 인증'),
        MenuGroup(children: [
          ToggleRow(
            icon: Icons.shield_outlined,
            label: '$_region 1박2일 여행으로 인증',
            value: _verify,
            onChanged: (v) => setState(() => _verify = v),
          ),
        ]),
        if (_verify)
          const Row(children: [
            _VerifiedBadge(),
            SizedBox(width: 8),
            Expanded(
              child: Text('정산 완료한 여행이라 인증 배지가 붙어요.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ),
          ]),
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
