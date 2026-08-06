import 'dart:typed_data';

import '../models/app_models.dart';

abstract class TravelRepository {
  String get modeName;

  Future<AppUser> mockLogin(LoginProvider provider);
  /// 소셜 로그인 — SDK가 받은 액세스 토큰을 서버가 제공자 API로 검증.
  Future<SocialLoginResult> socialLogin({
    required LoginProvider provider,
    required String accessToken,
  });
  Future<AppUser> localLogin({
    required String loginId,
    required String password,
  });
  Future<AppUser> localSignUp({
    required String name,
    required String loginId,
    required String password,
    required String phoneNumber,
    required String residence,
  });
  Future<AppUser> getUser(int userId);

  /// 회원 탈퇴 — DELETE /api/users/{userId} (핸드오프 13, soft delete).
  Future<void> deleteAccount(int userId);

  /// 거주지 수정 — PATCH /api/users/{userId}/residence (핸드오프 K).
  Future<AppUser> updateResidence(int userId, String residence);

  /// 프로필(닉네임·아바타) 수정 — PUT /api/users/{userId}/profile (핸드오프 K).
  Future<AppUser> updateProfile(
    int userId, {
    String? nickname,
    String? avatarPreset,
  });
  Future<List<TripSummary>> getTrips(int userId);
  Future<TripDetail> getTripDetail(int tripId);
  Future<List<RegionSummary>> getRegions({String? residence});
  Future<RegionDetail> getRegionDetail(
    int regionId, {
    String? residence,
    bool includeMerchants = true,
  });
  Future<PlaceInfoDetail> getPlaceInfoDetail(int regionId, {String? residence});
  Future<MerchantMapSearchResult> getMerchantMap({
    required int regionId,
    double? southLat,
    double? northLat,
    double? westLng,
    double? eastLng,
  });
  Future<MerchantDetailItem> getMerchantDetail({
    required int regionId,
    required int merchantId,
  });
  Future<TripSummary> createTrip({
    required int userId,
    required TripDraft draft,
    required int regionId,
  });
  Future<CreateYoutubeCourseJobResponse> createYoutubeCourseJob({
    required int userId,
    required int tripId,
    required int regionId,
    required String youtubeUrl,
  });
  Future<YoutubeCourseJobItem?> getActiveYoutubeCourseJob({
    required int userId,
    required int tripId,
  });
  Future<YoutubeCourseJobItem> getYoutubeCourseJob(String jobId);
  Future<GooglePlaceDetailItem?> searchGooglePlaceDetail({
    required String placeName,
    required String address,
    required double latitude,
    required double longitude,
  });
  Future<void> registerFcmToken({
    required int userId,
    required String fcmToken,
    required String platform,
  });
  Future<List<TripPlaceItem>> replaceTripPlaces(
    int tripId,
    List<TripPlaceItem> places,
  );
  Future<UploadedFileItem> uploadFile({
    required int tripId,
    required FileCategory category,
    required UploadBinary file,
  });
  /// [placeId]를 넘기면 해당 지정관광지 좌표 반경 기준 위치검증까지 수행(백엔드 F).
  Future<AuthPhotoReviewResult> analyzeAuthPhoto({
    required int tripId,
    required int uploadedFileId,
    int? placeId,
  });
  Future<void> deleteUploadedFile({
    required int tripId,
    required int uploadedFileId,
  });
  Future<Uint8List> downloadUploadedFileBytes({
    required int tripId,
    required int uploadedFileId,
  });
  Future<ReceiptItem> analyzeReceipt({
    required int tripId,
    required int uploadedFileId,
    required ReceiptUsageScope usageScope,
  });
  Future<LodgingInfo> saveLodgingInfo(int tripId, LodgingInfo lodgingInfo);
  Future<LodgingInfo> extractLodgingInfo({
    required int tripId,
    required int uploadedFileId,
  });
  Future<LodgingFormData> getLodgingFormData(int tripId);
  Future<LodgingFormData> saveLodgingForm(
    int tripId,
    LodgingFormSaveRequest request,
  );
  Future<LodgingFormData> saveLodgingFormTemplateLayout(
    int tripId,
    List<LodgingFormFieldItem> fields,
  );
  Future<LodgingFormData> analyzeLodgingFormTemplate(int tripId);
  String? getLodgingFormTemplatePreviewUrl(int tripId);
  String? getLodgingFormRenderedPdfUrl(int tripId);
  Future<String> downloadLodgingFormPdf(int tripId);
  Future<SettlementSummary> getSettlementSummary(int tripId);
  /// 정산 신청 — 실명·전화번호는 정산 시점에만 수집(개인정보 최소화 계약 B).
  Future<void> applySettlement(
    int tripId, {
    String? applicantName,
    String? phoneNumber,
  });
  Future<NotificationSettings> updateNotificationSettings(
    int userId,
    NotificationSettings settings,
  );
  Future<List<RegionSummary>> addFavoriteRegion(int userId, int regionId);
  Future<List<RegionSummary>> removeFavoriteRegion(int userId, int regionId);
  Future<String> downloadMergedPdf(int tripId, List<int> uploadedFileIds);

  /// 출발 준비 체크리스트 조회 — GET /api/trips/{tripId}/checklist (핸드오프 E).
  Future<List<ChecklistItem>> getTripChecklist(int tripId);

  /// 체크 상태 저장(전체 교체) — PUT /api/trips/{tripId}/checklist.
  Future<List<ChecklistItem>> updateTripChecklist(
    int tripId,
    List<ChecklistItem> items,
  );

  // ── 커뮤니티 (/api/community — 2026-07-28 구현) ──
  Future<List<CommunityPostData>> getCommunityFeed({int? userId});
  Future<CommunityPostData> createCommunityPost({
    required int userId,
    required String type,
    String? regionName,
    String? title,
    required String body,
    List<String> photos,
    String? courseName,
    String? courseMeta,
    List<SavedCourseStop> courseStops,
    int? tripId,
    required String visibility,
  });
  Future<void> toggleCommunityLike(int postId, int userId);
  Future<void> toggleCommunityBookmark(int postId, int userId);
  Future<void> updateCommunityVisibility(int postId, int userId, String visibility);
  Future<void> deleteCommunityPost(int postId, int userId);
  Future<CommunityPostData> updateCommunityPost({
    required int postId,
    required int userId,
    String? type,
    String? regionName,
    String? title,
    String? body,
    List<String>? photos,
    String? courseName,
    String? courseMeta,
    List<SavedCourseStop>? courseStops,
    bool clearCourse,
    String? visibility,
  });
  Future<List<CommunityCommentData>> getCommunityComments(int postId, {int? userId});
  Future<CommunityCommentData> addCommunityComment(int postId, int userId, String body,
      {int? parentId, int? mentionUserId});
  Future<void> toggleCommunityCommentLike(int commentId, int userId);
  Future<void> deleteCommunityComment(int commentId, int userId);
  Future<void> reportCommunity({
    required int userId,
    required String targetType,
    required int targetId,
    String? reason,
  });
  Future<CommunityMyPosts> getMyCommunityPosts(int userId);
  Future<List<CommunityPostData>> getMyCommunityBookmarks(int userId);

  /// 알림 센터 — GET /api/notifications?userId= (최신순).
  Future<List<AppNotification>> getNotifications(int userId);

  /// 알림 모두 읽음 — POST /api/notifications/read-all?userId=.
  Future<void> markAllNotificationsRead(int userId);
}
