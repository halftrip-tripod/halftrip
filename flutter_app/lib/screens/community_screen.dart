import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui/app_card.dart';

/// 커뮤니티 피드 (S4-1) — 디자인: halftrip-design/community.html
/// 백엔드 미구현 상태의 UI 셸 — 글 데이터는 로컬 목업, 좋아요/저장 토글은 화면 내에서만 동작.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _filter = 0;
  static const _filters = ['인기', '최신', '후기', '코스', '질문', '정보'];

  final List<_Post> _posts = _buildPosts();

  List<_Post> get _visible {
    final list = [..._posts];
    switch (_filter) {
      case 0:
        list.sort((a, b) => b.likes.compareTo(a.likes));
        return list;
      case 1:
        return list;
      default:
        return list.where((p) => p.tag == _filters[_filter]).toList();
    }
  }

  void _todo(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return AppShell(
      title: '커뮤니티',
      modeName: controller.modeName,
      currentTabIndex: widget.currentTabIndex,
      onTabSelected: widget.onTabSelected,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _todo('글쓰기는 커뮤니티 백엔드 연동 후 열려요.'),
        backgroundColor: AppColors.p500,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          '글쓰기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(
            children: [
              const Text(
                '커뮤니티',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink9,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickFilter,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _filters[_filter],
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink7,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          size: 17, color: AppColors.ink5),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final post in _visible) ...[
            _PostCard(post: post, onChanged: () => setState(() {})),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _filters.length; i++)
              ListTile(
                title: Text(
                  _filters[i],
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink9,
                  ),
                ),
                trailing: i == _filter
                    ? const Icon(Icons.check_rounded,
                        size: 20, color: AppColors.p600)
                    : null,
                onTap: () => Navigator.of(c).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }
}

/// 커뮤니티 글 카드 (디자인 .cpost) — 닉네임·인증배지·글종류·본문·좋아요/댓글/저장.
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onChanged});

  final _Post post;
  final VoidCallback onChanged;

  (Color, Color) get _tagColors => switch (post.tag) {
        '후기' => (AppColors.p100, AppColors.p700),
        '코스' => (AppColors.mintTint, AppColors.mintDeep),
        '질문' => (const Color(0xFFFFF3E2), const Color(0xFFB8731B)),
        _ => (AppColors.track, AppColors.ink5),
      };

  @override
  Widget build(BuildContext context) {
    final (tagBg, tagFg) = _tagColors;

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: post.avatarBg,
                child:
                    Text(post.avatarEmoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.nick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink9,
                            ),
                          ),
                        ),
                        if (post.verified) ...[
                          const SizedBox(width: 6),
                          const _VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.region} · ${post.timeAgo}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  post.tag,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tagFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.text,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ink7,
              height: 1.5,
            ),
          ),
          if (post.courseName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.soft,
                    ),
                    child: const Icon(Icons.route_outlined,
                        size: 20, color: AppColors.p600),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.courseName!,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.courseMeta ?? '',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.ink4),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                icon: post.likedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: AppColors.coralDeep,
                count: post.likes,
                onTap: () {
                  post.likedByMe = !post.likedByMe;
                  post.likes += post.likedByMe ? 1 : -1;
                  onChanged();
                },
              ),
              const SizedBox(width: 15),
              _Stat(
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.ink5,
                count: post.comments,
              ),
              const SizedBox(width: 15),
              _Stat(
                icon: post.savedByMe
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: post.savedByMe ? AppColors.warning : AppColors.ink4,
                count: post.saves,
                onTap: () {
                  post.savedByMe = !post.savedByMe;
                  post.saves += post.savedByMe ? 1 : -1;
                  onChanged();
                },
              ),
              const Spacer(),
              Text(
                post.region,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F0),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_rounded, size: 11, color: Color(0xFF1B8E4B)),
          SizedBox(width: 3),
          Text(
            '다녀온 여행',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B8E4B),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Post {
  _Post({
    required this.avatarEmoji,
    required this.avatarBg,
    required this.nick,
    required this.region,
    required this.timeAgo,
    required this.tag,
    required this.text,
    this.verified = false,
    this.courseName,
    this.courseMeta,
    required this.likes,
    required this.comments,
    required this.saves,
    this.savedByMe = false,
  });

  final String avatarEmoji;
  final Color avatarBg;
  final String nick;
  final String region;
  final String timeAgo;
  final String tag;
  final String text;
  final bool verified;
  final String? courseName;
  final String? courseMeta;
  int likes;
  final int comments;
  int saves;
  bool likedByMe = false;
  bool savedByMe;
}

List<_Post> _buildPosts() => [
      _Post(
        avatarEmoji: '🦊',
        avatarBg: const Color(0xFFFFE9D6),
        nick: '여행하는민트',
        verified: true,
        region: '강진',
        timeAgo: '3일 전',
        tag: '후기',
        text: '가우도 출렁다리 노을 진짜 최고였어요. 다산초당이랑 묶어서 도는 동선 강추! 환급까지 받으니 거의 공짜 여행 ㅎㅎ',
        courseName: '강진 환급 보장 코스',
        courseMeta: '1박 2일 · 7곳 · 환급 조건 충족',
        likes: 42,
        comments: 3,
        saves: 18,
        savedByMe: true,
      ),
      _Post(
        avatarEmoji: '🐻',
        avatarBg: const Color(0xFFE0F2FE),
        nick: '영월초보',
        region: '영월',
        timeAgo: '5시간 전',
        tag: '코스',
        text: '첫 반값여행 영월 1박2일 코스 짜봤는데 동선 어때요? 빠진 데 있을까요? 🙏',
        courseName: '영월 동강 감성 코스',
        courseMeta: '1박 2일 · 5곳 · 환급 조건 충족',
        likes: 12,
        comments: 15,
        saves: 26,
        savedByMe: true,
      ),
      _Post(
        avatarEmoji: '🐧',
        avatarBg: const Color(0xFFE0F2FE),
        nick: '강진가고파',
        region: '강진',
        timeAgo: '어제',
        tag: '질문',
        text: '6월 말 강진 가는데 가우도 주차 어디가 편한가요? 주말이라 자리 걱정되네요 🚗',
        likes: 3,
        comments: 9,
        saves: 4,
      ),
      _Post(
        avatarEmoji: '🐰',
        avatarBg: const Color(0xFFE4F6F2),
        nick: '먹보여행',
        verified: true,
        region: '평창',
        timeAgo: '2일 전',
        tag: '정보',
        text: '평창 양떼목장 근처 한우 맛집 3곳 가성비 순으로 정리했어요 🐮 환급 결제 되는 곳만 골랐음!',
        likes: 30,
        comments: 5,
        saves: 15,
        savedByMe: true,
      ),
    ];
