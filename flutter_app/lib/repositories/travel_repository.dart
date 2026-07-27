import 'dart:typed_data';

import '../models/app_models.dart';

abstract class TravelRepository {
  String get modeName;

  Future<AppUser> mockLogin(LoginProvider provider);
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

  /// 알림 센터 — GET /api/notifications?userId= (최신순).
  Future<List<AppNotification>> getNotifications(int userId);

  /// 알림 모두 읽음 — POST /api/notifications/read-all?userId=.
  Future<void> markAllNotificationsRead(int userId);
}
