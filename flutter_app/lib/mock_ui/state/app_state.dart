import 'package:flutter/material.dart';

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

  /// 커뮤니티 탭 진입 시 적용할 지역 필터 요청 (1회성).
  final ValueNotifier<String?> communityRegion = ValueNotifier(null);

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

  Region regionByName(String name) =>
      regions.firstWhere((r) => r.name == name, orElse: () => regions[1]);

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

  void addPost(Post p) {
    posts.insert(0, p);
    notifyListeners();
  }

  void readAllNotifications() {
    for (final n in notifications) {
      n.unread = false;
    }
    notifyListeners();
  }

  void update() => notifyListeners();
}
