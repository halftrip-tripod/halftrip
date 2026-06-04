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
  Future<AuthPhotoReviewResult> analyzeAuthPhoto({
    required int tripId,
    required int uploadedFileId,
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
  Future<void> applySettlement(int tripId);
  Future<NotificationSettings> updateNotificationSettings(
    int userId,
    NotificationSettings settings,
  );
  Future<List<RegionSummary>> addFavoriteRegion(int userId, int regionId);
  Future<List<RegionSummary>> removeFavoriteRegion(int userId, int regionId);
  Future<String> downloadMergedPdf(int tripId, List<int> uploadedFileIds);
}
