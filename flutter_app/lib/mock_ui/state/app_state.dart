import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_models.dart' as api;
import '../../repositories/travel_repository.dart';
import '../../utils/profile_presets.dart';
import '../data/mock_data.dart';
import '../data/models.dart';

/// 목업 전역 상태 — 백엔드 없이 화면 간 인터랙션이 이어져 보이게 하는 최소 상태.
class AppState extends ChangeNotifier {
  AppState._() {
    // 여행 중인 평창 여행만 확정 코스가 연결된 상태로 시작.
    // 강진(여행 전)은 코스 없음 → 여행 상세에서 코스 만들기 플로우를 태운다.
    trips[1].course = courseFor('평창');
  }
  static final AppState I = AppState._();

  /// 메인 셸 탭 전환 요청 (0 홈 / 1 내여행 / 2 온라인몰 / 3 커뮤니티).
  final ValueNotifier<int?> tabRequest = ValueNotifier(null);

  /// 탭이 화면에 나타날 때마다 그 탭 번호를 실어 보내는 갱신 신호.
  ///
  /// 셸이 IndexedStack이라 탭을 오가도 State가 살아있어 initState가 다시 돌지 않는다.
  /// 그래서 다른 탭에서 한 작업(정산 신청·거주지 변경·글쓰기)이 반영되지 않는데,
  /// 각 탭이 이 신호를 구독해 자기 차례에 재조회하면 해결된다.
  /// (같은 탭을 다시 눌러도 갱신되도록 값이 아니라 카운터를 증가시킨다)
  final ValueNotifier<int> tabShownTick = ValueNotifier(0);
  int _shownTab = 0;

  /// 현재 보이는 탭 — tabShownTick 수신 측이 "내 탭인지" 판별할 때 쓴다.
  int get shownTab => _shownTab;

  /// 셸이 탭을 띄울 때 호출. 해당 탭 구독자에게 갱신 신호가 나간다.
  void notifyTabShown(int tab) {
    _shownTab = tab;
    tabShownTick.value++;
  }

  /// 커뮤니티 탭 진입 시 적용할 지역 필터 요청 (1회성).
  final ValueNotifier<String?> communityRegion = ValueNotifier(null);

  /// 커뮤니티 탭 진입 시 적용할 종류 필터 요청 (1회성, '코스' 등 칩 라벨).
  final ValueNotifier<String?> communityFilter = ValueNotifier(null);

  // 세션
  bool loggedIn = false;
  String loginProvider = '카카오';
  String residence = '서울특별시 강남구';
  String nickname = '여행하는민트42';
  String avatarEmoji = '🐳';
  Color avatarBg = const Color(0xFFE0F2FE);

  // 알림 설정
  bool alertRegionOpen = true;
  bool alertSettlementDday = true;

  // 데이터
  final List<Region> regions = buildRegions();
  final List<Course> courses = buildCourses();
  final List<Trip> trips = buildTrips();
  final List<Post> posts = buildPosts();
  final List<NotifItem> notifications = buildNotifications();
  final List<Receipt> receipts = buildReceipts();

  // 여행 진행 상태 (강진 여행 기준 목업)
  final Set<int> checklistDone = {0, 1};
  int authPhotoDone = 1; // 인증 완료 관광지 수 (조건 2곳)
  bool lodgingSaved = false;

  int get spentAmount =>
      120000 + receipts.skip(3).fold(0, (s, r) => s + r.amount);

  /// 서버 지역 목록으로 지역 마스터를 맞춘다 — 커뮤니티 지역 필터·글쓰기 지역 선택 등
  /// AppState.regions를 읽는 화면이 목업 8곳이 아니라 반값여행 진행 지역 전체를 보게 한다.
  /// 이미 있는 지역 객체는 그대로 두고(즐겨찾기 상태 유지) 순서만 서버(displayOrder)대로.
  void syncRegions(List<api.RegionSummary> server) {
    if (server.isEmpty) return;
    final sorted = [...server]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final byName = {for (final r in regions) r.name: r};
    final next = <Region>[];
    for (final s in sorted) {
      final existing = byName[s.name];
      if (existing != null) {
        next.add(existing);
        continue;
      }
      final status = switch (s.statusCode.toUpperCase()) {
        'APPLYING' => RegionStatus.open,
        'PREPARING' => RegionStatus.soon,
        _ => RegionStatus.closed,
      };
      final deadline = s.applyDeadline;
      final dday = deadline == null ? 0 : deadline.difference(DateTime.now()).inDays;
      final open = s.openDate;
      next.add(Region(
        name: s.name,
        province: s.province,
        emoji: '🗺️',
        status: status,
        condition: s.refundConditionAmount > 0
            ? '최소 소비 ${(s.refundConditionAmount / 10000).round()}만원 · 관광지 2곳 인증'
            : '관광지 2곳 인증',
        dday: dday < 0 ? 0 : dday,
        ddayWarn: dday >= 0 && dday <= 3,
        openLabel: status == RegionStatus.soon && open != null
            ? '${open.month}월 ${open.day}일 오픈 예정'
            : null,
      ));
    }
    // 서버에 없는 목업 지역은 뒤에 남긴다(테스트 데이터 화면이 깨지지 않게).
    final serverNames = {for (final s in sorted) s.name};
    next.addAll(regions.where((r) => !serverNames.contains(r.name)));
    regions
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// 이름으로 목업 지역 찾기 — 목업 목록(7곳)에 없는 지역이면 이름 그대로 만들어
  /// 돌려준다. (예전엔 regions[1]=강진 폴백이라 횡성 여행의 AI 코스가 강진으로 생성됐음)
  Region regionByName(String name) => regions.firstWhere(
        (r) => r.name == name,
        orElse: () => Region(
          name: name,
          province: '',
          emoji: '🗺️',
          status: RegionStatus.open,
          condition: '',
          dday: 0,
        ),
      );

  /// 이 지역 여행에 연결할 코스 (없으면 null → 코스 만들기 유도).
  Course? courseFor(String region) {
    for (final c in courses) {
      if (c.region == region) return c;
    }
    return null;
  }

  int get unreadNotifCount => notifications.where((n) => n.unread).length;

  void login(String provider) {
    loginProvider = provider;
    loggedIn = true;
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }

  void toggleFavorite(Region r) {
    r.favorite.value = !r.favorite.value;
    notifyListeners();
  }

  void toggleChecklist(int i) {
    checklistDone.contains(i) ? checklistDone.remove(i) : checklistDone.add(i);
    notifyListeners();
  }

  void addReceipt(Receipt r) {
    receipts.insert(0, r);
    notifyListeners();
  }

  void addCourse(Course c) {
    courses.insert(0, c);
    notifyListeners();
  }

  void addTrip(Trip t) {
    trips.insert(0, t);
    notifyListeners();
  }

  // ── 커뮤니티 서버 브리지 (실서버 모드) ─────────────────────
  // 화면은 계속 AppState.posts만 본다. 브리지가 붙으면 로컬퍼스트 대신
  // 서버가 데이터 소스가 되고, 액션(작성·토글·공개전환·댓글)은 서버로 나간다.

  TravelRepository? _repository;
  int? _serverUserId;

  bool get serverMode => _repository != null && _serverUserId != null;
  TravelRepository? get communityRepository => _repository;
  int? get communityUserId => _serverUserId;

  /// 로그인 직후(실서버 모드) 컨트롤러가 호출 — 서버 피드·내 글로 posts를 채운다.
  Future<void> attachCommunityServer(TravelRepository repository, int userId) async {
    _repository = repository;
    _serverUserId = userId;
    await refreshCommunityFromServer();
  }

  void detachCommunityServer() {
    _repository = null;
    _serverUserId = null;
  }

  Future<void> refreshCommunityFromServer() async {
    final repository = _repository;
    final userId = _serverUserId;
    if (repository == null || userId == null) return;
    try {
      final feed = await repository.getCommunityFeed(userId: userId);
      final mine = await repository.getMyCommunityPosts(userId);
      final merged = <int, Post>{};
      for (final data in [...feed, ...mine.posts]) {
        merged[data.id] = _toPost(data);
      }
      final list = merged.values.toList()
        ..sort((a, b) => (b.serverId ?? 0).compareTo(a.serverId ?? 0));
      posts
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // 서버 실패 시 기존 목록 유지.
    }
  }

  Post _toPost(api.CommunityPostData data) {
    final avatar = decodeAvatar(data.authorAvatarPreset);
    return Post(
      avatarEmoji: avatar.emoji,
      avatarBg: avatar.color,
      nick: data.authorNickname,
      region: data.regionName ?? '전국',
      timeAgo: relativeTime(data.createdAt),
      tag: switch (data.type) {
        'COURSE' => PostTag.course,
        'QUESTION' => PostTag.ask,
        'INFO' => PostTag.info,
        _ => PostTag.review,
      },
      text: data.body,
      verified: data.verified,
      photos: data.photos,
      courseName: data.courseName,
      courseMeta: data.courseMeta,
      courseStops: data.courseStops,
      likes: data.likeCount,
      comments: data.commentCount,
      saves: data.saveCount,
      likedByMe: data.likedByMe,
      savedByMe: data.savedByMe,
      mine: data.mine,
      private: data.visibility == 'PRIVATE',
      title: data.title,
      serverId: data.id,
      edited: data.edited,
    );
  }

  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 30) return '${diff.inDays}일 전';
    return '${time.month}.${time.day}';
  }

  /// 좋아요·저장 토글 훅 — 화면이 Post 필드를 낙관 변경한 뒤 호출한다.
  void onPostReaction(Post p, {bool like = false, bool save = false}) {
    final repository = _repository;
    final userId = _serverUserId;
    final serverId = p.serverId;
    if (repository != null && userId != null && serverId != null) {
      // 화면은 먼저 +1 해둔 상태(낙관적 반영) — 서버 저장이 실패하면 조용히
      // 사라지는 대신 즉시 되돌려서 화면과 서버가 어긋난 채 남지 않게 한다.
      if (like) {
        repository.toggleCommunityLike(serverId, userId).then((_) {}).catchError((_) {
          p.likedByMe = !p.likedByMe;
          p.likes += p.likedByMe ? 1 : -1;
          notifyListeners();
        });
      }
      if (save) {
        repository.toggleCommunityBookmark(serverId, userId).then((_) {}).catchError((_) {
          p.savedByMe = !p.savedByMe;
          p.saves += p.savedByMe ? 1 : -1;
          notifyListeners();
        });
      }
    } else {
      persistCommunity();
    }
  }

  /// 나만보기 글을 커뮤니티에 공개 전환.
  void publishPost(Post p) {
    p.private = false;
    notifyListeners();
    final repository = _repository;
    final userId = _serverUserId;
    if (repository != null && userId != null && p.serverId != null) {
      repository
          .updateCommunityVisibility(p.serverId!, userId, 'PUBLIC')
          .catchError((_) {});
    } else {
      persistCommunity();
    }
  }

  void addPost(Post p) {
    posts.insert(0, p);
    notifyListeners();
    final repository = _repository;
    final userId = _serverUserId;
    if (repository != null && userId != null) {
      // 서버 저장 후 serverId 회수 (실패해도 화면 낙관 유지).
      // 인증 요청(verified 토글)이면 같은 지역의 내 여행을 찾아 근거로 전달 — 최종 배지는 서버 검증.
      _resolveTripIdFor(p, repository, userId).then((tripId) => repository
          .createCommunityPost(
            userId: userId,
            type: switch (p.tag) {
              PostTag.course => 'COURSE',
              PostTag.ask => 'QUESTION',
              PostTag.info => 'INFO',
              _ => 'REVIEW',
            },
            regionName: p.region,
            title: p.title,
            body: p.text,
            photos: p.photos,
            courseName: p.courseName,
            courseMeta: p.courseMeta,
            courseStops: p.courseStops,
            visibility: p.private ? 'PRIVATE' : 'PUBLIC',
            tripId: tripId,
          )
          .then((created) {
        p.serverId = created.id;
        p.verified = created.verified;
        notifyListeners();
      })).catchError((_) {});
    } else {
      persistCommunity();
    }
  }

  Future<int?> _resolveTripIdFor(
      Post p, TravelRepository repository, int userId) async {
    if (!p.verified) return null;
    try {
      final trips = await repository.getTrips(userId);
      for (final trip in trips) {
        if (trip.regionName == p.region) return trip.id;
      }
    } catch (_) {}
    return null;
  }

  // ── 커뮤니티 로컬 영속화 — 서버(핸드오프 J) 전까지 내 글·좋아요·저장을 기기에 유지.
  static const _myPostsKey = 'mock_community_my_posts';
  static const _reactionsKey = 'mock_community_reactions';
  bool _communityRestored = false;

  Future<void> restoreCommunity() async {
    if (_communityRestored || serverMode) return;
    _communityRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final raw in (prefs.getStringList(_myPostsKey) ?? const []).reversed) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final text = j['text'] as String? ?? '';
        if (text.isEmpty || posts.any((p) => p.mine && p.text == text)) continue;
        posts.insert(
          0,
          Post(
            avatarEmoji: j['avatarEmoji'] as String? ?? '🐳',
            avatarBg: Color(j['avatarBg'] as int? ?? 0xFFE0F2FE),
            nick: j['nick'] as String? ?? nickname,
            region: j['region'] as String? ?? '',
            timeAgo: j['timeAgo'] as String? ?? '저장됨',
            tag: PostTag.values[(j['tag'] as int? ?? 0).clamp(0, PostTag.values.length - 1)],
            text: text,
            photos: ((j['photos'] as List<dynamic>?) ?? const []).cast<String>(),
            title: j['title'] as String?,
            likes: j['likes'] as int? ?? 0,
            comments: j['comments'] as int? ?? 0,
            saves: j['saves'] as int? ?? 0,
            mine: true,
            private: j['private'] as bool? ?? false,
          ),
        );
      }
      final reactions =
          jsonDecode(prefs.getString(_reactionsKey) ?? '{}') as Map<String, dynamic>;
      for (final p in posts) {
        final r = reactions[p.text] as Map<String, dynamic>?;
        if (r == null) continue;
        if (r['liked'] == true && !p.likedByMe) {
          p.likedByMe = true;
          p.likes += 1;
        }
        if (r['saved'] == true && !p.savedByMe) {
          p.savedByMe = true;
          p.saves += 1;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> persistCommunity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_myPostsKey, [
        for (final p in posts.where((p) => p.mine))
          jsonEncode({
            'avatarEmoji': p.avatarEmoji,
            'avatarBg': p.avatarBg.toARGB32(),
            'nick': p.nick,
            'region': p.region,
            'timeAgo': p.timeAgo,
            'tag': p.tag.index,
            'text': p.text,
            'photos': p.photos,
            'title': p.title,
            'likes': p.likes,
            'comments': p.comments,
            'saves': p.saves,
            'private': p.private,
          }),
      ]);
      await prefs.setString(
        _reactionsKey,
        jsonEncode({
          for (final p in posts.where((p) => p.likedByMe || p.savedByMe))
            p.text: {'liked': p.likedByMe, 'saved': p.savedByMe},
        }),
      );
    } catch (_) {}
  }

  void readAllNotifications() {
    for (final n in notifications) {
      n.unread = false;
    }
    notifyListeners();
  }

  void update() => notifyListeners();
}
