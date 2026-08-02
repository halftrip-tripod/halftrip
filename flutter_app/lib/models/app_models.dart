import 'dart:convert';

enum LoginProvider { kakao, naver, google, guest }

enum PlaceCategory { halfPrice, digitalTourCard, merchant }

enum FileCategory {
  authPhoto,
  receiptImage,
  lodgingConfirmation,
  signature,
  generatedPdf,
}

enum PaymentType {
  creditCard,
  checkCard,
  onlinePayment,
  bankTransfer,
  cashReceipt,
  simpleReceipt,
  unknown,
}

enum ReceiptUsageScope { general, lodging }

enum ReceiptReviewStatus { pending, approved, rejected }

class UploadBinary {
  const UploadBinary({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String? mimeType;
}

extension EnumWireName on PlaceCategory {
  String get wireName => switch (this) {
        PlaceCategory.halfPrice => 'HALF_PRICE',
        PlaceCategory.digitalTourCard => 'DIGITAL_TOUR_CARD',
        PlaceCategory.merchant => 'MERCHANT',
      };

  String get label => switch (this) {
        PlaceCategory.halfPrice => '반값여행',
        PlaceCategory.digitalTourCard => '디지털 관광주민증',
        PlaceCategory.merchant => '지역화폐 가맹점',
      };
}

extension FileCategoryWire on FileCategory {
  String get wireName => switch (this) {
        FileCategory.authPhoto => 'AUTH_PHOTO',
        FileCategory.receiptImage => 'RECEIPT_IMAGE',
        FileCategory.lodgingConfirmation => 'LODGING_CONFIRMATION',
        FileCategory.signature => 'SIGNATURE',
        FileCategory.generatedPdf => 'GENERATED_PDF',
      };

  String get label => switch (this) {
        FileCategory.authPhoto => '인증사진',
        FileCategory.receiptImage => '영수증',
        FileCategory.lodgingConfirmation => '숙박확인서',
        FileCategory.signature => '서명',
        FileCategory.generatedPdf => '생성 PDF',
      };
}

extension PaymentTypeWire on PaymentType {
  static PaymentType fromWire(String value) => switch (value.toUpperCase()) {
        'CREDIT_CARD' => PaymentType.creditCard,
        'CHECK_CARD' => PaymentType.checkCard,
        'ONLINE_PAYMENT' => PaymentType.onlinePayment,
        'BANK_TRANSFER' => PaymentType.bankTransfer,
        'CASH_RECEIPT' => PaymentType.cashReceipt,
        'SIMPLE_RECEIPT' => PaymentType.simpleReceipt,
        _ => PaymentType.unknown,
      };

  String get label => switch (this) {
        PaymentType.creditCard => '카드 결제',
        PaymentType.checkCard => '체크카드',
        PaymentType.onlinePayment => '온라인 결제',
        PaymentType.bankTransfer => '계좌이체',
        PaymentType.cashReceipt => '현금영수증',
        PaymentType.simpleReceipt => '간이영수증',
        PaymentType.unknown => '판별 실패',
      };
}

extension ReceiptUsageScopeWire on ReceiptUsageScope {
  static ReceiptUsageScope fromWire(String value) => switch (value.toUpperCase()) {
        'LODGING' => ReceiptUsageScope.lodging,
        _ => ReceiptUsageScope.general,
      };

  String get wireName => switch (this) {
        ReceiptUsageScope.general => 'GENERAL',
        ReceiptUsageScope.lodging => 'LODGING',
      };

  String get label => switch (this) {
        ReceiptUsageScope.general => '일반 결제',
        ReceiptUsageScope.lodging => '숙박 결제',
      };
}

extension ReceiptReviewStatusWire on ReceiptReviewStatus {
  static ReceiptReviewStatus fromWire(String value) => switch (value.toUpperCase()) {
        'APPROVED' => ReceiptReviewStatus.approved,
        'REJECTED' => ReceiptReviewStatus.rejected,
        _ => ReceiptReviewStatus.pending,
      };

  String get label => switch (this) {
        ReceiptReviewStatus.pending => '심사중',
        ReceiptReviewStatus.approved => '통과',
        ReceiptReviewStatus.rejected => '불인정',
      };
}

extension LoginProviderWire on LoginProvider {
  String get wireName => switch (this) {
        LoginProvider.kakao => 'KAKAO',
        LoginProvider.naver => 'NAVER',
        LoginProvider.google => 'GOOGLE',
        LoginProvider.guest => 'GUEST',
      };

  String get label => switch (this) {
        LoginProvider.kakao => '카카오',
        LoginProvider.naver => '네이버',
        LoginProvider.google => '구글',
        LoginProvider.guest => '게스트',
      };
}

extension PlaceCategoryParsing on PlaceCategory {
  static PlaceCategory fromWire(String value) => switch (value.toUpperCase()) {
        'DIGITAL_TOUR_CARD' => PlaceCategory.digitalTourCard,
        'MERCHANT' => PlaceCategory.merchant,
        _ => PlaceCategory.halfPrice,
      };
}

class NotificationSettings {
  const NotificationSettings({
    required this.favoriteRegionPreopenAlert,
    required this.tripEndSettlementAlert,
    this.marketingAlert = false,
  });

  final bool favoriteRegionPreopenAlert;
  final bool tripEndSettlementAlert;
  final bool marketingAlert;

  NotificationSettings copyWith({
    bool? favoriteRegionPreopenAlert,
    bool? tripEndSettlementAlert,
    bool? marketingAlert,
  }) {
    return NotificationSettings(
      favoriteRegionPreopenAlert:
          favoriteRegionPreopenAlert ?? this.favoriteRegionPreopenAlert,
      tripEndSettlementAlert:
          tripEndSettlementAlert ?? this.tripEndSettlementAlert,
      marketingAlert: marketingAlert ?? this.marketingAlert,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      favoriteRegionPreopenAlert:
          json['favoriteRegionPreopenAlert'] as bool? ?? false,
      tripEndSettlementAlert: json['tripEndSettlementAlert'] as bool? ?? false,
      marketingAlert: json['marketingAlert'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteRegionPreopenAlert': favoriteRegionPreopenAlert,
        'tripEndSettlementAlert': tripEndSettlementAlert,
        'marketingAlert': marketingAlert,
      };
}

/// 커뮤니티 게시글 (서버 계약: /api/community/posts — 2026-07-28).
class CommunityPostData {
  const CommunityPostData({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.regionName,
    required this.photos,
    required this.courseName,
    required this.courseMeta,
    required this.verified,
    required this.edited,
    required this.visibility,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.likedByMe,
    required this.savedByMe,
    required this.mine,
    required this.authorNickname,
    required this.authorAvatarPreset,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String? title;
  final String body;
  final String? regionName;
  final List<String> photos;
  final String? courseName;
  final String? courseMeta;
  final bool verified;
  final bool edited;
  final String visibility;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final bool likedByMe;
  final bool savedByMe;
  final bool mine;
  final String authorNickname;
  final String authorAvatarPreset;
  final DateTime createdAt;

  factory CommunityPostData.fromJson(Map<String, dynamic> json) =>
      CommunityPostData(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'REVIEW',
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        regionName: json['regionName'] as String?,
        photos: ((json['photos'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        courseName: json['courseName'] as String?,
        courseMeta: json['courseMeta'] as String?,
        verified: json['verified'] as bool? ?? false,
        edited: json['edited'] as bool? ?? false,
        visibility: json['visibility'] as String? ?? 'PUBLIC',
        likeCount: json['likeCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        saveCount: json['saveCount'] as int? ?? 0,
        likedByMe: json['likedByMe'] as bool? ?? false,
        savedByMe: json['savedByMe'] as bool? ?? false,
        mine: json['mine'] as bool? ?? false,
        authorNickname: json['authorNickname'] as String? ?? '여행자',
        authorAvatarPreset: json['authorAvatarPreset'] as String? ?? '0:0',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

class CommunityCommentData {
  const CommunityCommentData({
    required this.id,
    required this.authorId,
    required this.parentId,
    required this.body,
    required this.authorNickname,
    required this.authorAvatarPreset,
    required this.isPostAuthor,
    required this.mine,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final int id;
  final int authorId;

  /// 인스타식 1단계 답글 — 루트 댓글 id (답글의 답글도 서버가 루트로 정규화).
  final int? parentId;
  final String body;
  final String authorNickname;
  final String authorAvatarPreset;
  final bool isPostAuthor;
  final bool mine;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory CommunityCommentData.fromJson(Map<String, dynamic> json) =>
      CommunityCommentData(
        id: json['id'] as int,
        authorId: json['authorId'] as int? ?? 0,
        parentId: json['parentId'] as int?,
        body: json['body'] as String? ?? '',
        authorNickname: json['authorNickname'] as String? ?? '여행자',
        authorAvatarPreset: json['authorAvatarPreset'] as String? ?? '0:0',
        isPostAuthor: json['isPostAuthor'] as bool? ?? false,
        mine: json['mine'] as bool? ?? false,
        likeCount: json['likeCount'] as int? ?? 0,
        likedByMe: json['likedByMe'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

class CommunityMyPosts {
  const CommunityMyPosts({
    required this.postCount,
    required this.receivedLikeCount,
    required this.receivedSaveCount,
    required this.posts,
  });

  final int postCount;
  final int receivedLikeCount;
  final int receivedSaveCount;
  final List<CommunityPostData> posts;

  factory CommunityMyPosts.fromJson(Map<String, dynamic> json) =>
      CommunityMyPosts(
        postCount: json['postCount'] as int? ?? 0,
        receivedLikeCount: json['receivedLikeCount'] as int? ?? 0,
        receivedSaveCount: json['receivedSaveCount'] as int? ?? 0,
        posts: ((json['posts'] as List<dynamic>?) ?? const [])
            .map((e) => CommunityPostData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 출발 준비 체크리스트 항목 — 계약: GET/PUT /api/trips/{tripId}/checklist (핸드오프 E, 사용자 직접 체크안).
class ChecklistItem {
  const ChecklistItem({
    required this.key,
    required this.label,
    required this.checked,
  });

  final String key;
  final String label;
  final bool checked;

  ChecklistItem copyWith({bool? checked}) =>
      ChecklistItem(key: key, label: label, checked: checked ?? this.checked);

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        // 서버는 done(자동판정+수동체크 합산)과 checked(수동)를 함께 준다 — 표시 기준은 done.
        checked: (json['done'] ?? json['checked']) as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'key': key, 'checked': checked};

  /// 서버 시드와 동일한 기본 4항목 — 백엔드 배포 전 폴백.
  static List<ChecklistItem> defaults() => const [
        ChecklistItem(key: 'currency_app', label: '지역화폐 앱 설치', checked: false),
        ChecklistItem(
            key: 'payment_method', label: '결제수단(인정 카드) 확인', checked: false),
        ChecklistItem(
            key: 'auth_guide', label: '인증사진 가이드 확인', checked: false),
        ChecklistItem(key: 'lodging', label: '숙소 예약 확인', checked: false),
      ];
}

/// 알림 유형 — 백엔드 wire enum(REGION_OPEN 등)과 매핑.
/// 계약: GET /api/notifications → [{type,title,body,createdAt,read}]
enum NotificationType {
  regionOpen,
  courseDone,
  communityLike,
  communityComment,
  settleDeadline,
  benefit,
  unknown,
}

class AppNotification {
  const AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.refType,
    this.refId,
  });

  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// 딥링크 타겟 참조(백엔드 계약: REGION·COURSE·POST·TRIP·MERCHANT).
  /// 알림 탭 시 이 값으로 관련 화면으로 이동. 백엔드 연동 전까진 mock에서만 채워짐.
  final String? refType;
  final int? refId;

  AppNotification copyWith({bool? read}) => AppNotification(
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        refType: refType,
        refId: refId,
      );

  static NotificationType typeFromWire(String? wire) =>
      switch (wire?.toUpperCase()) {
        'REGION_OPEN' => NotificationType.regionOpen,
        'COURSE_DONE' => NotificationType.courseDone,
        'COMMUNITY_LIKE' => NotificationType.communityLike,
        'COMMUNITY_COMMENT' => NotificationType.communityComment,
        'SETTLE_DEADLINE' => NotificationType.settleDeadline,
        'BENEFIT' => NotificationType.benefit,
        _ => NotificationType.unknown,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      type: typeFromWire(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      read: json['read'] as bool? ?? false,
      refType: json['refType'] as String?,
      refId: json['refId'] as int?,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.residence,
    required this.authProvider,
    required this.notificationSettings,
    required this.favoriteRegions,
    this.nickname = '',
    this.avatarPreset = '0:0',
  });

  final int id;
  final String name;
  final String email;
  final String phoneNumber;
  final String residence;
  final String authProvider;
  final NotificationSettings notificationSettings;
  final List<RegionSummary> favoriteRegions;

  /// 커뮤니티 반익명 닉네임 (화면 표시·인사말용, 실명과 분리).
  final String nickname;

  /// 아바타 프리셋 (이모지 문자). 계약: community_profiles.avatar_preset.
  final String avatarPreset;

  AppUser copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? residence,
    NotificationSettings? notificationSettings,
    List<RegionSummary>? favoriteRegions,
    String? nickname,
    String? avatarPreset,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      residence: residence ?? this.residence,
      authProvider: authProvider,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      favoriteRegions: favoriteRegions ?? this.favoriteRegions,
      nickname: nickname ?? this.nickname,
      avatarPreset: avatarPreset ?? this.avatarPreset,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      authProvider: json['authProvider'] as String? ?? 'GUEST',
      nickname: json['nickname'] as String? ?? '',
      avatarPreset: json['avatarPreset'] as String? ?? '0:0',
      notificationSettings: NotificationSettings.fromJson(
        (json['notificationSettings'] as Map<String, dynamic>?) ??
            const <String, dynamic>{
              'favoriteRegionPreopenAlert': true,
              'tripEndSettlementAlert': true,
            },
      ),
      favoriteRegions: ((json['favoriteRegions'] as List<dynamic>?) ?? [])
          .map((item) => RegionSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RegionSummary {
  const RegionSummary({
    required this.id,
    required this.name,
    required this.province,
    required this.refundConditionAmount,
    required this.mockBudgetRemaining,
    required this.halfPriceApplyUrl,
    required this.digitalTourCardApplyUrl,
    required this.dataSourceNote,
    this.statusCode = 'PREPARING',
    this.digitalBenefitAvailable = false,
    this.displayOrder = 0,
    this.mapTopPercent = 50,
    this.mapLeftPercent = 50,
    this.residenceRestrictionNote = '',
    required this.matchedByResidence,
  });

  final int id;
  final String name;
  final String province;
  final int refundConditionAmount;
  final int mockBudgetRemaining;
  final String halfPriceApplyUrl;
  final String digitalTourCardApplyUrl;
  final String dataSourceNote;
  final String statusCode;
  final bool digitalBenefitAvailable;
  final int displayOrder;
  final double mapTopPercent;
  final double mapLeftPercent;
  final String residenceRestrictionNote;
  final bool matchedByResidence;

  String get statusLabel => switch (statusCode.toUpperCase()) {
        'APPLYING' => '접수중',
        'CLOSED' => '1차 마감',
        _ => '오픈 예정',
      };

  factory RegionSummary.fromJson(Map<String, dynamic> json) {
    return RegionSummary(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      province: json['province'] as String? ?? '',
      refundConditionAmount: json['refundConditionAmount'] as int? ?? 0,
      mockBudgetRemaining: json['mockBudgetRemaining'] as int? ?? 0,
      halfPriceApplyUrl: json['halfPriceApplyUrl'] as String? ?? '',
      digitalTourCardApplyUrl: json['digitalTourCardApplyUrl'] as String? ?? '',
      dataSourceNote: json['dataSourceNote'] as String? ?? 'SAMPLE_SEED',
      statusCode: json['statusCode'] as String? ?? 'PREPARING',
      digitalBenefitAvailable:
          json['digitalBenefitAvailable'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? 0,
      mapTopPercent: (json['mapTopPercent'] as num?)?.toDouble() ?? 50,
      mapLeftPercent: (json['mapLeftPercent'] as num?)?.toDouble() ?? 50,
      residenceRestrictionNote:
          json['residenceRestrictionNote'] as String? ?? '',
      matchedByResidence: json['matchedByResidence'] as bool? ?? false,
    );
  }
}

class PlaceItem {
  const PlaceItem({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.eligibleForRefund,
  });

  final int id;
  final String name;
  final String address;
  final String description;
  final double? latitude;
  final double? longitude;
  final bool eligibleForRefund;

  factory PlaceItem.fromJson(Map<String, dynamic> json) {
    return PlaceItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      eligibleForRefund: json['eligibleForRefund'] as bool? ?? true,
    );
  }
}

class DigitalPlaceItem {
  const DigitalPlaceItem({
    required this.id,
    required this.name,
    required this.address,
    required this.discountDescription,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String address;
  final String discountDescription;
  final double? latitude;
  final double? longitude;

  factory DigitalPlaceItem.fromJson(Map<String, dynamic> json) {
    return DigitalPlaceItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      discountDescription: json['discountDescription'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class MerchantItem {
  const MerchantItem({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.kakaoPlaceName,
    required this.kakaoPhoneNumber,
    required this.kakaoRoadAddress,
    required this.kakaoCategoryName,
    required this.kakaoPlaceUrl,
  });

  final int id;
  final String name;
  final String address;
  final String category;
  final double? latitude;
  final double? longitude;
  final String kakaoPlaceName;
  final String kakaoPhoneNumber;
  final String kakaoRoadAddress;
  final String kakaoCategoryName;
  final String kakaoPlaceUrl;

  factory MerchantItem.fromJson(Map<String, dynamic> json) {
    return MerchantItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      category: json['category'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      kakaoPlaceName: json['kakaoPlaceName'] as String? ?? '',
      kakaoPhoneNumber: json['kakaoPhoneNumber'] as String? ?? '',
      kakaoRoadAddress: json['kakaoRoadAddress'] as String? ?? '',
      kakaoCategoryName: json['kakaoCategoryName'] as String? ?? '',
      kakaoPlaceUrl: json['kakaoPlaceUrl'] as String? ?? '',
    );
  }
}

class OnlineMallItem {
  const OnlineMallItem({
    required this.id,
    required this.name,
    required this.mallUrl,
    required this.description,
  });

  final int id;
  final String name;
  final String mallUrl;
  final String description;

  factory OnlineMallItem.fromJson(Map<String, dynamic> json) {
    return OnlineMallItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      mallUrl: json['mallUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class RegionDetail {
  const RegionDetail({
    required this.region,
    required this.halfPricePlaces,
    required this.digitalTourCardPlaces,
    required this.merchants,
    required this.onlineMalls,
  });

  final RegionSummary region;
  final List<PlaceItem> halfPricePlaces;
  final List<DigitalPlaceItem> digitalTourCardPlaces;
  final List<MerchantItem> merchants;
  final List<OnlineMallItem> onlineMalls;

  factory RegionDetail.fromJson(Map<String, dynamic> json) {
    return RegionDetail(
      region: RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
      halfPricePlaces: ((json['halfPricePlaces'] as List<dynamic>?) ?? [])
          .map((item) => PlaceItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      digitalTourCardPlaces:
          ((json['digitalTourCardPlaces'] as List<dynamic>?) ?? [])
              .map(
                (item) =>
                    DigitalPlaceItem.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      merchants: ((json['merchants'] as List<dynamic>?) ?? [])
          .map((item) => MerchantItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      onlineMalls: ((json['onlineMalls'] as List<dynamic>?) ?? [])
          .map((item) => OnlineMallItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlaceInfoDetail {
  const PlaceInfoDetail({
    required this.region,
    required this.halfPricePlaces,
    required this.onlineMalls,
  });

  final RegionSummary region;
  final List<PlaceItem> halfPricePlaces;
  final List<OnlineMallItem> onlineMalls;

  factory PlaceInfoDetail.fromJson(Map<String, dynamic> json) {
    return PlaceInfoDetail(
      region: RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
      halfPricePlaces: ((json['halfPricePlaces'] as List<dynamic>?) ?? [])
          .map((item) => PlaceItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      onlineMalls: ((json['onlineMalls'] as List<dynamic>?) ?? [])
          .map((item) => OnlineMallItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MerchantMapSearchResult {
  const MerchantMapSearchResult({
    required this.region,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.merchantCount,
    required this.markers,
  });

  final RegionSummary region;
  final double centerLatitude;
  final double centerLongitude;
  final int merchantCount;
  final List<MerchantMarkerItem> markers;

  factory MerchantMapSearchResult.fromJson(Map<String, dynamic> json) {
    return MerchantMapSearchResult(
      region: RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
      centerLatitude: (json['centerLatitude'] as num?)?.toDouble() ?? 0,
      centerLongitude: (json['centerLongitude'] as num?)?.toDouble() ?? 0,
      merchantCount: json['merchantCount'] as int? ?? 0,
      markers: ((json['merchants'] as List<dynamic>?) ?? const [])
          .map((item) => MerchantMarkerItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MerchantMarkerItem {
  const MerchantMarkerItem({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final double latitude;
  final double longitude;

  factory MerchantMarkerItem.fromJson(Map<String, dynamic> json) {
    return MerchantMarkerItem(
      id: json['id'] as int,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MerchantDetailItem {
  const MerchantDetailItem({
    required this.id,
    required this.storeName,
    required this.roadAddress,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.kakaoPlaceName,
    required this.kakaoPhone,
    required this.kakaoRoadAddress,
    required this.kakaoCategory,
    required this.kakaoPlaceUrl,
    required this.externalInfoAvailable,
  });

  final int id;
  final String storeName;
  final String roadAddress;
  final String category;
  final double? latitude;
  final double? longitude;
  final String kakaoPlaceName;
  final String kakaoPhone;
  final String kakaoRoadAddress;
  final String kakaoCategory;
  final String kakaoPlaceUrl;
  final bool externalInfoAvailable;

  factory MerchantDetailItem.fromJson(Map<String, dynamic> json) {
    return MerchantDetailItem(
      id: json['id'] as int,
      storeName: json['storeName'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
      category: json['category'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      kakaoPlaceName: json['kakaoPlaceName'] as String? ?? '',
      kakaoPhone: json['kakaoPhone'] as String? ?? '',
      kakaoRoadAddress: json['kakaoRoadAddress'] as String? ?? '',
      kakaoCategory: json['kakaoCategory'] as String? ?? '',
      kakaoPlaceUrl: json['kakaoPlaceUrl'] as String? ?? '',
      externalInfoAvailable: json['externalInfoAvailable'] as bool? ?? false,
    );
  }
}

class TripSummary {
  const TripSummary({
    required this.id,
    required this.regionId,
    required this.regionName,
    required this.applicantName,
    required this.startDate,
    required this.endDate,
    required this.travelerCount,
    required this.status,
    required this.totalSpentAmount,
    required this.refundConditionAmount,
    required this.settlementApplied,
    this.authCertifiedCount,
    this.authRequiredCount,
    this.checklistDoneCount,
    this.checklistTotal,
    this.settlementDeadline,
  });

  final int id;
  final int regionId;
  final String regionName;
  final String applicantName;
  final DateTime startDate;
  final DateTime endDate;
  final int travelerCount;
  final String status;
  final int totalSpentAmount;
  final int refundConditionAmount;
  final bool settlementApplied;

  /// 여행 진행 카운트(백엔드 E) — 서버 미지원 시 null.
  final int? authCertifiedCount;
  final int? authRequiredCount;
  final int? checklistDoneCount;
  final int? checklistTotal;
  final DateTime? settlementDeadline;

  TripSummary copyWith({
    int? travelerCount,
    String? status,
    int? totalSpentAmount,
    bool? settlementApplied,
  }) {
    return TripSummary(
      id: id,
      regionId: regionId,
      regionName: regionName,
      applicantName: applicantName,
      startDate: startDate,
      endDate: endDate,
      travelerCount: travelerCount ?? this.travelerCount,
      status: status ?? this.status,
      totalSpentAmount: totalSpentAmount ?? this.totalSpentAmount,
      refundConditionAmount: refundConditionAmount,
      settlementApplied: settlementApplied ?? this.settlementApplied,
      authCertifiedCount: authCertifiedCount,
      authRequiredCount: authRequiredCount,
      checklistDoneCount: checklistDoneCount,
      checklistTotal: checklistTotal,
      settlementDeadline: settlementDeadline,
    );
  }

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as int,
      regionId: json['regionId'] as int,
      regionName: json['regionName'] as String? ?? '',
      applicantName: json['applicantName'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      travelerCount: json['travelerCount'] as int? ?? 2,
      status: json['status'] as String? ?? '',
      totalSpentAmount: json['totalSpentAmount'] as int? ?? 0,
      refundConditionAmount: json['refundConditionAmount'] as int? ?? 0,
      settlementApplied: json['settlementApplied'] as bool? ?? false,
      authCertifiedCount: json['authCertifiedCount'] as int?,
      authRequiredCount: json['authRequiredCount'] as int?,
      checklistDoneCount: json['checklistDoneCount'] as int?,
      checklistTotal: json['checklistTotal'] as int?,
      settlementDeadline: json['settlementDeadline'] == null
          ? null
          : DateTime.tryParse(json['settlementDeadline'] as String),
    );
  }
}

class TripPlaceItem {
  const TripPlaceItem({
    required this.id,
    required this.placeType,
    required this.referencePlaceId,
    required this.placeName,
    required this.address,
    required this.visitOrder,
    required this.latitude,
    required this.longitude,
    required this.checked,
  });

  final int id;
  final PlaceCategory placeType;
  final int referencePlaceId;
  final String placeName;
  final String address;
  final int visitOrder;
  final double? latitude;
  final double? longitude;
  final bool checked;

  factory TripPlaceItem.fromJson(Map<String, dynamic> json) {
    return TripPlaceItem(
      id: json['id'] as int,
      placeType:
          PlaceCategoryParsing.fromWire(json['placeType'] as String? ?? ''),
      referencePlaceId: json['referencePlaceId'] as int,
      placeName: json['placeName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      visitOrder: json['visitOrder'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      checked: json['checked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toReplacementJson() => {
        'placeType': placeType.wireName,
        'referencePlaceId': referencePlaceId,
        'placeName': placeName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class UploadedFileItem {
  const UploadedFileItem({
    required this.id,
    required this.fileCategory,
    required this.originalFileName,
    required this.storagePath,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
  });

  final int id;
  final FileCategory fileCategory;
  final String originalFileName;
  final String storagePath;
  final int fileSize;
  final String mimeType;
  final DateTime createdAt;

  factory UploadedFileItem.fromJson(Map<String, dynamic> json) {
    return UploadedFileItem(
      id: json['id'] as int,
      fileCategory: switch (
          (json['fileCategory'] as String? ?? '').toUpperCase()) {
        'AUTH_PHOTO' => FileCategory.authPhoto,
        'RECEIPT_IMAGE' => FileCategory.receiptImage,
        'LODGING_CONFIRMATION' => FileCategory.lodgingConfirmation,
        'SIGNATURE' => FileCategory.signature,
        _ => FileCategory.generatedPdf,
      },
      originalFileName: json['originalFileName'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AuthPhotoReviewResult {
  const AuthPhotoReviewResult({
    required this.approved,
    required this.detectedPeopleCount,
    required this.requiredPeopleCount,
    required this.facesClear,
    required this.backgroundVisible,
    required this.reason,
    this.gpsPresent,
    this.capturedAt,
    this.locationVerified,
    this.withinTripPeriod,
  });

  final bool approved;
  final int detectedPeopleCount;
  final int requiredPeopleCount;
  final bool facesClear;
  final bool backgroundVisible;
  final String reason;

  /// EXIF 위치·시각 검증(백엔드 F) — 검증 미수행이면 null.
  final bool? gpsPresent;
  final DateTime? capturedAt;
  final bool? locationVerified;
  final bool? withinTripPeriod;

  factory AuthPhotoReviewResult.fromJson(Map<String, dynamic> json) {
    return AuthPhotoReviewResult(
      approved: json['approved'] as bool? ?? false,
      detectedPeopleCount: json['detectedPeopleCount'] as int? ?? 0,
      requiredPeopleCount: json['requiredPeopleCount'] as int? ?? 0,
      facesClear: json['facesClear'] as bool? ?? false,
      backgroundVisible: json['backgroundVisible'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      gpsPresent: json['gpsPresent'] as bool?,
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.tryParse(json['capturedAt'] as String),
      locationVerified: json['locationVerified'] as bool?,
      withinTripPeriod: json['withinTripPeriod'] as bool?,
    );
  }
}

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.uploadedFileId,
    required this.paymentType,
    required this.usageScope,
    required this.reviewStatus,
    required this.amount,
    required this.paymentDateTime,
    required this.eligibleAmount,
    required this.reviewReason,
    required this.rawText,
  });

  final int id;
  final int uploadedFileId;
  final PaymentType paymentType;
  final ReceiptUsageScope usageScope;
  final ReceiptReviewStatus reviewStatus;
  final int? amount;
  final DateTime? paymentDateTime;
  final int eligibleAmount;
  final String reviewReason;
  final String rawText;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] as int,
      uploadedFileId: json['uploadedFileId'] as int,
      paymentType:
          PaymentTypeWire.fromWire(json['paymentType'] as String? ?? ''),
      usageScope:
          ReceiptUsageScopeWire.fromWire(json['usageScope'] as String? ?? ''),
      reviewStatus: ReceiptReviewStatusWire.fromWire(
        json['reviewStatus'] as String? ?? '',
      ),
      amount: json['amount'] as int?,
      paymentDateTime: DateTime.tryParse(json['paymentDateTime'] as String? ?? ''),
      eligibleAmount: json['eligibleAmount'] as int? ?? 0,
      reviewReason: json['reviewReason'] as String? ?? '',
      rawText: json['rawText'] as String? ?? '',
    );
  }
}

class LodgingInfo {
  const LodgingInfo({
    required this.id,
    required this.lodgingName,
    required this.representativeName,
    required this.phoneNumber,
    required this.address,
    required this.signatureSvgPath,
    required this.agreedPersonalInfo,
    required this.agreedStayProof,
    required this.uploadedFileId,
  });

  final int id;
  final String lodgingName;
  final String representativeName;
  final String phoneNumber;
  final String address;
  final String signatureSvgPath;
  final bool agreedPersonalInfo;
  final bool agreedStayProof;
  final int? uploadedFileId;

  LodgingInfo copyWith({
    String? lodgingName,
    String? representativeName,
    String? phoneNumber,
    String? address,
    String? signatureSvgPath,
    bool? agreedPersonalInfo,
    bool? agreedStayProof,
    int? uploadedFileId,
  }) {
    return LodgingInfo(
      id: id,
      lodgingName: lodgingName ?? this.lodgingName,
      representativeName: representativeName ?? this.representativeName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      signatureSvgPath: signatureSvgPath ?? this.signatureSvgPath,
      agreedPersonalInfo: agreedPersonalInfo ?? this.agreedPersonalInfo,
      agreedStayProof: agreedStayProof ?? this.agreedStayProof,
      uploadedFileId: uploadedFileId ?? this.uploadedFileId,
    );
  }

  factory LodgingInfo.empty() {
    return const LodgingInfo(
      id: 0,
      lodgingName: '',
      representativeName: '',
      phoneNumber: '',
      address: '',
      signatureSvgPath: '',
      agreedPersonalInfo: false,
      agreedStayProof: false,
      uploadedFileId: null,
    );
  }

  factory LodgingInfo.fromJson(Map<String, dynamic> json) {
    return LodgingInfo(
      id: json['id'] as int? ?? 0,
      lodgingName: json['lodgingName'] as String? ?? '',
      representativeName: json['representativeName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      address: json['address'] as String? ?? '',
      signatureSvgPath: json['signatureSvgPath'] as String? ?? '',
      agreedPersonalInfo: json['agreedPersonalInfo'] as bool? ?? false,
      agreedStayProof: json['agreedStayProof'] as bool? ?? false,
      uploadedFileId: json['uploadedFileId'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'lodgingName': lodgingName,
        'representativeName': representativeName,
        'phoneNumber': phoneNumber,
        'address': address,
        'signatureSvgPath': signatureSvgPath,
        'agreedPersonalInfo': agreedPersonalInfo,
        'agreedStayProof': agreedStayProof,
        'uploadedFileId': uploadedFileId,
      };
}

class SettlementSummary {
  const SettlementSummary({
    required this.totalSpentAmount,
    required this.refundConditionAmount,
    required this.remainingAmount,
    required this.statusMessage,
  });

  final int totalSpentAmount;
  final int refundConditionAmount;
  final int remainingAmount;
  final String statusMessage;

  factory SettlementSummary.fromJson(Map<String, dynamic> json) {
    return SettlementSummary(
      totalSpentAmount: json['totalSpentAmount'] as int? ?? 0,
      refundConditionAmount: json['refundConditionAmount'] as int? ?? 0,
      remainingAmount: json['remainingAmount'] as int? ?? 0,
      statusMessage: json['statusMessage'] as String? ?? '',
    );
  }
}

class TripDetail {
  const TripDetail({
    required this.trip,
    required this.selectedPlaces,
    required this.uploadedFiles,
    required this.receipts,
    required this.lodgingInfo,
    required this.settlementSummary,
  });

  final TripSummary trip;
  final List<TripPlaceItem> selectedPlaces;
  final List<UploadedFileItem> uploadedFiles;
  final List<ReceiptItem> receipts;
  final LodgingInfo? lodgingInfo;
  final SettlementSummary settlementSummary;

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    return TripDetail(
      trip: TripSummary.fromJson(json['trip'] as Map<String, dynamic>),
      selectedPlaces: ((json['selectedPlaces'] as List<dynamic>?) ?? [])
          .map((item) => TripPlaceItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      uploadedFiles: ((json['uploadedFiles'] as List<dynamic>?) ?? [])
          .map(
            (item) => UploadedFileItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      receipts: ((json['receipts'] as List<dynamic>?) ?? [])
          .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      lodgingInfo: json['lodgingInfo'] == null
          ? null
          : LodgingInfo.fromJson(json['lodgingInfo'] as Map<String, dynamic>),
      settlementSummary: SettlementSummary.fromJson(
        json['settlementSummary'] as Map<String, dynamic>,
      ),
    );
  }
}

class LodgingFormFieldItem {
  const LodgingFormFieldItem({
    required this.key,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.editable,
    required this.multiline,
    required this.helperText,
  });

  final String key;
  final String label;
  final String type;
  // These values are interpreted as fixed coordinates on the PDF base canvas,
  // not percentages. The preview scales them onto the rendered PDF surface.
  final double x;
  final double y;
  final double width;
  final double height;
  final bool editable;
  final bool multiline;
  final String helperText;

  bool get isCheckbox => type.toLowerCase() == 'checkbox';
  bool get isSignature => type.toLowerCase() == 'signature';

  LodgingFormFieldItem copyWith({
    String? key,
    String? label,
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? editable,
    bool? multiline,
    String? helperText,
  }) {
    return LodgingFormFieldItem(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      editable: editable ?? this.editable,
      multiline: multiline ?? this.multiline,
      helperText: helperText ?? this.helperText,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'editable': editable,
        'multiline': multiline,
        'helperText': helperText,
      };

  factory LodgingFormFieldItem.fromJson(Map<String, dynamic> json) {
    return LodgingFormFieldItem(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      editable: json['editable'] as bool? ?? false,
      multiline: json['multiline'] as bool? ?? false,
      helperText: json['helperText'] as String? ?? '',
    );
  }
}

class LodgingFormTemplateItem {
  const LodgingFormTemplateItem({
    required this.templateId,
    required this.templateKey,
    required this.templateName,
    required this.sourceFormat,
    required this.previewTitle,
    required this.previewSubtitle,
    required this.fields,
    required this.notes,
  });

  final int templateId;
  final String templateKey;
  final String templateName;
  final String sourceFormat;
  final String previewTitle;
  final String previewSubtitle;
  final List<LodgingFormFieldItem> fields;
  final List<String> notes;

  LodgingFormTemplateItem copyWith({
    int? templateId,
    String? templateKey,
    String? templateName,
    String? sourceFormat,
    String? previewTitle,
    String? previewSubtitle,
    List<LodgingFormFieldItem>? fields,
    List<String>? notes,
  }) {
    return LodgingFormTemplateItem(
      templateId: templateId ?? this.templateId,
      templateKey: templateKey ?? this.templateKey,
      templateName: templateName ?? this.templateName,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      previewTitle: previewTitle ?? this.previewTitle,
      previewSubtitle: previewSubtitle ?? this.previewSubtitle,
      fields: fields ?? this.fields,
      notes: notes ?? this.notes,
    );
  }

  factory LodgingFormTemplateItem.fromJson(Map<String, dynamic> json) {
    return LodgingFormTemplateItem(
      templateId: json['templateId'] as int? ?? 0,
      templateKey: json['templateKey'] as String? ?? '',
      templateName: json['templateName'] as String? ?? '',
      sourceFormat: json['sourceFormat'] as String? ?? '',
      previewTitle: json['previewTitle'] as String? ?? '',
      previewSubtitle: json['previewSubtitle'] as String? ?? '',
      fields: ((json['fields'] as List<dynamic>?) ?? [])
          .map(
            (item) =>
                LodgingFormFieldItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      notes: ((json['notes'] as List<dynamic>?) ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class LodgingFormInstanceItem {
  const LodgingFormInstanceItem({
    required this.instanceId,
    required this.status,
    required this.payload,
    required this.lastSavedAt,
    required this.renderedPdfFileName,
  });

  final int? instanceId;
  final String status;
  final Map<String, dynamic> payload;
  final DateTime? lastSavedAt;
  final String? renderedPdfFileName;

  factory LodgingFormInstanceItem.fromJson(Map<String, dynamic> json) {
    return LodgingFormInstanceItem(
      instanceId: json['instanceId'] as int?,
      status: json['status'] as String? ?? 'DRAFT',
      payload: (json['payload'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      lastSavedAt: json['lastSavedAt'] == null
          ? null
          : DateTime.tryParse(json['lastSavedAt'] as String),
      renderedPdfFileName: json['renderedPdfFileName'] as String?,
    );
  }
}

class LodgingFormData {
  const LodgingFormData({
    required this.tripId,
    required this.regionName,
    required this.template,
    required this.instance,
    required this.todos,
  });

  final int tripId;
  final String regionName;
  final LodgingFormTemplateItem template;
  final LodgingFormInstanceItem instance;
  final List<String> todos;

  factory LodgingFormData.fromJson(Map<String, dynamic> json) {
    return LodgingFormData(
      tripId: json['tripId'] as int? ?? 0,
      regionName: json['regionName'] as String? ?? '',
      template: LodgingFormTemplateItem.fromJson(
        json['template'] as Map<String, dynamic>,
      ),
      instance: LodgingFormInstanceItem.fromJson(
        json['instance'] as Map<String, dynamic>,
      ),
      todos: ((json['todos'] as List<dynamic>?) ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  String prettyJson() =>
      const JsonEncoder.withIndent('  ').convert(instance.payload);
}

class LodgingFormSaveRequest {
  const LodgingFormSaveRequest({
    required this.payload,
    this.status = 'DRAFT',
  });

  final Map<String, dynamic> payload;
  final String status;

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'status': status,
      };
}

class TripDraft {
  const TripDraft({
    required this.applicantName,
    required this.phoneNumber,
    required this.residence,
    required this.startDate,
    required this.endDate,
    required this.travelerCount,
  });

  final String applicantName;
  final String phoneNumber;
  final String residence;
  final DateTime startDate;
  final DateTime endDate;
  final int travelerCount;
}

class SavedCourseStop {
  const SavedCourseStop({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sourceType,
  });

  final int placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String sourceType;

  factory SavedCourseStop.fromJson(Map<String, dynamic> json) {
    return SavedCourseStop(
      placeId: json['placeId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      sourceType: json['sourceType'] as String? ?? 'PLACE',
    );
  }

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'sourceType': sourceType,
      };
}

class SavedCourse {
  const SavedCourse({
    required this.id,
    required this.regionId,
    required this.regionName,
    required this.title,
    required this.preferences,
    required this.stops,
    required this.createdAt,
  });

  final String id;
  final int regionId;
  final String regionName;
  final String title;
  final List<String> preferences;
  final List<SavedCourseStop> stops;
  final DateTime createdAt;

  factory SavedCourse.fromJson(Map<String, dynamic> json) {
    return SavedCourse(
      id: json['id'] as String? ?? '',
      regionId: json['regionId'] as int? ?? 0,
      regionName: json['regionName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preferences: ((json['preferences'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      stops: ((json['stops'] as List<dynamic>?) ?? const [])
          .map((item) => SavedCourseStop.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'regionId': regionId,
        'regionName': regionName,
        'title': title,
        'preferences': preferences,
        'stops': stops.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class PendingYoutubeCourseJob {
  const PendingYoutubeCourseJob({
    required this.jobId,
    required this.tripId,
    required this.regionId,
    required this.regionName,
    required this.youtubeUrl,
    required this.createdAt,
  });

  final String jobId;
  final int tripId;
  final int regionId;
  final String regionName;
  final String youtubeUrl;
  final DateTime createdAt;

  factory PendingYoutubeCourseJob.fromJson(Map<String, dynamic> json) {
    return PendingYoutubeCourseJob(
      jobId: json['jobId'] as String? ?? '',
      tripId: json['tripId'] as int? ?? 0,
      regionId: json['regionId'] as int? ?? 0,
      regionName: json['regionName'] as String? ?? '',
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'tripId': tripId,
        'regionId': regionId,
        'regionName': regionName,
        'youtubeUrl': youtubeUrl,
        'createdAt': createdAt.toIso8601String(),
      };
}

class CreateYoutubeCourseJobResponse {
  const CreateYoutubeCourseJobResponse({
    required this.jobId,
    required this.status,
  });

  final String jobId;
  final String status;

  factory CreateYoutubeCourseJobResponse.fromJson(Map<String, dynamic> json) {
    return CreateYoutubeCourseJobResponse(
      jobId: json['jobId'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
    );
  }
}

class YoutubeCourseJobStop {
  const YoutubeCourseJobStop({
    required this.order,
    required this.placeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.phoneNumber = '',
    this.placeUrl = '',
    this.websiteUri = '',
    this.internationalPhoneNumber = '',
    this.rating,
    this.userRatingCount = 0,
    this.businessStatus = '',
    this.priceLevel = '',
    this.types = const [],
    this.openingHours = const [],
    this.editorialSummary = '',
    this.googlePlaceDetails = const {},
    required this.source,
    required this.reason,
  });

  final int order;
  final String placeName;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String phoneNumber;
  final String placeUrl;
  final String websiteUri;
  final String internationalPhoneNumber;
  final double? rating;
  final int userRatingCount;
  final String businessStatus;
  final String priceLevel;
  final List<String> types;
  final List<String> openingHours;
  final String editorialSummary;
  final Map<String, dynamic> googlePlaceDetails;
  final String source;
  final String reason;

  factory YoutubeCourseJobStop.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['googlePlaceDetails'];
    return YoutubeCourseJobStop(
      order: json['order'] as int? ?? 0,
      placeName: json['placeName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      placeUrl: json['placeUrl'] as String? ?? '',
      websiteUri: json['websiteUri'] as String? ?? '',
      internationalPhoneNumber:
          json['internationalPhoneNumber'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: json['userRatingCount'] as int? ?? 0,
      businessStatus: json['businessStatus'] as String? ?? '',
      priceLevel: json['priceLevel'] as String? ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      openingHours: ((json['openingHours'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      editorialSummary: json['editorialSummary'] as String? ?? '',
      googlePlaceDetails: rawDetails is Map<String, dynamic>
          ? rawDetails
          : const <String, dynamic>{},
      source: json['source'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class YoutubeCourseJobResult {
  const YoutubeCourseJobResult({
    required this.title,
    required this.summary,
    required this.stops,
  });

  final String title;
  final String summary;
  final List<YoutubeCourseJobStop> stops;

  factory YoutubeCourseJobResult.fromJson(Map<String, dynamic> json) {
    return YoutubeCourseJobResult(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      stops: ((json['stops'] as List<dynamic>?) ?? const [])
          .map((item) => YoutubeCourseJobStop.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GooglePlaceDetailItem {
  const GooglePlaceDetailItem({
    required this.placeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.phoneNumber,
    required this.placeUrl,
    required this.websiteUri,
    required this.internationalPhoneNumber,
    required this.rating,
    required this.userRatingCount,
    required this.businessStatus,
    required this.priceLevel,
    required this.types,
    required this.openingHours,
    required this.editorialSummary,
    required this.googlePlaceDetails,
  });

  final String placeName;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String phoneNumber;
  final String placeUrl;
  final String websiteUri;
  final String internationalPhoneNumber;
  final double? rating;
  final int userRatingCount;
  final String businessStatus;
  final String priceLevel;
  final List<String> types;
  final List<String> openingHours;
  final String editorialSummary;
  final Map<String, dynamic> googlePlaceDetails;

  factory GooglePlaceDetailItem.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['googlePlaceDetails'];
    return GooglePlaceDetailItem(
      placeName: json['placeName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      placeUrl: json['placeUrl'] as String? ?? '',
      websiteUri: json['websiteUri'] as String? ?? '',
      internationalPhoneNumber:
          json['internationalPhoneNumber'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: json['userRatingCount'] as int? ?? 0,
      businessStatus: json['businessStatus'] as String? ?? '',
      priceLevel: json['priceLevel'] as String? ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      openingHours: ((json['openingHours'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      editorialSummary: json['editorialSummary'] as String? ?? '',
      googlePlaceDetails: rawDetails is Map<String, dynamic>
          ? rawDetails
          : const <String, dynamic>{},
    );
  }
}

class YoutubeCourseJobItem {
  const YoutubeCourseJobItem({
    required this.jobId,
    required this.userId,
    required this.tripId,
    required this.regionId,
    required this.regionName,
    required this.youtubeUrl,
    required this.status,
    required this.result,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String jobId;
  final int userId;
  final int? tripId;
  final int regionId;
  final String regionName;
  final String youtubeUrl;
  final String status;
  final YoutubeCourseJobResult? result;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isProcessing => status == 'PROCESSING';
  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';

  factory YoutubeCourseJobItem.fromJson(Map<String, dynamic> json) {
    return YoutubeCourseJobItem(
      jobId: json['jobId'] as String? ?? '',
      userId: json['userId'] as int? ?? 0,
      tripId: json['tripId'] as int?,
      regionId: json['regionId'] as int? ?? 0,
      regionName: json['regionName'] as String? ?? '',
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      result: json['result'] is Map<String, dynamic>
          ? YoutubeCourseJobResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

