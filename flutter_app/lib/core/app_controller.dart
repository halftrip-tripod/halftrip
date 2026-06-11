import 'dart:convert';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import '../repositories/travel_repository.dart';
import '../screens/youtube_course_analysis_screen.dart';

class AppController extends ChangeNotifier {
  AppController({required TravelRepository repository})
      : _repository = repository;

  final TravelRepository _repository;
  bool isBusy = false;
  String? errorMessage;
  AppUser? currentUser;
  List<TripSummary> trips = const [];
  List<SavedCourse> savedCourses = const [];
  Set<int> preopenAlertRegionIds = const <int>{};
  Set<int> appliedTripIds = const <int>{};

  static const _savedCoursesKey = 'saved_courses_v1';
  static const _preopenAlertsKey = 'preopen_alert_regions_v1';
  static const _appliedTripsKey = 'applied_trip_ids_v1';

  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _pushInitialized = false;

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

  Future<void> login(LoginProvider provider) async {
    await _runBusy(() async {
      final authUser = await _repository.mockLogin(provider);
      currentUser = await _repository.getUser(authUser.id);
      trips = await _repository.getTrips(authUser.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
    });
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
      trips = await _repository.getTrips(authUser.id);
      await _loadLocalDashboardData();
      await _syncFcmToken();
    });
  }

  Future<void> signUpWithCredentials({
    required String name,
    required String loginId,
    required String password,
    required String phoneNumber,
    required String residence,
  }) async {
    await _runBusy(() async {
      final authUser = await _repository.localSignUp(
        name: name,
        loginId: loginId,
        password: password,
        phoneNumber: phoneNumber,
        residence: residence,
      );
      currentUser = await _repository.getUser(authUser.id);
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
    await _runBusy(() async {
      trips = await _repository.getTrips(user.id);
    }, resetError: false);
  }

  Future<AppUser> refreshCurrentUser() async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User is not logged in');
    }

    late final AppUser refreshed;
    await _runBusy(() async {
      refreshed = await _repository.getUser(user.id);
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

  Future<void> togglePreopenAlertRegion(int regionId) async {
    final next = {...preopenAlertRegionIds};
    if (next.contains(regionId)) {
      next.remove(regionId);
    } else {
      next.add(regionId);
    }
    preopenAlertRegionIds = next;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<void> saveCourse(SavedCourse course) async {
    final next = [...savedCourses];
    next.removeWhere((item) => item.id == course.id);
    next.insert(0, course);
    savedCourses = next;
    await _persistLocalDashboardData();
    notifyListeners();
  }

  Future<bool> saveCompletedYoutubeCourse(
    YoutubeCourseJobItem job, {
    List<String>? preferredPreferences,
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
        preferences: existing?.preferences ?? preferredPreferences ?? const <String>[],
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
    return true;
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
    preopenAlertRegionIds = (preferences.getStringList(_preopenAlertsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
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
    await preferences.setStringList(
      _preopenAlertsKey,
      preopenAlertRegionIds.map((item) => item.toString()).toList(),
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
    final token = await FirebaseMessaging.instance.getToken();
    await _registerFcmTokenIfPossible(token);
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
      await saveCompletedYoutubeCourse(job);
    } catch (_) {
      // Ignore sync failures so push handling does not block the user flow.
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
