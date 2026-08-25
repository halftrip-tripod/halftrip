import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/app_config.dart';
import '../models/app_models.dart';
import '../utils/browser_file_download.dart';
import 'travel_repository.dart';

class ApiTravelRepository implements TravelRepository {
  ApiTravelRepository(this.config);

  final AppConfig config;

  /// 로그인 응답으로 받은 인증 토큰.
  ///
  /// 이게 없으면 서버는 `?userId=` 만 보고 요청을 처리할 수밖에 없어 번호만 바꾸면
  /// 남의 자원이 열린다. 앱을 다시 켜면 로그인부터 다시 하므로 메모리에만 들고 있는다.
  String? _authToken;

  @override
  String get modeName => 'API Mode';

  @override
  void clearSession() {
    _authToken = null;
  }

  /// 세션 영속화용 — 현재 토큰 조회. (secure storage 저장은 AppController 책임)
  String? get authToken => _authToken;

  /// 앱 재시작 시 secure storage에 보관해둔 토큰을 다시 채운다.
  /// 유효성은 이어지는 getUser 호출이 검증한다(만료면 401).
  void adoptToken(String token) {
    _authToken = token;
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// 로그인·회원가입 응답에서 토큰을 꺼내 보관한다. 이후 모든 요청에 실려 나간다.
  void _rememberToken(Map<String, dynamic> data) {
    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      _authToken = token;
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(config.apiBaseUrl);
    final mergedPath =
        '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path';
    return base.replace(
      path: mergedPath,
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final headers = _headers();
    late http.Response response;
    final uri = _uri(path, query);
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      default:
        throw UnsupportedError('Unsupported method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] == false) {
      throw Exception(decoded['message'] ?? '요청에 실패했습니다.');
    }
    return decoded;
  }

  Future<String> _downloadToDocuments(
    String path,
    String fileName, {
    Map<String, dynamic>? query,
  }) async {
    final response = await http.get(_uri(path, query), headers: _headers(json: false));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('다운로드 실패: ${response.body}');
    }
    if (kIsWeb) {
      await downloadFileBytes(
        response.bodyBytes,
        fileName,
        mimeType: response.headers['content-type'] ?? 'application/pdf',
      );
      return 'Browser download started: $fileName';
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<String> _downloadFromUri(Uri uri, String fileName) async {
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('다운로드 실패: ${response.body}');
    }
    if (kIsWeb) {
      await downloadFileBytes(
        response.bodyBytes,
        fileName,
        mimeType: response.headers['content-type'] ?? 'application/pdf',
      );
      return 'Browser download started: $fileName';
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  @override
  Future<SocialLoginResult> socialLogin({
    required LoginProvider provider,
    required String accessToken,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/auth/social-login',
      body: {
        'provider': provider.wireName,
        'accessToken': accessToken,
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    _rememberToken(data);
    final user = await getUser(data['userId'] as int);
    return SocialLoginResult(
      user: user,
      newUser: data['newUser'] as bool? ?? false,
      needsResidence: data['needsResidence'] as bool? ?? false,
    );
  }

  @override
  Future<AppUser> mockLogin(LoginProvider provider) async {
    final response = await _jsonRequest(
      'POST',
      '/auth/mock-login',
      body: {
        'provider': provider.wireName,
        'email': '${provider.name}@travel-mvp.local',
        'name': provider == LoginProvider.guest
            ? '게스트 사용자'
            : '${provider.label} 사용자',
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    _rememberToken(data);
    return getUser(data['userId'] as int);
  }

  @override
  Future<AppUser> localLogin({
    required String loginId,
    required String password,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/auth/login',
      body: {
        'loginId': loginId,
        'password': password,
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    _rememberToken(data);
    return getUser(data['userId'] as int);
  }

  @override
  Future<AppUser> localSignUp({
    required String loginId,
    required String password,
    required String residence,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/auth/signup',
      body: {
        'loginId': loginId,
        'password': password,
        'residence': residence,
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    _rememberToken(data);
    return getUser(data['userId'] as int);
  }

  @override
  Future<AppUser> getUser(int userId) async {
    final response = await _jsonRequest('GET', '/users/$userId');
    return AppUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAccount(int userId) async {
    await _jsonRequest('DELETE', '/users/$userId');
  }

  @override
  Future<AppUser> updateResidence(int userId, String residence) async {
    final response = await _jsonRequest(
      'PATCH',
      '/users/$userId/residence',
      body: {'residence': residence},
    );
    return AppUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> updateProfile(
    int userId, {
    String? nickname,
    String? avatarPreset,
  }) async {
    final response = await _jsonRequest(
      'PATCH',
      '/users/$userId/profile',
      body: {
        if (nickname != null) 'nickname': nickname,
        if (avatarPreset != null) 'avatarPreset': avatarPreset,
      },
    );
    return AppUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<TripSummary>> getTrips(int userId) async {
    final response = await _jsonRequest(
      'GET',
      '/trips',
      query: {'userId': userId},
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => TripSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TripDetail> getTripDetail(int tripId) async {
    final response = await _jsonRequest('GET', '/trips/$tripId');
    return TripDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<RegionSummary>> getRegions({String? residence}) async {
    final response = await _jsonRequest(
      'GET',
      '/regions',
      query: residence == null || residence.isEmpty
          ? null
          : {'residence': residence},
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => RegionSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RegionDetail> getRegionDetail(
    int regionId, {
    String? residence,
    bool includeMerchants = true,
  }) async {
    final response = await _jsonRequest(
      'GET',
      '/regions/$regionId',
      query: {
        if (residence != null && residence.isNotEmpty) 'residence': residence,
        'includeMerchants': includeMerchants,
      },
    );
    return RegionDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<PlaceInfoDetail> getPlaceInfoDetail(
    int regionId, {
    String? residence,
  }) async {
    final response = await _jsonRequest(
      'GET',
      '/regions/$regionId/place-info',
      query: {
        if (residence != null && residence.isNotEmpty) 'residence': residence,
      },
    );
    return PlaceInfoDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<MerchantMapSearchResult> getMerchantMap({
    required int regionId,
    double? southLat,
    double? northLat,
    double? westLng,
    double? eastLng,
  }) async {
    final response = await _jsonRequest(
      'GET',
      '/regions/$regionId/merchant-map',
      query: {
        if (southLat != null) 'southLat': southLat,
        if (northLat != null) 'northLat': northLat,
        if (westLng != null) 'westLng': westLng,
        if (eastLng != null) 'eastLng': eastLng,
      },
    );
    return MerchantMapSearchResult.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<MerchantDetailItem> getMerchantDetail({
    required int regionId,
    required int merchantId,
  }) async {
    final response = await _jsonRequest(
      'GET',
      '/regions/$regionId/merchant-map/$merchantId',
    );
    return MerchantDetailItem.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TripSummary> createTrip({
    required int userId,
    required TripDraft draft,
    required int regionId,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/trips',
      body: {
        'userId': userId,
        'applicantName': draft.applicantName,
        'phoneNumber': draft.phoneNumber,
        'residence': draft.residence,
        'startDate': draft.startDate.toIso8601String().split('T').first,
        'endDate': draft.endDate.toIso8601String().split('T').first,
        'travelerCount': draft.travelerCount,
        'regionId': regionId,
      },
    );
    return TripSummary.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<CreateYoutubeCourseJobResponse> createYoutubeCourseJob({
    required int userId,
    int? tripId,
    required int regionId,
    required String youtubeUrl,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/youtube-course-jobs',
      body: {
        'userId': userId,
        if (tripId != null) 'tripId': tripId,
        'regionId': regionId,
        'youtubeUrl': youtubeUrl,
      },
    );
    return CreateYoutubeCourseJobResponse.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<YoutubeCourseJobItem> getYoutubeCourseJob(String jobId) async {
    final response = await _jsonRequest('GET', '/youtube-course-jobs/$jobId');
    return YoutubeCourseJobItem.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<GooglePlaceDetailItem?> searchGooglePlaceDetail({
    required String placeName,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/google-places/search',
      body: {
        'placeName': placeName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }
    return GooglePlaceDetailItem.fromJson(data);
  }

  @override
  Future<YoutubeCourseJobItem?> getActiveYoutubeCourseJob({
    required int userId,
    required int tripId,
  }) async {
    try {
      final response = await _jsonRequest(
        'GET',
        '/youtube-course-jobs/active',
        query: {
          'userId': userId,
          'tripId': tripId,
        },
      );
      return YoutubeCourseJobItem.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registerFcmToken({
    required int userId,
    required String fcmToken,
    required String platform,
  }) async {
    await _jsonRequest(
      'POST',
      '/users/$userId/fcm-tokens',
      body: {
        'fcmToken': fcmToken,
        'platform': platform,
      },
    );
  }

  @override
  Future<List<TripPlaceItem>> replaceTripPlaces(
    int tripId,
    List<TripPlaceItem> places,
  ) async {
    final response = await _jsonRequest(
      'PUT',
      '/trips/$tripId/places',
      body: {
        'places': places.map((item) => item.toReplacementJson()).toList(),
      },
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => TripPlaceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UploadedFileItem> uploadFile({
    required int tripId,
    required FileCategory category,
    required UploadBinary file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/trips/$tripId/uploaded-files', {'category': category.wireName}),
    );
    request.headers.addAll(_headers(json: false));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes,
        filename: file.fileName,
      ),
    );
    final streamed = await request.send();
    final responseText = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('파일 업로드 실패: $responseText');
    }
    final decoded = jsonDecode(responseText) as Map<String, dynamic>;
    return UploadedFileItem.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  @override
  Future<AuthPhotoReviewResult> analyzeAuthPhoto({
    required int tripId,
    required int uploadedFileId,
    int? placeId,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/trips/$tripId/auth-photos/analyze/$uploadedFileId',
      query: placeId == null ? null : {'placeId': placeId},
      body: const {},
    );
    return AuthPhotoReviewResult.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteUploadedFile({
    required int tripId,
    required int uploadedFileId,
  }) async {
    await _jsonRequest(
      'DELETE',
      '/trips/$tripId/uploaded-files/$uploadedFileId',
    );
  }

  @override
  Future<Uint8List> downloadUploadedFileBytes({
    required int tripId,
    required int uploadedFileId,
  }) async {
    final response = await http.get(
      _uri('/trips/$tripId/uploaded-files/$uploadedFileId/binary'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('파일 다운로드 실패: ${response.body}');
    }
    return response.bodyBytes;
  }

  @override
  Future<ReceiptItem> analyzeReceipt({
    required int tripId,
    required int uploadedFileId,
    required ReceiptUsageScope usageScope,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/trips/$tripId/receipts/analyze/$uploadedFileId',
      body: {'usageScope': usageScope.wireName},
    );
    return ReceiptItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<ReceiptItem> correctReceipt({
    required int tripId,
    required int receiptId,
    int? amount,
    PaymentType? paymentType,
    DateTime? paymentDateTime,
  }) async {
    // 서버가 "yyyy-MM-dd HH:mm" 문자열을 기대한다 (springboot #58).
    String? dt;
    if (paymentDateTime != null) {
      final d = paymentDateTime;
      String two(int v) => v.toString().padLeft(2, '0');
      dt = '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    final response = await _jsonRequest(
      'PATCH',
      '/trips/$tripId/receipts/$receiptId',
      body: {
        if (amount != null) 'amount': amount,
        if (paymentType != null) 'paymentType': paymentType.wireName,
        if (dt != null) 'paymentDateTime': dt,
      },
    );
    return ReceiptItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingInfo> saveLodgingInfo(
    int tripId,
    LodgingInfo lodgingInfo,
  ) async {
    final response = await _jsonRequest(
      'POST',
      '/trips/$tripId/lodging-info',
      body: lodgingInfo.toJson(),
    );
    return LodgingInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingInfo> extractLodgingInfo({
    required int tripId,
    required int uploadedFileId,
  }) async {
    final response = await _jsonRequest(
      'POST',
      '/trips/$tripId/lodging-info/extract/$uploadedFileId',
      body: const {},
    );
    return LodgingInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingFormData> getLodgingFormData(int tripId) async {
    final response = await _jsonRequest('GET', '/integrations/lodging-form/$tripId');
    return LodgingFormData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingFormData> saveLodgingForm(
    int tripId,
    LodgingFormSaveRequest request,
  ) async {
    final response = await _jsonRequest(
      'PUT',
      '/trips/$tripId/lodging-form',
      body: request.toJson(),
    );
    return LodgingFormData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingFormData> saveLodgingFormTemplateLayout(
    int tripId,
    List<LodgingFormFieldItem> fields,
  ) async {
    final response = await _jsonRequest(
      'PUT',
      '/integrations/lodging-form/$tripId/template-layout',
      body: {
        'fields': fields.map((field) => field.toJson()).toList(),
      },
    );
    return LodgingFormData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<LodgingFormData> analyzeLodgingFormTemplate(int tripId) async {
    final response = await _jsonRequest(
      'POST',
      '/integrations/lodging-form/$tripId/analyze-template',
      body: const {},
    );
    return LodgingFormData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  String? getLodgingFormTemplatePreviewUrl(int tripId) {
    return _uri('/integrations/lodging-form/$tripId/template-pdf').toString();
  }

  @override
  String? getLodgingFormRenderedPdfUrl(int tripId) {
    return _uri('/integrations/lodging-form/$tripId/pdf').toString();
  }

  @override
  Future<String> downloadLodgingFormPdf(int tripId) {
    return _downloadToDocuments(
      '/integrations/lodging-form/$tripId/pdf',
      'trip-$tripId-lodging-form.pdf',
    );
  }

  @override
  Future<Uint8List> fetchLodgingFormPdfBytes(int tripId) async {
    final response = await http.get(_uri('/integrations/lodging-form/$tripId/pdf'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('숙박확인서 PDF 불러오기 실패: ${response.body}');
    }
    return response.bodyBytes;
  }

  @override
  Future<SettlementSummary> getSettlementSummary(int tripId) async {
    final response = await _jsonRequest(
      'GET',
      '/trips/$tripId/settlement-summary',
    );
    return SettlementSummary.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> applySettlement(
    int tripId, {
    String? applicantName,
    String? phoneNumber,
  }) async {
    await _jsonRequest(
      'POST',
      '/trips/$tripId/settlement-apply',
      body: {
        if (applicantName != null) 'applicantName': applicantName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
  }

  @override
  Future<NotificationSettings> updateNotificationSettings(
    int userId,
    NotificationSettings settings,
  ) async {
    final response = await _jsonRequest(
      'PUT',
      '/users/$userId/notification-settings',
      body: settings.toJson(),
    );
    return NotificationSettings.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<RegionSummary>> addFavoriteRegion(int userId, int regionId) async {
    final response = await _jsonRequest(
      'POST',
      '/users/$userId/favorite-regions',
      body: {'regionId': regionId},
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => RegionSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<RegionSummary>> removeFavoriteRegion(int userId, int regionId) async {
    final response = await _jsonRequest(
      'DELETE',
      '/users/$userId/favorite-regions/$regionId',
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => RegionSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> downloadMergedPdf(
    int tripId,
    List<int> uploadedFileIds, {
    String? fileName,
  }) {
    final uri = _uri('/integrations/pdf/merge/$tripId')
        .replace(query: uploadedFileIds.map((id) => 'uploadedFileIds=$id').join('&'));
    return _downloadFromUri(uri, fileName ?? 'trip-$tripId-documents.pdf');
  }

  // ── 커뮤니티 ──

  @override
  Future<List<CommunityPostData>> getCommunityFeed({int? userId}) async {
    final response = await _jsonRequest('GET', '/community/posts',
        query: userId == null ? null : {'userId': userId});
    return ((response['data'] as List<dynamic>?) ?? const [])
        .map((e) => CommunityPostData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityPostData> createCommunityPost({
    required int userId,
    required String type,
    String? regionName,
    String? title,
    required String body,
    List<String> photos = const [],
    String? courseName,
    String? courseMeta,
    List<SavedCourseStop> courseStops = const [],
    int? tripId,
    required String visibility,
  }) async {
    final response = await _jsonRequest('POST', '/community/posts', body: {
      'userId': userId,
      'type': type,
      if (regionName != null) 'regionName': regionName,
      if (title != null) 'title': title,
      'body': body,
      'photos': photos,
      if (courseName != null) 'courseName': courseName,
      if (courseMeta != null) 'courseMeta': courseMeta,
      if (courseStops.isNotEmpty)
        'courseStops': courseStops.map((s) => s.toJson()).toList(),
      if (tripId != null) 'tripId': tripId,
      'visibility': visibility,
    });
    return CommunityPostData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> toggleCommunityLike(int postId, int userId) async {
    await _jsonRequest('POST', '/community/posts/$postId/like',
        query: {'userId': userId}, body: const {});
  }

  @override
  Future<void> toggleCommunityBookmark(int postId, int userId) async {
    await _jsonRequest('POST', '/community/posts/$postId/bookmark',
        query: {'userId': userId}, body: const {});
  }

  @override
  Future<void> updateCommunityVisibility(
      int postId, int userId, String visibility) async {
    await _jsonRequest('PATCH', '/community/posts/$postId',
        body: {'userId': userId, 'visibility': visibility});
  }

  @override
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
    bool clearCourse = false,
    String? visibility,
  }) async {
    final response = await _jsonRequest('PATCH', '/community/posts/$postId', body: {
      'userId': userId,
      if (type != null) 'type': type,
      if (regionName != null) 'regionName': regionName,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (photos != null) 'photos': photos,
      if (courseName != null) 'courseName': courseName,
      if (courseMeta != null) 'courseMeta': courseMeta,
      if (courseStops != null && courseStops.isNotEmpty)
        'courseStops': courseStops.map((s) => s.toJson()).toList(),
      if (clearCourse) 'clearCourse': true,
      if (visibility != null) 'visibility': visibility,
    });
    return CommunityPostData.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteCommunityPost(int postId, int userId) async {
    await _jsonRequest('DELETE', '/community/posts/$postId',
        query: {'userId': userId});
  }

  @override
  Future<List<CommunityCommentData>> getCommunityComments(int postId,
      {int? userId}) async {
    final response = await _jsonRequest('GET', '/community/posts/$postId/comments',
        query: userId == null ? null : {'userId': userId});
    return ((response['data'] as List<dynamic>?) ?? const [])
        .map((e) => CommunityCommentData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityCommentData> addCommunityComment(
      int postId, int userId, String body,
      {int? parentId, int? mentionUserId}) async {
    final response = await _jsonRequest('POST', '/community/posts/$postId/comments',
        body: {
          'userId': userId,
          'body': body,
          if (parentId != null) 'parentId': parentId,
          if (mentionUserId != null) 'mentionUserId': mentionUserId,
        });
    return CommunityCommentData.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> toggleCommunityCommentLike(int commentId, int userId) async {
    await _jsonRequest('POST', '/community/comments/$commentId/like',
        query: {'userId': userId}, body: const {});
  }

  @override
  Future<void> deleteCommunityComment(int commentId, int userId) async {
    await _jsonRequest('DELETE', '/community/comments/$commentId',
        query: {'userId': userId});
  }

  @override
  Future<void> reportCommunity({
    required int userId,
    required String targetType,
    required int targetId,
    String? reason,
  }) async {
    await _jsonRequest('POST', '/community/reports', body: {
      'userId': userId,
      'targetType': targetType,
      'targetId': targetId,
      if (reason != null) 'reason': reason,
    });
  }

  @override
  Future<CommunityMyPosts> getMyCommunityPosts(int userId) async {
    final response = await _jsonRequest('GET', '/community/users/$userId/posts');
    return CommunityMyPosts.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<CommunityPostData>> getMyCommunityBookmarks(int userId) async {
    final response =
        await _jsonRequest('GET', '/community/users/$userId/bookmarks');
    return ((response['data'] as List<dynamic>?) ?? const [])
        .map((e) => CommunityPostData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ChecklistItem>> getTripChecklist(int tripId) async {
    final response = await _jsonRequest('GET', '/trips/$tripId/checklist');
    return _parseChecklist(response['data']);
  }

  /// 서버 응답은 `{tripId, doneCount, total, items:[...]}` 래핑 — items만 꺼낸다.
  List<ChecklistItem> _parseChecklist(dynamic data) {
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : (data as List<dynamic>? ?? const []);
    return items
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ChecklistItem>> updateTripChecklist(
    int tripId,
    List<ChecklistItem> items,
  ) async {
    final response = await _jsonRequest(
      'PUT',
      '/trips/$tripId/checklist',
      body: {'items': items.map((item) => item.toJson()).toList()},
    );
    return _parseChecklist(response['data']);
  }

  @override
  Future<List<AppNotification>> getNotifications(int userId) async {
    // 쿼리는 query 파라미터로 — 경로에 ?를 넣으면 _uri()가 %3F로 인코딩해 CORS preflight가 깨진다.
    final response = await _jsonRequest(
      'GET',
      '/notifications',
      query: {'userId': userId},
    );
    final items = response['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAllNotificationsRead(int userId) async {
    await _jsonRequest(
      'POST',
      '/notifications/read-all',
      query: {'userId': userId},
      body: const {},
    );
  }
}
