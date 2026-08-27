import '../../models/app_models.dart';

enum TravelCategory {
  tour,
  food,
  cafe,
  shopping,
  accommodation,
  transport,
  activity,
  rest,
  etc,
}

enum TransportType { walk, subway, bus, taxi, car, bicycle, train, etc }

enum ReservationStatus { notRequired, required, reserved, unknown }

enum FoodVerificationStatus { confirmed, estimated, unknown, notApplicable }

enum RestaurantPriceSource {
  googlePriceRange,
  googlePriceLevel,
  video,
  user,
  none,
}

enum TravelPlanSourceType { video, user }

enum TravelPlanVerificationStatus { unconfirmed, confirmed, excluded }

enum TravelPlanSaveStatus { idle, saving, saved, failed }

enum TravelPlanFilter {
  all,
  dated,
  foodAndCafe,
  foodConfirmed,
  foodNeedsReview,
  reservationRequired,
  completed,
  excluded,
}

enum TravelPlanSort {
  custom,
  dateTime,
  placeName,
  category,
  restaurantPriceLevel,
}

class TravelPlanItem {
  const TravelPlanItem({
    required this.id,
    required this.order,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.placeId,
    required this.placeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.activity,
    required this.participantCount,
    required this.transportType,
    required this.transportMinutes,
    required this.reservationStatus,
    required this.memo,
    required this.videoTimestampSeconds,
    required this.videoEndTimestampSeconds,
    required this.videoEvidenceText,
    required this.foodName,
    required this.foodDescription,
    required this.foodVerificationStatus,
    required this.menuPriceAmount,
    required this.menuPriceCurrency,
    required this.menuPriceSource,
    required this.restaurantPriceLevel,
    required this.restaurantPriceMin,
    required this.restaurantPriceMax,
    required this.restaurantPriceCurrency,
    required this.restaurantPriceSource,
    required this.sourceType,
    required this.verificationStatus,
    required this.completed,
  });

  final String id;
  final int order;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? placeId;
  final String placeName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final TravelCategory category;
  final String activity;
  final int? participantCount;
  final TransportType? transportType;
  final int? transportMinutes;
  final ReservationStatus reservationStatus;
  final String memo;
  final int? videoTimestampSeconds;
  final int? videoEndTimestampSeconds;
  final String? videoEvidenceText;
  final String? foodName;
  final String? foodDescription;
  final FoodVerificationStatus foodVerificationStatus;
  final num? menuPriceAmount;
  final String? menuPriceCurrency;
  final String menuPriceSource;
  final String? restaurantPriceLevel;
  final num? restaurantPriceMin;
  final num? restaurantPriceMax;
  final String? restaurantPriceCurrency;
  final RestaurantPriceSource restaurantPriceSource;
  final TravelPlanSourceType sourceType;
  final TravelPlanVerificationStatus verificationStatus;
  final bool completed;

  bool get isFoodPlace =>
      category == TravelCategory.food || category == TravelCategory.cafe;

  TravelPlanItem copyWith({
    String? id,
    int? order,
    Object? date = _unset,
    Object? startTime = _unset,
    Object? endTime = _unset,
    Object? placeId = _unset,
    String? placeName,
    Object? address = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    TravelCategory? category,
    String? activity,
    Object? participantCount = _unset,
    Object? transportType = _unset,
    Object? transportMinutes = _unset,
    ReservationStatus? reservationStatus,
    String? memo,
    Object? videoTimestampSeconds = _unset,
    Object? videoEndTimestampSeconds = _unset,
    Object? videoEvidenceText = _unset,
    Object? foodName = _unset,
    Object? foodDescription = _unset,
    FoodVerificationStatus? foodVerificationStatus,
    Object? menuPriceAmount = _unset,
    Object? menuPriceCurrency = _unset,
    String? menuPriceSource,
    Object? restaurantPriceLevel = _unset,
    Object? restaurantPriceMin = _unset,
    Object? restaurantPriceMax = _unset,
    Object? restaurantPriceCurrency = _unset,
    RestaurantPriceSource? restaurantPriceSource,
    TravelPlanSourceType? sourceType,
    TravelPlanVerificationStatus? verificationStatus,
    bool? completed,
  }) {
    return TravelPlanItem(
      id: id ?? this.id,
      order: order ?? this.order,
      date: date == _unset ? this.date : date as String?,
      startTime: startTime == _unset ? this.startTime : startTime as String?,
      endTime: endTime == _unset ? this.endTime : endTime as String?,
      placeId: placeId == _unset ? this.placeId : placeId as String?,
      placeName: placeName ?? this.placeName,
      address: address == _unset ? this.address : address as String?,
      latitude: latitude == _unset ? this.latitude : latitude as double?,
      longitude: longitude == _unset ? this.longitude : longitude as double?,
      category: category ?? this.category,
      activity: activity ?? this.activity,
      participantCount:
          participantCount == _unset
              ? this.participantCount
              : participantCount as int?,
      transportType:
          transportType == _unset
              ? this.transportType
              : transportType as TransportType?,
      transportMinutes:
          transportMinutes == _unset
              ? this.transportMinutes
              : transportMinutes as int?,
      reservationStatus: reservationStatus ?? this.reservationStatus,
      memo: memo ?? this.memo,
      videoTimestampSeconds:
          videoTimestampSeconds == _unset
              ? this.videoTimestampSeconds
              : videoTimestampSeconds as int?,
      videoEndTimestampSeconds:
          videoEndTimestampSeconds == _unset
              ? this.videoEndTimestampSeconds
              : videoEndTimestampSeconds as int?,
      videoEvidenceText:
          videoEvidenceText == _unset
              ? this.videoEvidenceText
              : videoEvidenceText as String?,
      foodName: foodName == _unset ? this.foodName : foodName as String?,
      foodDescription:
          foodDescription == _unset
              ? this.foodDescription
              : foodDescription as String?,
      foodVerificationStatus:
          foodVerificationStatus ?? this.foodVerificationStatus,
      menuPriceAmount:
          menuPriceAmount == _unset
              ? this.menuPriceAmount
              : menuPriceAmount as num?,
      menuPriceCurrency:
          menuPriceCurrency == _unset
              ? this.menuPriceCurrency
              : menuPriceCurrency as String?,
      menuPriceSource: menuPriceSource ?? this.menuPriceSource,
      restaurantPriceLevel:
          restaurantPriceLevel == _unset
              ? this.restaurantPriceLevel
              : restaurantPriceLevel as String?,
      restaurantPriceMin:
          restaurantPriceMin == _unset
              ? this.restaurantPriceMin
              : restaurantPriceMin as num?,
      restaurantPriceMax:
          restaurantPriceMax == _unset
              ? this.restaurantPriceMax
              : restaurantPriceMax as num?,
      restaurantPriceCurrency:
          restaurantPriceCurrency == _unset
              ? this.restaurantPriceCurrency
              : restaurantPriceCurrency as String?,
      restaurantPriceSource:
          restaurantPriceSource ?? this.restaurantPriceSource,
      sourceType: sourceType ?? this.sourceType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'placeId': placeId,
    'placeName': placeName,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'category': category.name,
    'activity': activity,
    'participantCount': participantCount,
    'transportType': transportType?.name,
    'transportMinutes': transportMinutes,
    'reservationStatus': reservationStatus.name,
    'memo': memo,
    'videoTimestampSeconds': videoTimestampSeconds,
    'videoEndTimestampSeconds': videoEndTimestampSeconds,
    'videoEvidenceText': videoEvidenceText,
    'foodName': foodName,
    'foodDescription': foodDescription,
    'foodVerificationStatus': foodVerificationStatus.name,
    'menuPriceAmount': menuPriceAmount,
    'menuPriceCurrency': menuPriceCurrency,
    'menuPriceSource': menuPriceSource,
    'restaurantPriceLevel': restaurantPriceLevel,
    'restaurantPriceMin': restaurantPriceMin,
    'restaurantPriceMax': restaurantPriceMax,
    'restaurantPriceCurrency': restaurantPriceCurrency,
    'restaurantPriceSource': restaurantPriceSource.name,
    'sourceType': sourceType.name,
    'verificationStatus': verificationStatus.name,
    'completed': completed,
  };

  factory TravelPlanItem.fromJson(Map<String, dynamic> json) {
    return TravelPlanItem(
      id: json['id'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      date: json['date'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      placeId: json['placeId'] as String?,
      placeName: json['placeName'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: enumByName(
        TravelCategory.values,
        json['category'] as String?,
        TravelCategory.etc,
      ),
      activity: json['activity'] as String? ?? '',
      participantCount: (json['participantCount'] as num?)?.toInt(),
      transportType: enumOrNull(
        TransportType.values,
        json['transportType'] as String?,
      ),
      transportMinutes: (json['transportMinutes'] as num?)?.toInt(),
      reservationStatus: enumByName(
        ReservationStatus.values,
        json['reservationStatus'] as String?,
        ReservationStatus.unknown,
      ),
      memo: json['memo'] as String? ?? '',
      videoTimestampSeconds: (json['videoTimestampSeconds'] as num?)?.toInt(),
      videoEndTimestampSeconds:
          (json['videoEndTimestampSeconds'] as num?)?.toInt(),
      videoEvidenceText: json['videoEvidenceText'] as String?,
      foodName: json['foodName'] as String?,
      foodDescription: json['foodDescription'] as String?,
      foodVerificationStatus: enumByName(
        FoodVerificationStatus.values,
        json['foodVerificationStatus'] as String?,
        FoodVerificationStatus.unknown,
      ),
      menuPriceAmount: json['menuPriceAmount'] as num?,
      menuPriceCurrency: json['menuPriceCurrency'] as String?,
      menuPriceSource: json['menuPriceSource'] as String? ?? 'NONE',
      restaurantPriceLevel: json['restaurantPriceLevel'] as String?,
      restaurantPriceMin: json['restaurantPriceMin'] as num?,
      restaurantPriceMax: json['restaurantPriceMax'] as num?,
      restaurantPriceCurrency: json['restaurantPriceCurrency'] as String?,
      restaurantPriceSource: enumByName(
        RestaurantPriceSource.values,
        json['restaurantPriceSource'] as String?,
        RestaurantPriceSource.none,
      ),
      sourceType: enumByName(
        TravelPlanSourceType.values,
        json['sourceType'] as String?,
        TravelPlanSourceType.video,
      ),
      verificationStatus: enumByName(
        TravelPlanVerificationStatus.values,
        json['verificationStatus'] as String?,
        TravelPlanVerificationStatus.unconfirmed,
      ),
      completed: json['completed'] as bool? ?? false,
    );
  }

  /// 코스함 코스(SavedCourseStop) → 계획표 행. 유튜브 job 없이 코스에서 계획표를
  /// 열 때 쓴다 — 영상 근거·메뉴 검증 같은 유튜브 전용 필드는 비워둔다.
  factory TravelPlanItem.fromCourseStop(
    SavedCourseStop stop, {
    required String docKey,
    required int order,
  }) {
    final cat = stop.category;
    final category = cat.contains('맛집') || cat.contains('식당') || cat.contains('음식')
        ? TravelCategory.food
        : cat.contains('카페')
            ? TravelCategory.cafe
            : cat.contains('숙') || cat.contains('호텔') || cat.contains('펜션')
                ? TravelCategory.accommodation
                : cat.contains('쇼핑')
                    ? TravelCategory.shopping
                    : TravelCategory.tour;
    return TravelPlanItem(
      id: '$docKey-$order',
      order: order,
      date: null,
      startTime: null,
      endTime: null,
      placeId: stop.placeId == 0 ? null : '${stop.placeId}',
      placeName: stop.name,
      address: stop.address.isEmpty ? null : stop.address,
      latitude: stop.latitude == 0 ? null : stop.latitude,
      longitude: stop.longitude == 0 ? null : stop.longitude,
      category: category,
      activity: '',
      participantCount: null,
      transportType: null,
      transportMinutes: null,
      reservationStatus: ReservationStatus.unknown,
      memo: 'DAY ${stop.day}',
      videoTimestampSeconds: null,
      videoEndTimestampSeconds: null,
      videoEvidenceText: null,
      foodName: null,
      foodDescription: null,
      foodVerificationStatus: FoodVerificationStatus.notApplicable,
      menuPriceAmount: null,
      menuPriceCurrency: null,
      menuPriceSource: 'NONE',
      restaurantPriceLevel: null,
      restaurantPriceMin: null,
      restaurantPriceMax: null,
      restaurantPriceCurrency: null,
      restaurantPriceSource: RestaurantPriceSource.none,
      sourceType: TravelPlanSourceType.user,
      verificationStatus: TravelPlanVerificationStatus.unconfirmed,
      completed: false,
    );
  }

  factory TravelPlanItem.fromYoutubeStop(
    YoutubeCourseJobStop stop, {
    required String jobId,
  }) {
    final category = categoryFromStop(stop);
    final details = stop.googlePlaceDetails;
    final placeId = stringValue(
      details['id'] ?? details['placeId'] ?? details['name'],
    );
    final priceRange = mapValue(details['priceRange']);
    final startPrice = moneyValue(priceRange?['startPrice']);
    final endPrice = moneyValue(priceRange?['endPrice']);
    final priceCurrency =
        moneyCurrency(priceRange?['startPrice']) ??
        moneyCurrency(priceRange?['endPrice']);
    final priceLevel = nullableText(
      stop.priceLevel.isNotEmpty ? stop.priceLevel : details['priceLevel'],
    );
    final isFood =
        category == TravelCategory.food || category == TravelCategory.cafe;
    final foodName = nullableText(details['foodName'] ?? details['menuName']);
    final foodDescription = nullableText(details['foodDescription']);
    final evidence = nullableText(details['videoEvidenceText'] ?? stop.reason);
    return TravelPlanItem(
      id: '$jobId-${stop.order}',
      order: stop.order,
      date: null,
      startTime: null,
      endTime: null,
      placeId: placeId,
      placeName: stop.placeName,
      address: nullableText(stop.address),
      latitude: stop.latitude == 0 ? null : stop.latitude,
      longitude: stop.longitude == 0 ? null : stop.longitude,
      category: category,
      activity: stop.reason.trim().isEmpty ? '' : stop.reason.trim(),
      participantCount: null,
      transportType: null,
      transportMinutes: null,
      reservationStatus: ReservationStatus.unknown,
      memo: '',
      videoTimestampSeconds: intValue(details['videoTimestampSeconds']),
      videoEndTimestampSeconds: intValue(details['videoEndTimestampSeconds']),
      videoEvidenceText: evidence,
      foodName: isFood ? foodName : null,
      foodDescription: isFood ? foodDescription : null,
      foodVerificationStatus:
          !isFood
              ? FoodVerificationStatus.notApplicable
              : foodName != null
              ? FoodVerificationStatus.confirmed
              : foodDescription != null
              ? FoodVerificationStatus.estimated
              : FoodVerificationStatus.unknown,
      menuPriceAmount: isFood ? numValue(details['menuPriceAmount']) : null,
      menuPriceCurrency:
          isFood ? nullableText(details['menuPriceCurrency']) : null,
      menuPriceSource:
          isFood && numValue(details['menuPriceAmount']) != null
              ? (nullableText(details['menuPriceSource']) ?? 'VIDEO')
              : 'NONE',
      restaurantPriceLevel: isFood ? priceLevel : null,
      restaurantPriceMin: isFood ? startPrice : null,
      restaurantPriceMax: isFood ? endPrice : null,
      restaurantPriceCurrency: isFood ? priceCurrency : null,
      restaurantPriceSource:
          !isFood
              ? RestaurantPriceSource.none
              : startPrice != null || endPrice != null
              ? RestaurantPriceSource.googlePriceRange
              : priceLevel != null
              ? RestaurantPriceSource.googlePriceLevel
              : RestaurantPriceSource.none,
      sourceType: TravelPlanSourceType.video,
      verificationStatus: TravelPlanVerificationStatus.unconfirmed,
      completed: false,
    );
  }
}

class TravelPlanDocument {
  const TravelPlanDocument({
    required this.jobId,
    required this.tripId,
    required this.title,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.participantCount,
    required this.youtubeUrl,
    required this.videoTitle,
    required this.items,
    required this.updatedAt,
    required this.lastExportedAt,
    required this.spreadsheetId,
    required this.spreadsheetUrl,
  });

  final String jobId;
  final int? tripId;
  final String title;
  final String city;
  final String? startDate;
  final String? endDate;
  final int? participantCount;
  final String youtubeUrl;
  final String videoTitle;
  final List<TravelPlanItem> items;
  final DateTime updatedAt;
  final DateTime? lastExportedAt;
  final String? spreadsheetId;
  final String? spreadsheetUrl;

  TravelPlanDocument copyWith({
    String? title,
    String? city,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? participantCount = _unset,
    List<TravelPlanItem>? items,
    DateTime? updatedAt,
    Object? lastExportedAt = _unset,
    Object? spreadsheetId = _unset,
    Object? spreadsheetUrl = _unset,
  }) {
    return TravelPlanDocument(
      jobId: jobId,
      tripId: tripId,
      title: title ?? this.title,
      city: city ?? this.city,
      startDate: startDate == _unset ? this.startDate : startDate as String?,
      endDate: endDate == _unset ? this.endDate : endDate as String?,
      participantCount:
          participantCount == _unset
              ? this.participantCount
              : participantCount as int?,
      youtubeUrl: youtubeUrl,
      videoTitle: videoTitle,
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
      lastExportedAt:
          lastExportedAt == _unset
              ? this.lastExportedAt
              : lastExportedAt as DateTime?,
      spreadsheetId:
          spreadsheetId == _unset
              ? this.spreadsheetId
              : spreadsheetId as String?,
      spreadsheetUrl:
          spreadsheetUrl == _unset
              ? this.spreadsheetUrl
              : spreadsheetUrl as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'tripId': tripId,
    'title': title,
    'city': city,
    'startDate': startDate,
    'endDate': endDate,
    'participantCount': participantCount,
    'youtubeUrl': youtubeUrl,
    'videoTitle': videoTitle,
    'items': items.map((item) => item.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastExportedAt': lastExportedAt?.toIso8601String(),
    'spreadsheetId': spreadsheetId,
    'spreadsheetUrl': spreadsheetUrl,
  };

  factory TravelPlanDocument.fromJson(Map<String, dynamic> json) {
    return TravelPlanDocument(
      jobId: json['jobId'] as String? ?? '',
      tripId: (json['tripId'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '',
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      participantCount: (json['participantCount'] as num?)?.toInt(),
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      videoTitle: json['videoTitle'] as String? ?? '',
      items:
          ((json['items'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(TravelPlanItem.fromJson)
              .toList(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastExportedAt: DateTime.tryParse(
        json['lastExportedAt'] as String? ?? '',
      ),
      spreadsheetId: json['spreadsheetId'] as String?,
      spreadsheetUrl: json['spreadsheetUrl'] as String?,
    );
  }
}

const Object _unset = Object();

T enumByName<T extends Enum>(List<T> values, String? value, T fallback) {
  if (value == null) return fallback;
  final normalized = value.toLowerCase();
  for (final item in values) {
    if (item.name.toLowerCase() == normalized) return item;
  }
  return fallback;
}

T? enumOrNull<T extends Enum>(List<T> values, String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.toLowerCase();
  for (final item in values) {
    if (item.name.toLowerCase() == normalized) return item;
  }
  return null;
}

TravelCategory categoryFromStop(YoutubeCourseJobStop stop) {
  final text = [stop.category, ...stop.types].join(' ').toLowerCase();
  if (text.contains('카페') || text.contains('cafe') || text.contains('coffee')) {
    return TravelCategory.cafe;
  }
  if (text.contains('식당') ||
      text.contains('음식') ||
      text.contains('restaurant') ||
      text.contains('food') ||
      text.contains('bakery')) {
    return TravelCategory.food;
  }
  if (text.contains('숙박') ||
      text.contains('hotel') ||
      text.contains('lodging')) {
    return TravelCategory.accommodation;
  }
  if (text.contains('교통') ||
      text.contains('station') ||
      text.contains('terminal') ||
      text.contains('transit')) {
    return TravelCategory.transport;
  }
  if (text.contains('쇼핑') ||
      text.contains('store') ||
      text.contains('shopping')) {
    return TravelCategory.shopping;
  }
  if (text.contains('체험') || text.contains('activity')) {
    return TravelCategory.activity;
  }
  return TravelCategory.tour;
}

String? nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? stringValue(Object? value) => nullableText(value);

int? intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? numValue(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

Map<String, dynamic>? mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

num? moneyValue(Object? raw) {
  final value = mapValue(raw);
  if (value == null) return null;
  if (!value.containsKey('units') && !value.containsKey('nanos')) return null;
  final units = numValue(value['units']) ?? 0;
  final nanos = numValue(value['nanos']) ?? 0;
  return units + (nanos / 1000000000);
}

String? moneyCurrency(Object? raw) {
  final value = mapValue(raw);
  return value == null ? null : nullableText(value['currencyCode']);
}

extension TravelCategoryLabel on TravelCategory {
  String get label => switch (this) {
    TravelCategory.tour => '관광',
    TravelCategory.food => '식당',
    TravelCategory.cafe => '카페',
    TravelCategory.shopping => '쇼핑',
    TravelCategory.accommodation => '숙박',
    TravelCategory.transport => '교통',
    TravelCategory.activity => '체험',
    TravelCategory.rest => '휴식',
    TravelCategory.etc => '기타',
  };
}

extension TransportTypeLabel on TransportType {
  String get label => switch (this) {
    TransportType.walk => '도보',
    TransportType.subway => '지하철',
    TransportType.bus => '버스',
    TransportType.taxi => '택시',
    TransportType.car => '자동차',
    TransportType.bicycle => '자전거',
    TransportType.train => '기차',
    TransportType.etc => '기타',
  };
}

extension ReservationStatusLabel on ReservationStatus {
  String get label => switch (this) {
    ReservationStatus.notRequired => '예약 불필요',
    ReservationStatus.required => '예약 필요',
    ReservationStatus.reserved => '예약 완료',
    ReservationStatus.unknown => '확인 필요',
  };
}

extension FoodVerificationStatusLabel on FoodVerificationStatus {
  String get label => switch (this) {
    FoodVerificationStatus.confirmed => '확인됨',
    FoodVerificationStatus.estimated => 'AI 추정',
    FoodVerificationStatus.unknown => '확인 필요',
    FoodVerificationStatus.notApplicable => '해당 없음',
  };
}

extension TravelPlanFilterLabel on TravelPlanFilter {
  String get label => switch (this) {
    TravelPlanFilter.all => '전체',
    TravelPlanFilter.dated => '날짜 입력',
    TravelPlanFilter.foodAndCafe => '식당 및 카페',
    TravelPlanFilter.foodConfirmed => '음식 확인 완료',
    TravelPlanFilter.foodNeedsReview => '음식 확인 필요',
    TravelPlanFilter.reservationRequired => '예약 필요',
    TravelPlanFilter.completed => '완료',
    TravelPlanFilter.excluded => '제외',
  };
}

extension TravelPlanSortLabel on TravelPlanSort {
  String get label => switch (this) {
    TravelPlanSort.custom => '사용자 지정 순서',
    TravelPlanSort.dateTime => '날짜와 시간',
    TravelPlanSort.placeName => '장소명',
    TravelPlanSort.category => '일정 유형',
    TravelPlanSort.restaurantPriceLevel => '식당 가격 수준',
  };
}
