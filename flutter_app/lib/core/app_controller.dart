import 'dart:convert';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import '../repositories/mock_travel_repository.dart';
import '../repositories/api_travel_repository.dart';
import '../repositories/travel_repository.dart';
import '../mock_ui/state/app_state.dart' as mock;
import '../screens/youtube_course_analysis_screen.dart';

class AppController extends ChangeNotifier {
  AppController({required TravelRepository repository})
      : _repository = repository;

  final TravelRepository _repository;
  bool isBusy = false;
  String? errorMessage;
  AppUser? currentUser;
  // 소셜 신규 가입 직후 거주지 입력 온보딩이 필요한지 여부.
  bool needsResidenceSetup = false;
  List<TripSummary> trips = const [];
  List<SavedCourse> savedCourses = const [];
  Map<int, String> selectedCourseIdsByTrip = const <int, String>{};
  List<PendingYoutubeCourseJob> pendingYoutubeCourseJobs = const [];
  Set<int> appliedTripIds = const <int>{};

  static const _savedCoursesKey = 'saved_courses_v1';
  static const _selectedCoursesKey = 'selected_course_ids_by_trip_v1';
  static const _pendingYoutubeJobsKey = 'pending_youtube_jobs_v1';
  static const _appliedTripsKey = 'applied_trip_ids_v1';

  // 로그인 세션 영속화 — 토큰은 일반 SharedPreferences가 아니라 secure storage에.
  // (Android Keystore 암호화 / iOS Keychain. 웹은 브라우저 저장소 기반)
  static const _sessionTokenKey = 'session_auth_token_v1';
  static const _sessionUserIdKey = 'session_user_id_v1';
  static const _sessionProviderKey = 'session_provider_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _pushInitialized = false;

  /// 세션 세대 — 로그아웃마다 올라간다. 응답을 기다리는 사이 세션이 끝난 갱신은
  /// 이 값이 달라진 걸 보고 결과를 버린다.
  int _sessionEpoch = 0;

  TravelRepository get repository => _repository;
  String get modeName => _repository.modeName;
  bool get isLoggedIn => currentUser != null;

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  Future<void> initializePushNotifications() async {
    if (_pushInitialized) return;
    _pushInitialized = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await FirebaseMessaging.instance.requestPermission();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        _registerFcmTokenIfPossible(token);
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      scheduleMicrotask(() => _handleNotificationTap(initialMessage));
    }

    await _syncFcmToken();
  }

  /// 로그인 성공 직후 세션(토큰·userId)을 secure storage에 남긴다.
  /// 저장 실패는 삼킨다 — 이번 세션 로그인 자체는 유효하므로.
  Future<void> _persistSession({String provider = 'LOCAL'}) async {
    final repo = _repository;
    final user = currentUser;
    if (repo is! ApiTravelRepository || user == null) return;
    final token = repo.authToken;
    if (token == null || token.isEmpty) return;
    try {
      await _secureStorage.write(key: _sessionTokenKey, value: token);
      await _secureStorage.write(key: _sessionUserIdKey, value: '${user.id}');
      await _secureStorage.write(key: _sessionProviderKey, value: provider);
      debugPrint('[세션] 저장 완료 userId=${user.id}');
    } catch (error) {
      debugPrint('[세션] 저장 실패: $error');
    }
  }

  /// 저장된 세션 파기 — 로그아웃·탈퇴·토큰 만료 시.
  Future<void> clearPersistedSession() async {
    try {
      await _secureStorage.delete(key: _sessionTokenKey);
      await _secureStorage.delete(key: _sessionUserIdKey);
      await _secureStorage.delete(key: _sessionProviderKey);
    } catch (_) {}
  }

  /// 앱 부팅 시 저장된 세션으로 자동 로그인. 성공하면 true.
  ///
  /// 토큰 유효성은 getUser 호출이 검증한다 — 401/403(만료·위조)이면 세션을
  /// 지우고, 네트워크 오류면 남겨둬서 다음 부팅에 다시 시도한다.
  Future<bool> restoreSession() async {
    final repo = _repository;
    if (repo is! ApiTravelRepository) return false;
    String? token;
    String? userIdRaw;
    try {
      token = await _secureStorage.read(key: _sessionTokenKey);
      userIdRaw = await _secureStorage.read(key: _sessionUserIdKey);
    } catch (error) {
      debugPrint('[세션] 저장소 읽기 실패: $error');
      return false;
    }
    final userId = int.tryParse(userIdRaw ?? '');
    if (token == null || token.isEmpty || userId == null) {
      debugPrint('[세션] 저장된 세션 없음');
      return false;
    }
    repo.adoptToken(token);
    try {
      currentUser = await repo.getUser(userId);
      trips = await repo.getTrips(userId);
      await _loadLocalDashboardData();
      await _syncFcmToken();
      await _attachCommunityIfServer();
      // 소셜 가입 도중(거주지 입력 전) 종료된 계정은 온보딩부터 이어간다.
      needsResidenceSetup = currentUser!.residence.trim().isEmpty;
      notifyListeners();
      debugPrint('[세션] 복원 성공 userId=$userId');
      return true;
    } catch (error) {
      repo.clearSession();
      currentUser = null;
      debugPrint('[세션] 복원 실패: $error');
      final message = error.toString();
      if (message.contains('401') || message.contains('403')) {
        await clearPersistedSession();
      }
      return false;
    }
  }

  /// 실 소셜 로그인 — SDK 액세스 토큰을 서버로 검증. 거주지 필요 여부는 서버 응답을 따른다.
  Future<void> loginWithSocial(LoginProvider provider, String accessToken) async {
    await _runBusy(() async {
      final result = await _repository.socialLogin(
        provider: provider,
        accessToken: accessToken,
      );
      currentUser = result.user;
      // 저장은 로그인 확정 즉시 — 뒤 단계(FCM·커뮤 연결)가 실패해도 세션은 남게.
      await _persistSession(provider: provider.name.toUpperCase());
      trips = await _repository.getTrips(result.user.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
      await _attachCommunityIfServer();
      needsResidenceSetup = result.needsResidence;
    });
  }

  Future<void> login(LoginProvider provider) async {
    await _runBusy(() async {
      final authUser = await _repository.mockLogin(provider);
      currentUser = await _repository.getUser(authUser.id);
      trips = await _repository.getTrips(authUser.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
      await _persistSession(provider: provider.name.toUpperCase());
      await _attachCommunityIfServer();
      // 소셜 가입은 거주지 입력 온보딩을 거치도록 한다.
      needsResidenceSetup = true;
    });
  }

  /// 실서버 모드면 커뮤니티 화면(AppState)의 데이터 소스를 서버로 전환한다.
  Future<void> _attachCommunityIfServer() async {
    final user = currentUser;
    if (user == null || _repository is! ApiTravelRepository) {
      return;
    }
    await mock.AppState.I.attachCommunityServer(_repository, user.id);
  }

  /// 거주지 온보딩 완료 — 거주지를 서버에 저장하고 메인으로 진입한다.
  void completeResidenceSetup(String residence) {
    needsResidenceSetup = false;
    // 저장은 updateResidence(낙관 갱신 + 서버 PATCH)가 담당 — 홈 카드·세션 복원이
    // 서버 값을 읽으므로 로컬만 바꾸면 "미설정"으로 남고 재시작 시 온보딩이 또 뜬다.
    unawaited(updateResidence(residence));
    notifyListeners();
  }

  /// 거주지 변경 — 마이페이지에서 온보딩 완료 후 거주지만 갱신한다.
  /// (온보딩 진입 플래그를 건드리지 않아 completeResidenceSetup과 구분된다.)
  Future<void> updateResidence(String residence) async {
    final user = currentUser;
    if (user == null) return;
    // 낙관 갱신 후 서버 동기화 — 거주지 API(핸드오프 K) 배포 전에는 실패해도 로컬 유지.
    currentUser = user.copyWith(residence: residence);
    notifyListeners();
    try {
      final updated = await repository.updateResidence(user.id, residence);
      currentUser = currentUser?.copyWith(residence: updated.residence);
      notifyListeners();
    } catch (_) {}
  }

  /// 프로필 편집 — 닉네임·아바타 프리셋 변경. 낙관 갱신 + 서버 동기화(핸드오프 K).
  Future<void> updateProfile({String? nickname, String? avatarPreset}) async {
    final user = currentUser;
    if (user == null) return;
    final trimmed = nickname?.trim();
    final effectiveNickname =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    currentUser = user.copyWith(
      nickname: effectiveNickname,
      avatarPreset: avatarPreset,
    );
    notifyListeners();
    try {
      await repository.updateProfile(
        user.id,
        nickname: effectiveNickname,
        avatarPreset: avatarPreset,
      );
    } catch (_) {}
  }

  /// 로그아웃 — 세션 상태를 비우고 로그인 화면으로 되돌린다.
  /// 회원 탈퇴 — 서버 계정 삭제 후 기기 저장 데이터(코스·커뮤 글 등)까지 파기.
  /// 백엔드 DELETE 미배포 상태면 실패를 그대로 던진다(화면에서 안내).
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    await repository.deleteAccount(user.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await clearPersistedSession();
    // 탈퇴는 로그아웃과 달리 소셜 연결 자체를 끊는다(카카오 unlink).
    await _signOutSocialSdks(unlink: true);
    savedCourses = const [];
    selectedCourseIdsByTrip = const <int, String>{};
    pendingYoutubeCourseJobs = const [];
    logout();
  }

  /// 소셜 SDK 토큰 정리 — 로그아웃·탈퇴 시 기기에 남은 카카오·네이버 세션을 지운다.
  /// (네이버 로그인 검수 항목: 서비스 로그아웃 시 토큰 폐기. 미설정·웹이면 조용히 통과)
  Future<void> _signOutSocialSdks({bool unlink = false}) async {
    if (kIsWeb) return;
    try {
      if (unlink) {
        await kakao.UserApi.instance.unlink();
      } else {
        await kakao.UserApi.instance.logout();
      }
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOutAndDeleteToken();
    } catch (_) {}
  }

  void logout() {
    // 먼저 세대를 올린다 — 이 뒤로 도착하는 이전 세션의 갱신 응답은 전부 무효.
    _sessionEpoch++;
    mock.AppState.I.detachCommunityServer();
    _repository.clearSession();
    // 기기에 남긴 세션도 함께 파기 (완료를 기다릴 필요는 없음).
    unawaited(clearPersistedSession());
    unawaited(_signOutSocialSdks());
    currentUser = null;
    trips = const [];
    needsResidenceSetup = false;
    notifyListeners();
  }

  Future<void> loginWithCredentials({
    required String loginId,
    required String password,
  }) async {
    await _runBusy(() async {
      final authUser = await _repository.localLogin(
        loginId: loginId,
        password: password,
      );
      currentUser = await _repository.getUser(authUser.id);
      await _persistSession();
      trips = await _repository.getTrips(authUser.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
      await _attachCommunityIfServer();
    });
  }

  Future<void> signUpWithCredentials({
    required String loginId,
    required String password,
    required String residence,
  }) async {
    await _runBusy(() async {
      final authUser = await _repository.localSignUp(
        loginId: loginId,
        password: password,
        residence: residence,
      );
      currentUser = await _repository.getUser(authUser.id);
      await _persistSession();
      trips = await _repository.getTrips(authUser.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
    });
  }

  Future<void> refreshTrips() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    final epoch = _sessionEpoch;
    await _runBusy(() async {
      final fetched = await _repository.getTrips(user.id);
      if (epoch != _sessionEpoch) return; // 기다리는 사이 로그아웃 — 버린다
      trips = fetched;
    }, resetError: false);
    if (epoch != _sessionEpoch) return;
    await refreshSavedCourses();
    _adoptServerCourseSelections();
    await _pruneStaleCourseSelections();
  }

  /// 서버가 기억하는 여행-코스 연결(V90)을 로컬 맵에 반영한다.
  /// 이게 없으면 재설치·기기 변경 후 코스함에는 코스가 있는데 여행에는 안 붙는다.
  void _adoptServerCourseSelections() {
    final next = {...selectedCourseIdsByTrip};
    var changed = false;
    for (final trip in trips) {
      final serverId = trip.selectedCourseId;
      if (serverId == null) continue;
      final courseId = '$serverId';
      if (next[trip.id] != courseId) {
        next[trip.id] = courseId;
        changed = true;
      }
    }
    if (!changed) return;
    selectedCourseIdsByTrip = next;
    unawaited(_persistLocalDashboardData());
  }

  /// 존재하지 않는 여행을 가리키는 확정 코스 매핑 제거.
  /// mock 여행 id가 재사용될 때 이전 세션의 로컬 저장 매핑이 새 여행에 붙는 것을 막는다.
  Future<void> _pruneStaleCourseSelections() async {
    final validIds = trips.map((t) => t.id).toSet();
    final pruned = {
      for (final entry in selectedCourseIdsByTrip.entries)
        if (validIds.contains(entry.key)) entry.key: entry.value,
    };
    if (pruned.length == selectedCourseIdsByTrip.length) return;
    selectedCourseIdsByTrip = pruned;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<AppUser> refreshCurrentUser() async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User is not logged in');
    }

    final epoch = _sessionEpoch;
    late final AppUser refreshed;
    await _runBusy(() async {
      refreshed = await _repository.getUser(user.id);
      // 응답을 기다리는 사이 로그아웃됐으면 결과를 버린다. 여기서 currentUser를
      // 다시 채우면 루트가 로그인 화면에서 홈으로 되돌아가고, 이어지는 요청은
      // 지워진 토큰으로 나가 "화면을 불러오지 못했어요"(401)에 갇힌다.
      if (epoch != _sessionEpoch) {
        throw StateError('Session ended while refreshing user');
      }
      currentUser = refreshed;
    }, resetError: false);
    return refreshed;
  }

  Future<void> updateSettings(NotificationSettings settings) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      final updated = await _repository.updateNotificationSettings(
        user.id,
        settings,
      );
      currentUser = user.copyWith(notificationSettings: updated);
    });
  }

  Future<void> toggleFavoriteRegion(RegionSummary region) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    await _runBusy(() async {
      final isFavorite = user.favoriteRegions.any((item) => item.id == region.id);
      final updatedFavorites = isFavorite
          ? await _repository.removeFavoriteRegion(user.id, region.id)
          : await _repository.addFavoriteRegion(user.id, region.id);
      currentUser = user.copyWith(favoriteRegions: updatedFavorites);
    }, resetError: false);
  }

  List<SavedCourse> _demoSavedCourses() => [
        SavedCourse(
          id: 'demo_gangjin_course',
          regionId: 2,
          regionName: '강진',
          title: '강진 미식 1박2일 코스',
          preferences: const ['맛집', '자연', '문화'],
          stops: const [
            SavedCourseStop(
              placeId: 2,
              name: '강진만 생태공원',
              address: '전라남도 강진군 강진만길 20',
              latitude: 34.575,
              longitude: 126.78,
              sourceType: 'PLACE',
            ),
            SavedCourseStop(
              placeId: 3,
              name: '가우도 출렁다리',
              address: '전라남도 강진군 대구면 저두리',
              latitude: 34.6,
              longitude: 126.81,
              sourceType: 'PLACE',
            ),
            SavedCourseStop(
              placeId: 4,
              name: '다산초당',
              address: '전라남도 강진군 도암면 만덕리',
              latitude: 34.58,
              longitude: 126.74,
              sourceType: 'PLACE',
            ),
          ],
          createdAt: DateTime(2026, 7, 6),
        ),
      ];

  /// 코스함에 저장. 서버에도 올려 재설치·기기 변경에도 남게 한다.
  /// 서버가 새 id를 주면 그 id로 교체한다(여행-코스 연결이 서버 id 기준이라 중요).
  Future<void> saveCourse(SavedCourse course) async {
    final next = [...savedCourses];
    next.removeWhere((item) => item.id == course.id);
    next.insert(0, course);
    savedCourses = next;
    await _persistLocalDashboardData();
    notifyListeners();

    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      final saved = await _repository.saveCourseToServer(userId: userId, course: course);
      if (saved.id == course.id) return;
      savedCourses = [
        for (final item in savedCourses)
          if (item.id == course.id) saved else item,
      ];
      // 이 코스를 확정 코스로 쓰던 여행의 연결도 새 id로 옮긴다.
      final remapped = {
        for (final entry in selectedCourseIdsByTrip.entries)
          entry.key: entry.value == course.id ? saved.id : entry.value,
      };
      selectedCourseIdsByTrip = remapped;
      await _persistLocalDashboardData();
      notifyListeners();
    } catch (_) {
      // 서버 미배포·네트워크 실패 — 로컬 코스함은 그대로 쓴다.
    }
  }

  /// 서버 코스함을 받아 로컬과 합친다. 같은 id는 서버 값을 우선한다.
  Future<void> refreshSavedCourses() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      final remote = await _repository.getSavedCourses(userId);
      if (remote.isEmpty) return;
      final remoteIds = {for (final course in remote) course.id};
      savedCourses = [
        ...remote,
        ...savedCourses.where((item) => !remoteIds.contains(item.id)),
      ];
      await _persistLocalDashboardData();
      notifyListeners();
    } catch (_) {
      // 서버 미지원 — 로컬 코스함만 보여준다.
    }
  }

  Future<bool> saveCompletedYoutubeCourse(
    YoutubeCourseJobItem job, {
    String? preferredTitle,
  }) async {
    final result = job.result;
    if (!job.isCompleted || result == null || result.stops.isEmpty) {
      return false;
    }

    final existing = savedCourses.cast<SavedCourse?>().firstWhere(
          (item) => item?.id == job.jobId,
          orElse: () => null,
        );
    final customTitle = preferredTitle?.trim() ?? '';
    final resolvedTitle = existing?.title.trim().isNotEmpty == true
        ? existing!.title
        : customTitle.isNotEmpty
            ? customTitle
            : result.title.trim().isNotEmpty
                ? result.title.trim()
                : '${job.regionName} 유튜브 추천 코스';

    await saveCourse(
      SavedCourse(
        id: job.jobId,
        regionId: job.regionId,
        regionName: job.regionName,
        title: resolvedTitle,
        preferences: existing?.preferences ?? const <String>[],
        stops: result.stops
            .map(
              (stop) => SavedCourseStop(
                placeId: stop.order,
                name: stop.placeName,
                address: stop.address,
                latitude: stop.latitude,
                longitude: stop.longitude,
                sourceType: _savedCourseSourceType(stop),
              ),
            )
            .toList(),
        createdAt: existing?.createdAt ?? job.updatedAt ?? job.createdAt ?? DateTime.now(),
      ),
    );
    await _removePendingYoutubeCourseJob(job.jobId);
    return true;
  }

  SavedCourse? findSavedCourse(String courseId) {
    return savedCourses.cast<SavedCourse?>().firstWhere(
          (item) => item?.id == courseId,
          orElse: () => null,
        );
  }

  String? selectedCourseIdForTrip(int tripId) => selectedCourseIdsByTrip[tripId];

  SavedCourse? selectedCourseForTrip(int tripId) {
    final courseId = selectedCourseIdsByTrip[tripId];
    if (courseId == null || courseId.isEmpty) {
      return null;
    }
    return findSavedCourse(courseId);
  }

  List<PendingYoutubeCourseJob> pendingYoutubeJobsForTrip(int tripId) {
    return pendingYoutubeCourseJobs
        .where((job) => job.tripId == tripId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 여행에 확정 코스를 연결한다.
  /// 서버에도 저장해야 재설치·기기 변경에서 연결이 사라지지 않는다(V90).
  /// 로컬 맵은 서버 응답을 기다리지 않고 바로 화면에 반영하기 위한 것.
  Future<void> selectCourseForTrip({
    required int tripId,
    required String courseId,
  }) async {
    final next = {...selectedCourseIdsByTrip};
    next[tripId] = courseId;
    selectedCourseIdsByTrip = next;
    await _persistLocalDashboardData();
    notifyListeners();
    await _syncSelectedCourse(tripId, courseId);
  }

  /// 여행의 확정 코스 등록을 취소한다 (코스 자체는 코스함에 남는다).
  Future<void> unselectCourseForTrip(int tripId) async {
    final next = {...selectedCourseIdsByTrip}..remove(tripId);
    selectedCourseIdsByTrip = next;
    await _persistLocalDashboardData();
    notifyListeners();
    await _syncSelectedCourse(tripId, null);
  }

  /// 연결 상태를 서버에 반영. 서버가 아직 이 API를 모르면 조용히 넘어간다
  /// (로컬 맵은 이미 갱신돼 있어 화면은 그대로 동작한다).
  Future<void> _syncSelectedCourse(int tripId, String? courseId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await repository.updateTripSelectedCourse(
        tripId: tripId,
        userId: userId,
        courseId: courseId == null ? null : int.tryParse(courseId),
      );
    } catch (_) {
      // 서버 미배포·네트워크 실패 — 로컬 연결은 유지된다.
    }
  }

  /// 코스함에서 코스를 삭제한다. 이 코스를 확정 코스로 쓰던 여행의 연결도 함께 해제.
  Future<void> deleteSavedCourse(String courseId) async {
    final userId = currentUser?.id;
    if (userId != null) {
      unawaited(_repository
          .deleteSavedCourseOnServer(userId: userId, courseId: courseId)
          .catchError((_) {}));
    }
    savedCourses = [...savedCourses]..removeWhere((item) => item.id == courseId);
    selectedCourseIdsByTrip = {...selectedCourseIdsByTrip}
      ..removeWhere((_, id) => id == courseId);
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<void> trackPendingYoutubeCourseJob(PendingYoutubeCourseJob job) async {
    final next = [...pendingYoutubeCourseJobs];
    next.removeWhere((item) => item.jobId == job.jobId);
    next.insert(0, job);
    pendingYoutubeCourseJobs = next;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<void> syncPendingYoutubeCourseJobsForTrip(int tripId) async {
    final jobs = pendingYoutubeJobsForTrip(tripId);
    if (jobs.isEmpty) {
      return;
    }

    var changed = false;
    for (final pending in jobs) {
      try {
        final job = await _repository.getYoutubeCourseJob(pending.jobId);
        if (job.isCompleted) {
          await saveCompletedYoutubeCourse(job);
          changed = true;
        } else if (job.isFailed) {
          await _removePendingYoutubeCourseJob(job.jobId);
          changed = true;
        }
      } catch (_) {
        // Ignore transient sync errors; keep pending item visible.
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<SavedCourse?> syncTripPlacesToSelectedCourse({
    required int tripId,
    required int regionId,
    required String regionName,
    required List<TripPlaceItem> places,
    String? preferredTitle,
  }) async {
    if (places.isEmpty) {
      final next = {...selectedCourseIdsByTrip}..remove(tripId);
      selectedCourseIdsByTrip = next;
      await _persistLocalDashboardData();
      notifyListeners();
      return null;
    }

    final existing = selectedCourseForTrip(tripId);
    final resolvedTitle = existing?.title.trim().isNotEmpty == true
        ? existing!.title
        : (preferredTitle?.trim().isNotEmpty == true
            ? preferredTitle!.trim()
            : '$regionName 직접 코스');

    final course = SavedCourse(
      id: existing?.id ?? 'manual-$tripId-${DateTime.now().millisecondsSinceEpoch}',
      regionId: regionId,
      regionName: regionName,
      title: resolvedTitle,
      preferences: existing?.preferences ?? const <String>[],
      stops: places
          .map(
            (place) => SavedCourseStop(
              placeId: place.referencePlaceId,
              name: place.placeName,
              address: place.address,
              latitude: place.latitude ?? 0,
              longitude: place.longitude ?? 0,
              sourceType: place.placeType.wireName,
            ),
          )
          .toList(),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    await saveCourse(course);
    await selectCourseForTrip(tripId: tripId, courseId: course.id);
    return course;
  }

  String _savedCourseSourceType(YoutubeCourseJobStop stop) {
    final category = stop.category.toLowerCase();
    if (category.contains('식당') ||
        category.contains('카페') ||
        category.contains('음식') ||
        category.contains('주점') ||
        category.contains('미용')) {
      return PlaceCategory.merchant.wireName;
    }
    return PlaceCategory.halfPrice.wireName;
  }

  Future<void> deleteCourse(String courseId) async {
    savedCourses = savedCourses.where((item) => item.id != courseId).toList();
    final nextSelected = {...selectedCourseIdsByTrip}
      ..removeWhere((_, selectedCourseId) => selectedCourseId == courseId);
    selectedCourseIdsByTrip = nextSelected;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<void> setTripApplicationStatus(int tripId, bool applied) async {
    final next = {...appliedTripIds};
    if (applied) {
      next.add(tripId);
    } else {
      next.remove(tripId);
    }
    appliedTripIds = next;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<T> runTask<T>(Future<T> Function() task) async {
    errorMessage = null;
    notifyListeners();
    try {
      return await task();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _runBusy(
    Future<void> Function() task, {
    bool resetError = true,
  }) async {
    isBusy = true;
    if (resetError) {
      errorMessage = null;
    }
    notifyListeners();
    try {
      await task();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalDashboardData() async {
    final preferences = await SharedPreferences.getInstance();
    final rawCourses = preferences.getStringList(_savedCoursesKey) ?? const [];
    savedCourses = rawCourses
        .map((item) => SavedCourse.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    // mock 모드 데모: 저장 코스가 비어 있으면 시연용 코스를 채워
    // 홈 저장 코스 카드가 목업과 동일한 상태로 시작하게 한다.
    if (savedCourses.isEmpty && _repository is MockTravelRepository) {
      savedCourses = _demoSavedCourses();
    }
    final rawSelectedCourseIds = preferences.getString(_selectedCoursesKey);
    if (rawSelectedCourseIds == null || rawSelectedCourseIds.isEmpty) {
      selectedCourseIdsByTrip = const <int, String>{};
    } else {
      final decoded = jsonDecode(rawSelectedCourseIds) as Map<String, dynamic>;
      selectedCourseIdsByTrip = decoded.map(
        (key, value) => MapEntry(int.tryParse(key) ?? 0, value.toString()),
      )..remove(0);
    }
    final rawPendingJobs = preferences.getStringList(_pendingYoutubeJobsKey) ?? const [];
    pendingYoutubeCourseJobs = rawPendingJobs
        .map(
          (item) => PendingYoutubeCourseJob.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();
    appliedTripIds = (preferences.getStringList(_appliedTripsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<void> _persistLocalDashboardData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _savedCoursesKey,
      savedCourses.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await preferences.setString(
      _selectedCoursesKey,
      jsonEncode(
        selectedCourseIdsByTrip.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
    );
    await preferences.setStringList(
      _pendingYoutubeJobsKey,
      pendingYoutubeCourseJobs.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await preferences.setStringList(
      _appliedTripsKey,
      appliedTripIds.map((item) => item.toString()).toList(),
    );
  }

  Future<void> _syncFcmToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    // 로그인·세션복원 체인 한가운데서 불린다 — Firebase 미설정 기기에서 여기가 던지면
    // 로그인은 성공했는데 "실패" 토스트가 뜨고 세션 복원까지 끊긴다. 푸시는 비치명.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _registerFcmTokenIfPossible(token);
    } catch (error) {
      debugPrint('[FCM] 토큰 동기화 실패(무시): $error');
    }
  }

  Future<void> _registerFcmTokenIfPossible(String? token) async {
    final user = currentUser;
    if (user == null || token == null || token.isEmpty) {
      return;
    }
    try {
      await _repository.registerFcmToken(
        userId: user.id,
        fcmToken: token,
        platform: 'android',
      );
    } catch (_) {
      // Ignore push token registration failures to avoid blocking app usage.
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type'];
    final jobId = message.data['jobId'];
    if (type == 'YOUTUBE_COURSE_COMPLETED' && jobId is String && jobId.isNotEmpty) {
      await _syncCompletedYoutubeCourse(jobId);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('유튜브 코스 생성이 완료되었습니다.'),
          action: SnackBarAction(
            label: '보기',
            onPressed: () => _openYoutubeJob(jobId),
          ),
        ),
      );
      return;
    }
    // 커뮤니티·리마인더 등 일반 푸시 — 안드로이드는 포그라운드에서 시스템 알림을
    // 자동 표시하지 않으므로 앱 사용 중에는 스낵바로 대신 보여준다.
    final title = message.notification?.title;
    if (title != null && title.isNotEmpty) {
      final body = message.notification?.body;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            body == null || body.isEmpty ? title : '$title\n$body',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final type = message.data['type'];
    final jobId = message.data['jobId'];
    if (type == 'YOUTUBE_COURSE_COMPLETED' && jobId is String && jobId.isNotEmpty) {
      await _syncCompletedYoutubeCourse(jobId);
      _openYoutubeJob(jobId);
    }
  }

  Future<void> _syncCompletedYoutubeCourse(String jobId) async {
    try {
      final job = await _repository.getYoutubeCourseJob(jobId);
      if (job.tripId != null &&
          (job.isPending || job.isProcessing) &&
          pendingYoutubeCourseJobs.every((item) => item.jobId != job.jobId)) {
        await trackPendingYoutubeCourseJob(
          PendingYoutubeCourseJob(
            jobId: job.jobId,
            tripId: job.tripId!,
            regionId: job.regionId,
            regionName: job.regionName,
            youtubeUrl: job.youtubeUrl,
            createdAt: job.createdAt ?? DateTime.now(),
          ),
        );
      }
      await saveCompletedYoutubeCourse(job);
    } catch (_) {
      // Ignore sync failures so push handling does not block the user flow.
    }
  }

  Future<void> _removePendingYoutubeCourseJob(String jobId) async {
    final before = pendingYoutubeCourseJobs.length;
    pendingYoutubeCourseJobs =
        pendingYoutubeCourseJobs.where((item) => item.jobId != jobId).toList();
    if (pendingYoutubeCourseJobs.length != before) {
      await _persistLocalDashboardData();
      notifyListeners();
    }
  }

  Future<void> _openYoutubeJob(String jobId) async {
    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => YoutubeCourseAnalysisScreen(jobId: jobId),
      ),
    );
  }
}
