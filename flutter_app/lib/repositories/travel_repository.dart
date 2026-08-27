import 'dart:typed_data';

import '../models/app_models.dart';

abstract class TravelRepository {
  String get modeName;

  /// 로그아웃 시 호출 — 보관 중인 인증 토큰을 버린다.
  /// mock 구현은 들고 있는 토큰이 없으므로 아무것도 하지 않는다.
  void clearSession() {}

  /// 현재 세션 토큰 — 헤더를 직접 붙일 수 없는 곳(브라우저 PDF 뷰어 등)에
  /// 넘겨주기 위해 노출한다. mock·비로그인 상태에서는 null.
  String? get authToken => null;

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
  /// 로컬 회원가입. 실명·전화번호는 받지 않는다 — 개인정보 최소수집 원칙상
  /// 상시 보유하는 값은 거주지·닉네임·로그인 식별자뿐이고, 실명·전화번호는
  /// 정산 신청 시점에 그 여행 레코드에만 저장한다.
  Future<AppUser> localSignUp({
    required String loginId,
    required String password,
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

  /// 지역 축제 — TourAPI 실시간. 진행 중·예정 축제가 없으면 빈 목록.
  Future<List<RegionFestival>> getRegionFestivals(int regionId) async => const [];

  /// 지역 관광지·맛집·숙소 — TourAPI 실시간. type: 관광지|맛집|숙소|null(전체), keyword: 검색어(선택).
  Future<List<TourAttraction>> getRegionAttractions(int regionId,
          {String? type, String? keyword}) async =>
      const [];

  /// TourAPI 관광지 상세 — 없으면 null(화면은 기본 정보만).
  Future<TourPlaceDetail?> getTourPlaceDetail(String contentId,
          {int contentTypeId = 12}) async =>
      null;
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
    int? tripId, // 코스는 지역 귀속 — 여행 없이(코스함 바로 분석)도 잡 생성 가능
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

  /// OCR이 잘못 읽은 값을 사용자가 바로잡는다. null 필드는 기존 값 유지.
  /// 보정값도 서버에서 분석과 같은 심사를 다시 탄다.
  Future<ReceiptItem> correctReceipt({
    required int tripId,
    required int receiptId,
    int? amount,
    PaymentType? paymentType,
    DateTime? paymentDateTime,
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

  /// 숙박확인서 PDF 원본 바이트 — 인쇄·공유(printing 패키지)에 사용.
  Future<Uint8List> fetchLodgingFormPdfBytes(int tripId);
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
  /// 증빙 파일들을 하나의 PDF로 병합해 저장하고 경로를 돌려준다.
  /// [fileName]을 주면 그 이름으로 저장한다(미지정 시 trip-{id}-documents.pdf).
  Future<String> downloadMergedPdf(
    int tripId,
    List<int> uploadedFileIds, {
    String? fileName,
  });

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
