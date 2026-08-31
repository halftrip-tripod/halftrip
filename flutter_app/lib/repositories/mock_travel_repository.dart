import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';
import '../utils/profile_presets.dart';
import 'travel_repository.dart';

class MockTravelRepository implements TravelRepository {
  MockTravelRepository() {
    _seed();
  }

  @override
  String get modeName => 'Mock Mode';

  @override
  void clearSession() {
    // mock 모드는 서버 토큰을 들고 있지 않아 버릴 것이 없다.
  }

  @override
  String? get authToken => null;

  @override
  Future<SocialLoginResult> socialLogin({
    required LoginProvider provider,
    required String accessToken,
  }) async {
    final user = await mockLogin(provider);
    return SocialLoginResult(user: user, newUser: false, needsResidence: false);
  }

  late AppUser _user;
  String _localLoginId = 'sample';
  String _localPassword = '1234';
  final Map<int, RegionDetail> _regionDetails = {};
  final Map<int, TripSummary> _trips = {};
  final Map<int, List<TripPlaceItem>> _tripPlaces = {};
  final Map<int, List<UploadedFileItem>> _tripFiles = {};
  final Map<int, List<ReceiptItem>> _tripReceipts = {};
  final Map<int, LodgingInfo> _tripLodging = {};
  final Map<int, List<int>> _uploadedFileBytesById = {};
  final Map<String, YoutubeCourseJobItem> _youtubeJobs = {};
  late List<AppNotification> _notifications = _seedNotifications();
  int _nextTripId = 10;
  int _nextTripPlaceId = 100;
  int _nextUploadedFileId = 1000;
  int _nextReceiptId = 2000;

  void _seed() {
    final wando = RegionDetail(
      region: const RegionSummary(
        id: 1,
        name: '완도',
        province: '전라남도',
        refundConditionAmount: 200000,
        mockBudgetRemaining: 61,
        halfPriceApplyUrl: 'https://www.wandotrip.kr/bbs/apply_date.php',
        digitalTourCardApplyUrl: 'https://www.wandotrip.kr/bbs/apply_date.php',
        dataSourceNote: 'SAMPLE_SEED',
        statusCode: 'APPLYING',
        digitalBenefitAvailable: true,
        displayOrder: 1,
        mapTopPercent: 92,
        mapLeftPercent: 55,
        residenceRestrictionNote: 'sample adjacency rule',
        matchedByResidence: true,
      ),
      halfPricePlaces: const [
        PlaceItem(
          id: 1001,
          name: '완도해양치유센터',
          address: '전라남도 완도군 완도읍 장보고대로 335',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3100,
          longitude: 126.7470,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1002,
          name: '완도타워',
          address: '전라남도 완도군 완도읍 장보고대로 330',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3240,
          longitude: 126.7400,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1003,
          name: '완도청해진유적지',
          address: '전라남도 완도군 완도읍 청해진로 1455',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3380,
          longitude: 126.7180,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1004,
          name: '국립완도난대수목원',
          address: '전라남도 완도군 군외면 초평1길 156',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3520,
          longitude: 126.7080,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1005,
          name: '보길도 윤선도 원림',
          address: '전라남도 완도군 보길면 부황길 57',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3680,
          longitude: 126.7000,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1006,
          name: '슬로시티 청산도',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.1836,
          longitude: 126.8664,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1007,
          name: '청해포구 촬영장',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3595,
          longitude: 126.7261,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1008,
          name: '신지명사십리 해수욕장',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3341,
          longitude: 126.8014,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1009,
          name: '금당 8경',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.46,
          longitude: 127.09,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1010,
          name: '어촌민속전시관',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.326,
          longitude: 126.755,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1011,
          name: '해양생태전시관',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.329,
          longitude: 126.759,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1012,
          name: '장보고 기념관',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.3672,
          longitude: 126.7565,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1013,
          name: '스마트치유센터',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.312,
          longitude: 126.75,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1014,
          name: '충무사',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.399,
          longitude: 126.802,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1015,
          name: '완도이순신기념관',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.396,
          longitude: 126.804,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
        PlaceItem(
          id: 1016,
          name: '약산해안치유의 숲',
          address: '상세주소 확인 예정',
          description: '완도반값여행 대상 관광지. TODO: Kakao Places API로 주소/좌표 검증 후 저장.',
          latitude: 34.405,
          longitude: 126.885,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
      ],
      digitalTourCardPlaces: const [
        DigitalPlaceItem(
          id: 101,
          name: '완도 로컬카페',
          address: '전라남도 완도군 바다로 8',
          discountDescription: '디지털 관광주민증 할인 샘플',
          latitude: 34.3172,
          longitude: 126.7574,
        ),
      ],
      merchants: const [
        MerchantItem(
          id: 1,
          name: '완도 특산품 상회',
          address: '전라남도 완도군 시장길 5',
          category: '오프라인 가맹점',
          latitude: 34.3132,
          longitude: 126.7581,
          kakaoPlaceName: '완도 특산품 상회',
          kakaoPhoneNumber: '061-555-1111',
          kakaoRoadAddress: '전라남도 완도군 시장길 5',
          kakaoCategoryName: '기념품점',
          kakaoPlaceUrl: 'https://place.map.kakao.com/',
        ),
      ],
      onlineMalls: const [
        OnlineMallItem(
          id: 1,
          name: '완도 온라인몰',
          mallUrl: 'https://example.com/wando',
          description: '특산물 온라인몰 샘플',
        ),
      ],
    );

    final gangjin = RegionDetail(
      region: const RegionSummary(
        id: 2,
        name: '강진',
        province: '전라남도',
        refundConditionAmount: 180000,
        mockBudgetRemaining: 34,
        halfPriceApplyUrl:
            'https://www.gangjintour.com/advance/advance_req.html?',
        digitalTourCardApplyUrl:
            'https://www.gangjintour.com/advance/advance_req.html?',
        dataSourceNote: 'SAMPLE_SEED',
        statusCode: 'APPLYING',
        digitalBenefitAvailable: true,
        displayOrder: 2,
        mapTopPercent: 86,
        mapLeftPercent: 25,
        residenceRestrictionNote: 'sample adjacency rule',
        matchedByResidence: true,
      ),
      halfPricePlaces: const [
        PlaceItem(
          id: 2,
          name: '강진만 생태공원',
          address: '전라남도 강진군 강진만길 20',
          description: '반값여행 인정 관광지 샘플',
          latitude: 34.6445,
          longitude: 126.7782,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
      ],
      digitalTourCardPlaces: const [
        DigitalPlaceItem(
          id: 102,
          name: '강진 청자마을 상점',
          address: '전라남도 강진군 청자로 18',
          discountDescription: '디지털 관광주민증 할인 샘플',
          latitude: 34.64,
          longitude: 126.772,
        ),
      ],
      merchants: const [
        MerchantItem(
          id: 2,
          name: '강진 로컬브랜드 마켓',
          address: '전라남도 강진군 읍내로 3',
          category: '오프라인 가맹점',
          latitude: 34.6421,
          longitude: 126.7672,
          kakaoPlaceName: '강진 로컬브랜드 마켓',
          kakaoPhoneNumber: '061-555-2222',
          kakaoRoadAddress: '전라남도 강진군 읍내로 3',
          kakaoCategoryName: '상점',
          kakaoPlaceUrl: 'https://place.map.kakao.com/',
        ),
      ],
      onlineMalls: const [
        OnlineMallItem(
          id: 2,
          name: '강진 온라인몰',
          mallUrl: 'https://example.com/gangjin',
          description: '특산물 온라인몰 샘플',
        ),
      ],
    );

    final pyeongchang = RegionDetail(
      region: const RegionSummary(
        id: 3,
        name: '평창',
        province: '강원특별자치도',
        refundConditionAmount: 220000,
        mockBudgetRemaining: 72,
        halfPriceApplyUrl: 'https://tour.pc.go.kr/Home/index',
        digitalTourCardApplyUrl: 'https://tour.pc.go.kr/Home/index',
        dataSourceNote: 'SAMPLE_SEED',
        statusCode: 'APPLYING',
        digitalBenefitAvailable: true,
        displayOrder: 3,
        mapTopPercent: 13,
        mapLeftPercent: 70,
        residenceRestrictionNote: 'sample adjacency rule',
        matchedByResidence: true,
      ),
      halfPricePlaces: const [
        PlaceItem(
          id: 3,
          name: '평창 로컬투어 라운지',
          address: '강원특별자치도 평창군 관광로 7',
          description: '반값여행 인정 관광지 샘플',
          latitude: 37.3705,
          longitude: 128.3902,
          eligibleForRefund: true,
          openingHours: null,
          admissionFee: null,
          phone: null,
          paymentMethods: [],
          digitalDiscountText: null,
        ),
      ],
      digitalTourCardPlaces: const [
        DigitalPlaceItem(
          id: 103,
          name: '평창 체험센터',
          address: '강원특별자치도 평창군 체험길 14',
          discountDescription: '디지털 관광주민증 할인 샘플',
          latitude: 37.3602,
          longitude: 128.4002,
        ),
      ],
      merchants: const [
        MerchantItem(
          id: 3,
          name: '평창 여행상점',
          address: '강원특별자치도 평창군 관광로 2',
          category: '오프라인 가맹점',
          latitude: 37.3705,
          longitude: 128.3902,
          kakaoPlaceName: '평창 여행상점',
          kakaoPhoneNumber: '033-555-3333',
          kakaoRoadAddress: '강원특별자치도 평창군 관광로 2',
          kakaoCategoryName: '상점',
          kakaoPlaceUrl: 'https://place.map.kakao.com/',
        ),
      ],
      onlineMalls: const [
        OnlineMallItem(
          id: 3,
          name: '평창 온라인몰',
          mallUrl: 'https://example.com/pyeongchang',
          description: '특산물 온라인몰 샘플',
        ),
      ],
    );

    _regionDetails[1] = wando;
    _regionDetails[2] = gangjin;
    _regionDetails[3] = pyeongchang;

    // 홈 지도·온라인몰 데모용 추가 지역 (목업 전용 가짜 데이터 — 실서버와 무관).
    RegionDetail simpleRegion({
      required int id,
      required String name,
      required String province,
      required String statusCode,
      required double top,
      required double left,
      required int refundAmount,
      required String mallName,
    }) {
      return RegionDetail(
        region: RegionSummary(
          id: id,
          name: name,
          province: province,
          refundConditionAmount: refundAmount,
          mockBudgetRemaining: 50,
          halfPriceApplyUrl: 'https://example.com/apply',
          digitalTourCardApplyUrl: 'https://example.com/apply',
          dataSourceNote: 'SAMPLE_SEED',
          statusCode: statusCode,
          digitalBenefitAvailable: true,
          displayOrder: id,
          mapTopPercent: top,
          mapLeftPercent: left,
          residenceRestrictionNote: 'sample adjacency rule',
          matchedByResidence: true,
        ),
        halfPricePlaces: [
          PlaceItem(
            id: id * 1000,
            name: '$name 대표 관광지',
            address: '$province $name 관광로 1',
            description: '반값여행 인정 관광지 샘플',
            latitude: null,
            longitude: null,
            eligibleForRefund: true,
            openingHours: null,
            admissionFee: null,
            phone: null,
            paymentMethods: [],
            digitalDiscountText: null,
          ),
        ],
        digitalTourCardPlaces: const [],
        merchants: const [],
        onlineMalls: [
          OnlineMallItem(
            id: id,
            name: mallName,
            mallUrl: 'https://example.com/mall$id',
            description: '$name 특산물 온라인몰',
          ),
        ],
      );
    }

    final extraRegions = [
      simpleRegion(id: 4, name: '영월', province: '강원특별자치도', statusCode: 'PREPARING', top: 28, left: 77, refundAmount: 200000, mallName: '영월몰'),
      simpleRegion(id: 5, name: '하동', province: '경상남도', statusCode: 'APPLYING', top: 68, left: 62, refundAmount: 200000, mallName: '하동녹차몰'),
      simpleRegion(id: 6, name: '제천', province: '충청북도', statusCode: 'APPLYING', top: 33, left: 57, refundAmount: 180000, mallName: '제천몰'),
      simpleRegion(id: 7, name: '고창', province: '전라북도', statusCode: 'PREPARING', top: 60, left: 28, refundAmount: 200000, mallName: '고창황토배기몰'),
      simpleRegion(id: 8, name: '영광', province: '전라남도', statusCode: 'APPLYING', top: 52, left: 22, refundAmount: 250000, mallName: '영광굴비몰'),
      simpleRegion(id: 9, name: '거창', province: '경상남도', statusCode: 'PREPARING', top: 62, left: 56, refundAmount: 200000, mallName: '거창몰'),
    ];
    for (final extra in extraRegions) {
      _regionDetails[extra.region.id] = extra;
    }

    _user = AppUser(
      id: 1,
      name: '샘플 사용자',
      email: 'sample@travel-mvp.local',
      phoneNumber: '010-1234-5678',
      residence: '서울특별시 강남구',
      authProvider: 'GUEST',
      nickname: randomNickname(),
      avatarPreset: randomAvatar(),
      notificationSettings: const NotificationSettings(
        favoriteRegionPreopenAlert: true,
        tripEndSettlementAlert: true,
      ),
      favoriteRegions: [wando.region, gangjin.region],
    );

    _trips[1] = TripSummary(
      id: 1,
      regionId: 1,
      regionName: wando.region.name,
      applicantName: _user.name,
      startDate: DateTime(2026, 4, 20),
      endDate: DateTime(2026, 4, 26),
      travelerCount: 2,
      status: '여행중',
      totalSpentAmount: 120000,
      refundConditionAmount: wando.region.refundConditionAmount,
      settlementApplied: false,
    );
    _tripPlaces[1] = [
      const TripPlaceItem(
        id: 1,
        placeType: PlaceCategory.halfPrice,
        referencePlaceId: 1001,
        placeName: '완도해양치유센터',
        address: '상세주소 확인 예정',
        visitOrder: 1,
        latitude: null,
        longitude: null,
        checked: true,
      ),
      const TripPlaceItem(
        id: 2,
        placeType: PlaceCategory.digitalTourCard,
        referencePlaceId: 101,
        placeName: '완도 로컬카페',
        address: '전라남도 완도군 바다로 8',
        visitOrder: 2,
        latitude: 34.3172,
        longitude: 126.7574,
        checked: true,
      ),
    ];
    // 스토어 데모용 증빙 채움 (목업 전용): 인증샷 2장 + 숙박확인서 + 영수증 12만원.
    _tripFiles[1] = <UploadedFileItem>[
      UploadedFileItem(
        id: 9001,
        fileCategory: FileCategory.authPhoto,
        originalFileName: 'wando_auth_1.jpg',
        storagePath: 'mock/wando_auth_1.jpg',
        fileSize: 812345,
        mimeType: 'image/jpeg',
        createdAt: DateTime(2026, 4, 21, 11, 20),
      ),
      UploadedFileItem(
        id: 9003,
        fileCategory: FileCategory.lodgingConfirmation,
        originalFileName: 'wando_lodging_form.pdf',
        storagePath: 'mock/wando_lodging_form.pdf',
        fileSize: 182034,
        mimeType: 'application/pdf',
        createdAt: DateTime(2026, 4, 22, 18, 5),
      ),
    ];
    _tripReceipts[1] = <ReceiptItem>[
      ReceiptItem(
        id: 8001,
        uploadedFileId: 9101,
        paymentType: PaymentType.creditCard,
        usageScope: ReceiptUsageScope.lodging,
        reviewStatus: ReceiptReviewStatus.approved,
        amount: 80000,
        paymentDateTime: DateTime(2026, 4, 21, 15, 2),
        eligibleAmount: 80000,
        reviewReason: '',
        rawText: '청산도 한옥스테이 80,000원',
      ),
      ReceiptItem(
        id: 8002,
        uploadedFileId: 9102,
        paymentType: PaymentType.creditCard,
        usageScope: ReceiptUsageScope.general,
        reviewStatus: ReceiptReviewStatus.approved,
        amount: 40000,
        paymentDateTime: DateTime(2026, 4, 21, 19, 30),
        eligibleAmount: 40000,
        reviewReason: '',
        rawText: '완도 전복의집 40,000원',
      ),
    ];
    _tripLodging[1] = const LodgingInfo(
      id: 1,
      lodgingName: '청산도 한옥스테이',
      representativeName: '김완도',
      phoneNumber: '061-552-1234',
      address: '전라남도 완도군 청산면 슬로시티길 12',
      signatureSvgPath: '[{"x":20,"y":60},{"x":46,"y":30},null]',
      agreedPersonalInfo: true,
      agreedStayProof: true,
      uploadedFileId: 9003,
    );

    _trips[2] = TripSummary(
      id: 2,
      regionId: 2,
      regionName: gangjin.region.name,
      applicantName: _user.name,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 5),
      travelerCount: 2,
      status: '정산 신청 완료',
      totalSpentAmount: 180000,
      refundConditionAmount: gangjin.region.refundConditionAmount,
      settlementApplied: true,
    );
    _tripPlaces[2] = <TripPlaceItem>[];
    _tripFiles[2] = <UploadedFileItem>[];
    _tripReceipts[2] = <ReceiptItem>[];

    // 온라인몰 '내 환급금 사용처' 데모용 정산 완료 여행 (목업 전용).
    _trips[3] = TripSummary(
      id: 3,
      regionId: 3,
      regionName: pyeongchang.region.name,
      applicantName: _user.name,
      startDate: DateTime(2026, 3, 14),
      endDate: DateTime(2026, 3, 15),
      travelerCount: 2,
      status: '정산 신청 완료',
      totalSpentAmount: 240000,
      refundConditionAmount: pyeongchang.region.refundConditionAmount,
      settlementApplied: true,
    );
    _tripPlaces[3] = <TripPlaceItem>[];
    _tripFiles[3] = <UploadedFileItem>[];
    _tripReceipts[3] = <ReceiptItem>[];

    _trips[4] = TripSummary(
      id: 4,
      regionId: 6,
      regionName: '제천',
      applicantName: _user.name,
      startDate: DateTime(2026, 2, 21),
      endDate: DateTime(2026, 2, 22),
      travelerCount: 4,
      status: '정산 신청 완료',
      totalSpentAmount: 310000,
      refundConditionAmount: 180000,
      settlementApplied: true,
    );
    _tripPlaces[4] = <TripPlaceItem>[];
    _tripFiles[4] = <UploadedFileItem>[];
    _tripReceipts[4] = <ReceiptItem>[];
  }

  @override
  Future<AppUser> mockLogin(LoginProvider provider) async => _user;

  @override
  Future<AppUser> localLogin({
    required String loginId,
    required String password,
  }) async {
    if (loginId.trim() != _localLoginId || password.trim() != _localPassword) {
      throw Exception('아이디 또는 비밀번호가 올바르지 않습니다.');
    }
    return _user;
  }

  @override
  Future<AppUser> localSignUp({
    required String loginId,
    required String password,
    required String residence,
  }) async {
    _localLoginId = loginId.trim();
    _localPassword = password.trim();
    _user = _user.copyWith(residence: residence.trim());
    return _user;
  }

  @override
  Future<AppUser> getUser(int userId) async => _user;

  @override
  Future<void> deleteAccount(int userId) async {}

  @override
  Future<AppUser> updateResidence(int userId, String residence) async {
    _user = _user.copyWith(residence: residence);
    return _user;
  }

  @override
  Future<AppUser> updateProfile(
    int userId, {
    String? nickname,
    String? avatarPreset,
  }) async {
    _user = _user.copyWith(
      nickname: nickname,
      avatarPreset: avatarPreset,
    );
    return _user;
  }

  @override
  Future<List<TripSummary>> getTrips(int userId) async {
    final trips = _trips.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return trips;
  }

  @override
  Future<TripDetail> getTripDetail(int tripId) async {
    final trip = _requireTrip(tripId);
    return TripDetail(
      trip: trip,
      selectedPlaces:
          List.unmodifiable(_tripPlaces[tripId] ?? const <TripPlaceItem>[]),
      uploadedFiles:
          List.unmodifiable(_tripFiles[tripId] ?? const <UploadedFileItem>[]),
      receipts:
          List.unmodifiable(_tripReceipts[tripId] ?? const <ReceiptItem>[]),
      lodgingInfo: _tripLodging[tripId],
      settlementSummary: _buildSettlementSummary(trip),
    );
  }

  @override
  Future<List<RegionSummary>> getRegions({String? residence}) async {
    final normalizedResidence = (residence ?? '').trim();
    final regions = _regionDetails.values
        .map((item) {
          // 목업: 데모용으로 전 지역 노출 (실서버가 거주지 인접 제외를 계산).
          const matched = true;
          return RegionSummary(
            id: item.region.id,
            name: item.region.name,
            province: item.region.province,
            refundConditionAmount: item.region.refundConditionAmount,
            mockBudgetRemaining: item.region.mockBudgetRemaining,
            halfPriceApplyUrl: item.region.halfPriceApplyUrl,
            digitalTourCardApplyUrl: item.region.digitalTourCardApplyUrl,
            dataSourceNote: item.region.dataSourceNote,
            statusCode: item.region.statusCode,
            digitalBenefitAvailable: item.region.digitalBenefitAvailable,
            displayOrder: item.region.displayOrder,
            mapTopPercent: item.region.mapTopPercent,
            mapLeftPercent: item.region.mapLeftPercent,
            residenceRestrictionNote: item.region.residenceRestrictionNote,
            matchedByResidence: matched,
          );
        })
        .where((item) => normalizedResidence.isEmpty || item.matchedByResidence)
        .toList();
    return regions;
  }

  @override
  Future<RegionDetail> getRegionDetail(
    int regionId, {
    String? residence,
    bool includeMerchants = true,
  }) async {
    final detail = _regionDetails[regionId];
    if (detail == null) {
      throw Exception('지역 정보를 찾을 수 없습니다.');
    }
    final matched = residence == null || residence.isEmpty
        ? detail.region.matchedByResidence
        : detail.region.province.contains(residence) ||
            residence.contains(detail.region.province);
    return RegionDetail(
      region: RegionSummary(
        id: detail.region.id,
        name: detail.region.name,
        province: detail.region.province,
        refundConditionAmount: detail.region.refundConditionAmount,
        mockBudgetRemaining: detail.region.mockBudgetRemaining,
        halfPriceApplyUrl: detail.region.halfPriceApplyUrl,
        digitalTourCardApplyUrl: detail.region.digitalTourCardApplyUrl,
        dataSourceNote: detail.region.dataSourceNote,
        statusCode: detail.region.statusCode,
        digitalBenefitAvailable: detail.region.digitalBenefitAvailable,
        displayOrder: detail.region.displayOrder,
        mapTopPercent: detail.region.mapTopPercent,
        mapLeftPercent: detail.region.mapLeftPercent,
        residenceRestrictionNote: detail.region.residenceRestrictionNote,
        matchedByResidence: matched,
      ),
      halfPricePlaces: detail.halfPricePlaces,
      digitalTourCardPlaces: detail.digitalTourCardPlaces,
      merchants: includeMerchants ? detail.merchants : const [],
      onlineMalls: detail.onlineMalls,
    );
  }

  @override
  Future<PlaceInfoDetail> getPlaceInfoDetail(
    int regionId, {
    String? residence,
  }) async {
    final detail = await getRegionDetail(
      regionId,
      residence: residence,
      includeMerchants: false,
    );
    return PlaceInfoDetail(
      region: detail.region,
      halfPricePlaces: detail.halfPricePlaces,
      onlineMalls: detail.onlineMalls,
    );
  }

  @override
  Future<List<RegionFestival>> getRegionFestivals(int regionId) async => const [];

  @override
  Future<List<TourAttraction>> getRegionAttractions(int regionId,
          {String? type, String? keyword}) async =>
      const [];

  @override
  Future<TourPlaceDetail?> getTourPlaceDetail(String contentId,
          {int contentTypeId = 12}) async =>
      null;

  @override
  Future<MerchantMapSearchResult> getMerchantMap({
    required int regionId,
    double? southLat,
    double? northLat,
    double? westLng,
    double? eastLng,
  }) async {
    final detail = _regionDetails[regionId];
    if (detail == null) {
      throw Exception('지역 정보를 찾을 수 없습니다.');
    }
    final merchants = detail.merchants
        .where((item) => item.latitude != null && item.longitude != null)
        .where((item) {
          final lat = item.latitude!;
          final lng = item.longitude!;
          final inLat = southLat == null || northLat == null
              ? true
              : lat >= southLat && lat <= northLat;
          final inLng = westLng == null || eastLng == null
              ? true
              : lng >= westLng && lng <= eastLng;
          return inLat && inLng;
        })
        .toList();
    return MerchantMapSearchResult(
      region: detail.region,
      centerLatitude: detail.region.id == 1
          ? 34.3119
          : (merchants.isEmpty ? 0 : (merchants.first.latitude ?? 0)),
      centerLongitude: detail.region.id == 1
          ? 126.7551
          : (merchants.isEmpty ? 0 : (merchants.first.longitude ?? 0)),
      merchantCount: merchants.length,
      markers: merchants
          .map((item) => MerchantMarkerItem(
                id: item.id,
                latitude: item.latitude ?? 0,
                longitude: item.longitude ?? 0,
              ))
          .toList(),
    );
  }

  @override
  Future<MerchantDetailItem> getMerchantDetail({
    required int regionId,
    required int merchantId,
  }) async {
    final detail = _regionDetails[regionId];
    if (detail == null) {
      throw Exception('지역 정보를 찾을 수 없습니다.');
    }
    final merchant = detail.merchants.firstWhere(
      (item) => item.id == merchantId,
      orElse: () => throw Exception('가맹점 정보를 찾을 수 없습니다.'),
    );
    return MerchantDetailItem(
      id: merchant.id,
      storeName: merchant.name,
      roadAddress: merchant.address,
      category: merchant.category,
      latitude: merchant.latitude,
      longitude: merchant.longitude,
      kakaoPlaceName: merchant.kakaoPlaceName,
      kakaoPhone: merchant.kakaoPhoneNumber,
      kakaoRoadAddress: merchant.kakaoRoadAddress,
      kakaoCategory: merchant.kakaoCategoryName,
      kakaoPlaceUrl: merchant.kakaoPlaceUrl,
      externalInfoAvailable: merchant.kakaoPlaceName.isNotEmpty,
    );
  }

  @override
  Future<List<SavedCourse>> getSavedCourses(int userId) async => const [];

  @override
  Future<SavedCourse> saveCourseToServer({
    required int userId,
    required SavedCourse course,
  }) async => course;

  @override
  Future<void> deleteSavedCourseOnServer({
    required int userId,
    required String courseId,
  }) async {}

  @override
  Future<void> updateTripSelectedCourse({
    required int tripId,
    required int userId,
    required int? courseId,
  }) async {}

  @override
  Future<TripSummary> createTrip({
    required int userId,
    required TripDraft draft,
    required int regionId,
  }) async {
    final region = _regionDetails[regionId]?.region;
    if (region == null) {
      throw Exception('선택한 지역 정보를 찾을 수 없습니다.');
    }
    final trip = TripSummary(
      id: _nextTripId++,
      regionId: region.id,
      regionName: region.name,
      applicantName: draft.applicantName,
      startDate: draft.startDate,
      endDate: draft.endDate,
      travelerCount: draft.travelerCount,
      status: '여행중',
      totalSpentAmount: 0,
      refundConditionAmount: region.refundConditionAmount,
      settlementApplied: false,
    );
    _trips[trip.id] = trip;
    _tripPlaces[trip.id] = [];
    _tripFiles[trip.id] = [];
    _tripReceipts[trip.id] = [];
    return trip;
  }

  @override
  Future<CreateYoutubeCourseJobResponse> createYoutubeCourseJob({
    required int userId,
    int? tripId,
    required int regionId,
    required String youtubeUrl,
  }) async {
    final detail = _regionDetails[regionId];
    if (detail == null) {
      throw Exception('지역 정보를 찾을 수 없습니다.');
    }
    final jobId = 'mock-job-${DateTime.now().millisecondsSinceEpoch}';
    final stops = detail.halfPricePlaces
        .where((item) => item.latitude != null && item.longitude != null)
        .take(5)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => YoutubeCourseJobStop(
            order: entry.key + 1,
            placeName: entry.value.name,
            address: entry.value.address,
            latitude: entry.value.latitude ?? 0,
            longitude: entry.value.longitude ?? 0,
            category: '관광지',
            phoneNumber: '',
            placeUrl: '',
            websiteUri: '',
            internationalPhoneNumber: '',
            rating: null,
            userRatingCount: 0,
            businessStatus: '',
            priceLevel: '',
            types: const [],
            openingHours: const [],
            editorialSummary: '',
            googlePlaceDetails: const {},
            source: 'youtube_mock',
            reason: 'Mock 유튜브 분석 결과',
          ),
        )
        .toList();
    _youtubeJobs[jobId] = YoutubeCourseJobItem(
      jobId: jobId,
      userId: userId,
      tripId: tripId,
      regionId: regionId,
      regionName: detail.region.name,
      youtubeUrl: youtubeUrl,
      status: 'COMPLETED',
      result: YoutubeCourseJobResult(
        title: '${detail.region.name} 유튜브 추천 코스',
        summary: 'Mock 유튜브 분석 결과입니다.',
        stops: stops,
      ),
      errorMessage: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return CreateYoutubeCourseJobResponse(jobId: jobId, status: 'PENDING');
  }

  @override
  Future<YoutubeCourseJobItem> getYoutubeCourseJob(String jobId) async {
    final job = _youtubeJobs[jobId];
    if (job == null) {
      throw Exception('유튜브 코스 작업을 찾을 수 없습니다.');
    }
    return job;
  }

  @override
  Future<YoutubeCourseJobItem?> getActiveYoutubeCourseJob({
    required int userId,
    required int tripId,
  }) async {
    final jobs = _youtubeJobs.values
        .where((job) => job.userId == userId && job.tripId == tripId)
        .where((job) => job.status == 'PENDING' || job.status == 'PROCESSING')
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return jobs.isEmpty ? null : jobs.first;
  }

  @override
  Future<GooglePlaceDetailItem?> searchGooglePlaceDetail({
    required String placeName,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    return null;
  }

  @override
  Future<void> registerFcmToken({
    required int userId,
    required String fcmToken,
    required String platform,
  }) async {
    return;
  }

  @override
  Future<List<TripPlaceItem>> replaceTripPlaces(
    int tripId,
    List<TripPlaceItem> places,
  ) async {
    final existing = List<TripPlaceItem>.from(
      _tripPlaces[tripId] ?? const <TripPlaceItem>[],
    );
    final replaced = <TripPlaceItem>[];
    for (var index = 0; index < places.length; index++) {
      final item = places[index];
      final matched = existing.cast<TripPlaceItem?>().firstWhere(
            (candidate) =>
                candidate?.placeType == item.placeType &&
                candidate?.referencePlaceId == item.referencePlaceId,
            orElse: () => null,
          );
      replaced.add(
        TripPlaceItem(
          id: matched?.id ?? _nextTripPlaceId++,
          placeType: item.placeType,
          referencePlaceId: item.referencePlaceId,
          placeName: item.placeName,
          address: item.address,
          visitOrder: index + 1,
          latitude: item.latitude,
          longitude: item.longitude,
          checked: true,
        ),
      );
    }
    _tripPlaces[tripId] = replaced;
    return List.unmodifiable(replaced);
  }

  @override
  Future<UploadedFileItem> uploadFile({
    required int tripId,
    required FileCategory category,
    required UploadBinary file,
  }) async {
    final items = [...?_tripFiles[tripId]];
    final uploadedFile = UploadedFileItem(
      id: _nextUploadedFileId++,
      fileCategory: category,
      originalFileName: file.fileName,
      storagePath: 'memory://${file.fileName}',
      fileSize: file.bytes.length,
      mimeType: file.mimeType ?? _guessMimeType(file.fileName),
      createdAt: DateTime.now(),
    );
    items.add(uploadedFile);
    _tripFiles[tripId] = items;
    _uploadedFileBytesById[uploadedFile.id] = List<int>.from(file.bytes);
    return uploadedFile;
  }

  @override
  Future<AuthPhotoReviewResult> analyzeAuthPhoto({
    required int tripId,
    required int uploadedFileId,
    int? placeId,
  }) async {
    final trip = _requireTrip(tripId);
    return AuthPhotoReviewResult(
      approved: true,
      detectedPeopleCount: trip.travelerCount,
      requiredPeopleCount: trip.travelerCount,
      facesClear: true,
      backgroundVisible: true,
      reason: '모의 환경에서는 인증사진을 자동 승인합니다.',
    );
  }

  @override
  Future<void> deleteUploadedFile({
    required int tripId,
    required int uploadedFileId,
  }) async {
    final files = [...?_tripFiles[tripId]];
    final removedFile = files.cast<UploadedFileItem?>().firstWhere(
          (item) => item?.id == uploadedFileId,
          orElse: () => null,
        );
    if (removedFile == null) {
      return;
    }

    files.removeWhere((item) => item.id == uploadedFileId);
    _tripFiles[tripId] = files;
    _uploadedFileBytesById.remove(uploadedFileId);

    final receipts = [...?_tripReceipts[tripId]];
    receipts.removeWhere((item) => item.uploadedFileId == uploadedFileId);
    _tripReceipts[tripId] = receipts;

    final lodging = _tripLodging[tripId];
    if (lodging?.uploadedFileId == uploadedFileId) {
      _tripLodging[tripId] = LodgingInfo(
        id: lodging!.id,
        lodgingName: lodging.lodgingName,
        representativeName: lodging.representativeName,
        phoneNumber: lodging.phoneNumber,
        address: lodging.address,
        signatureSvgPath: lodging.signatureSvgPath,
        agreedPersonalInfo: lodging.agreedPersonalInfo,
        agreedStayProof: lodging.agreedStayProof,
        uploadedFileId: null,
      );
    }

    final trip = _requireTrip(tripId);
    final total = receipts.fold<int>(0, (sum, item) => sum + item.eligibleAmount);
    _trips[tripId] = trip.copyWith(totalSpentAmount: total);
  }

  @override
  Future<Uint8List> downloadUploadedFileBytes({
    required int tripId,
    required int uploadedFileId,
  }) async {
    final uploadedFile = (_tripFiles[tripId] ?? const <UploadedFileItem>[])
        .cast<UploadedFileItem?>()
        .firstWhere(
          (item) => item?.id == uploadedFileId,
          orElse: () => null,
        );
    if (uploadedFile == null) {
      throw Exception('파일 정보를 찾을 수 없습니다.');
    }
    final bytes = _uploadedFileBytesById[uploadedFileId];
    if (bytes == null) {
      throw Exception('파일 데이터가 없습니다.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<ReceiptItem> analyzeReceipt({
    required int tripId,
    required int uploadedFileId,
    required ReceiptUsageScope usageScope,
  }) async {
    final file = (_tripFiles[tripId] ?? const <UploadedFileItem>[]).firstWhere(
      (item) => item.id == uploadedFileId,
    );
    final resolvedUsageScope = _resolveReceiptUsageScope(
      file.originalFileName,
      usageScope,
    );
    final amount = _extractAmount(file.originalFileName) ?? 40000;
    final paymentType = _classifyPayment(file.originalFileName);
    final review = _reviewReceipt(paymentType, resolvedUsageScope, amount);
    final receipts = [...?_tripReceipts[tripId]];
    final receipt = ReceiptItem(
      id: _nextReceiptId++,
      uploadedFileId: uploadedFileId,
      paymentType: paymentType,
      usageScope: resolvedUsageScope,
      reviewStatus: review.$1,
      amount: amount,
      paymentDateTime: DateTime.now().subtract(const Duration(minutes: 5)),
      eligibleAmount: review.$2,
      reviewReason: review.$3,
      rawText: 'MOCK OCR: ${file.originalFileName}',
    );
    receipts.removeWhere((item) => item.uploadedFileId == uploadedFileId);
    receipts.add(receipt);
    _tripReceipts[tripId] = receipts;

    final trip = _requireTrip(tripId);
    final total = receipts.fold<int>(0, (sum, item) => sum + item.eligibleAmount);
    _trips[tripId] = trip.copyWith(totalSpentAmount: total);
    if (trip.regionId == 1 && resolvedUsageScope == ReceiptUsageScope.lodging) {
      _tripLodging[tripId] = LodgingInfo(
        id: tripId + 5000,
        lodgingName: _mockLodgingName(file.originalFileName),
        representativeName: '완도 숙박업주',
        phoneNumber: '061-555-1234',
        address: '전라남도 완도군 샘플로 12',
        signatureSvgPath: _tripLodging[tripId]?.signatureSvgPath ?? '',
        agreedPersonalInfo: _tripLodging[tripId]?.agreedPersonalInfo ?? false,
        agreedStayProof: _tripLodging[tripId]?.agreedStayProof ?? false,
        uploadedFileId: uploadedFileId,
      );
    }
    return receipt;
  }

  @override
  Future<ReceiptItem> correctReceipt({
    required int tripId,
    required int receiptId,
    int? amount,
    PaymentType? paymentType,
    DateTime? paymentDateTime,
  }) async {
    final receipts = [...?_tripReceipts[tripId]];
    final index = receipts.indexWhere((item) => item.id == receiptId);
    if (index < 0) {
      throw StateError('Receipt not found: $receiptId');
    }
    final before = receipts[index];
    final nextAmount = amount ?? before.amount ?? 0;
    final nextPaymentType = paymentType ?? before.paymentType;
    // 보정값도 실서버처럼 심사를 다시 탄다 — mock에서만 통과하는 값이 생기지 않게.
    final review = _reviewReceipt(nextPaymentType, before.usageScope, nextAmount);
    final corrected = ReceiptItem(
      id: before.id,
      uploadedFileId: before.uploadedFileId,
      paymentType: nextPaymentType,
      usageScope: before.usageScope,
      reviewStatus: review.$1,
      amount: nextAmount,
      paymentDateTime: paymentDateTime ?? before.paymentDateTime,
      eligibleAmount: review.$2,
      reviewReason: review.$3,
      rawText: before.rawText,
    );
    receipts[index] = corrected;
    _tripReceipts[tripId] = receipts;

    final trip = _requireTrip(tripId);
    final total = receipts.fold<int>(0, (sum, item) => sum + item.eligibleAmount);
    _trips[tripId] = trip.copyWith(totalSpentAmount: total);
    return corrected;
  }

  @override
  Future<LodgingInfo> saveLodgingInfo(
      int tripId, LodgingInfo lodgingInfo) async {
    final next = lodgingInfo.id == 0 ? lodgingInfo.copyWith() : lodgingInfo;
    _tripLodging[tripId] = LodgingInfo(
      id: next.id == 0 ? tripId + 5000 : next.id,
      lodgingName: next.lodgingName,
      representativeName: next.representativeName,
      phoneNumber: next.phoneNumber,
      address: next.address,
      signatureSvgPath: next.signatureSvgPath,
      agreedPersonalInfo: next.agreedPersonalInfo,
      agreedStayProof: next.agreedStayProof,
      uploadedFileId: next.uploadedFileId,
    );
    return _tripLodging[tripId]!;
  }

  @override
  Future<LodgingInfo> extractLodgingInfo({
    required int tripId,
    required int uploadedFileId,
  }) async {
    final file = (_tripFiles[tripId] ?? const <UploadedFileItem>[]).firstWhere(
      (item) => item.id == uploadedFileId,
    );
    final lodgingInfo = LodgingInfo(
      id: tripId + 5000,
      lodgingName: file.originalFileName.toLowerCase().contains('hotel')
          ? 'Mock Hotel'
          : '',
      representativeName: '',
      phoneNumber: '',
      address: '',
      signatureSvgPath: '',
      agreedPersonalInfo: false,
      agreedStayProof: false,
      uploadedFileId: uploadedFileId,
    );
    _tripLodging[tripId] = lodgingInfo;
    return lodgingInfo;
  }

  @override
  Future<LodgingFormData> getLodgingFormData(int tripId) async {
    final trip = _requireTrip(tripId);
    final lodging = _tripLodging[tripId] ?? LodgingInfo.empty();
    return LodgingFormData(
      tripId: trip.id,
      regionName: trip.regionName,
      template: const LodgingFormTemplateItem(
        templateId: 1,
        templateKey: 'mock-regional-lodging-form',
        templateName: 'regional_lodging_confirmation_mock.pdf',
        // 실서버(V61 이후)와 동일하게 DOCX 폼 입력 UI를 데모하도록 맞춘다.
        sourceFormat: 'DOCX',
        previewTitle: '숙박확인서',
        previewSubtitle: 'Mock 모드 공통 템플릿',
        fields: [
          LodgingFormFieldItem(
            key: 'traveler_name',
            label: '신청자명',
            type: 'text',
            x: 8,
            y: 12,
            width: 24,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '',
          ),
          LodgingFormFieldItem(
            key: 'traveler_phone_number',
            label: '신청자 연락처',
            type: 'text',
            x: 36,
            y: 12,
            width: 24,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '',
          ),
          LodgingFormFieldItem(
            key: 'region_name',
            label: '여행 지역',
            type: 'text',
            x: 64,
            y: 12,
            width: 28,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '',
          ),
          LodgingFormFieldItem(
            key: 'trip_date_range',
            label: '여행 기간',
            type: 'text',
            x: 8,
            y: 24,
            width: 40,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '',
          ),
          LodgingFormFieldItem(
            key: 'residence',
            label: '거주지',
            type: 'text',
            x: 52,
            y: 24,
            width: 40,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '',
          ),
          LodgingFormFieldItem(
            key: 'lodging_name',
            label: '숙박업소명',
            type: 'text',
            x: 8,
            y: 40,
            width: 84,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '실제 숙박업소명을 입력하세요.',
          ),
          LodgingFormFieldItem(
            key: 'representative_name',
            label: '대표자명',
            type: 'text',
            x: 8,
            y: 52,
            width: 38,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '대표자 이름을 입력하세요.',
          ),
          LodgingFormFieldItem(
            key: 'phone_number',
            label: '전화번호',
            type: 'text',
            x: 54,
            y: 52,
            width: 38,
            height: 8,
            editable: true,
            multiline: false,
            helperText: '대표 연락처를 입력하세요.',
          ),
          LodgingFormFieldItem(
            key: 'address',
            label: '주소',
            type: 'text',
            x: 8,
            y: 64,
            width: 84,
            height: 12,
            editable: true,
            multiline: true,
            helperText: '숙박업소 주소를 입력하세요.',
          ),
          LodgingFormFieldItem(
            key: 'agreed_personal_info',
            label: '개인정보 제공 동의',
            type: 'checkbox',
            x: 8,
            y: 80,
            width: 40,
            height: 6,
            editable: true,
            multiline: false,
            helperText: '숙박업주 동의를 받은 후 체크하세요.',
          ),
          LodgingFormFieldItem(
            key: 'agreed_stay_proof',
            label: '실제 숙박 사실 확인',
            type: 'checkbox',
            x: 52,
            y: 80,
            width: 40,
            height: 6,
            editable: true,
            multiline: false,
            helperText: '숙박 사실 확인 후 체크하세요.',
          ),
          LodgingFormFieldItem(
            key: 'signature',
            label: '숙박업주 서명',
            type: 'signature',
            x: 58,
            y: 88,
            width: 34,
            height: 10,
            editable: true,
            multiline: false,
            helperText: '전자서명을 입력하세요.',
          ),
        ],
        notes: ['Mock 모드에서는 실제 PDF 대신 화면 미리보기만 제공합니다.'],
      ),
      instance: LodgingFormInstanceItem(
        instanceId: tripId + 9000,
        status: 'DRAFT',
        payload: {
          'traveler_name': trip.applicantName,
          'traveler_phone_number': _user.phoneNumber,
          'region_name': trip.regionName,
          'trip_date_range':
              '${trip.startDate.toIso8601String().split('T').first} ~ ${trip.endDate.toIso8601String().split('T').first}',
          'residence': _user.residence,
          'lodging_name': lodging.lodgingName,
          'representative_name': lodging.representativeName,
          'phone_number': lodging.phoneNumber,
          'address': lodging.address,
          'agreed_personal_info': lodging.agreedPersonalInfo,
          'agreed_stay_proof': lodging.agreedStayProof,
          'signature': lodging.signatureSvgPath,
        },
        lastSavedAt: DateTime.now(),
        renderedPdfFileName: null,
      ),
      todos: const [
        'TODO: 실제 지역별 PDF 템플릿을 연결하면 이 구조를 그대로 재사용합니다.',
        'TODO: Mock 모드에서는 텍스트 파일만 생성합니다.',
      ],
    );
  }

  @override
  Future<LodgingFormData> saveLodgingForm(
    int tripId,
    LodgingFormSaveRequest request,
  ) async {
    final payload = request.payload;
    _tripLodging[tripId] = LodgingInfo(
      id: tripId + 5000,
      lodgingName: payload['lodging_name']?.toString() ?? '',
      representativeName: payload['representative_name']?.toString() ?? '',
      phoneNumber: payload['phone_number']?.toString() ?? '',
      address: payload['address']?.toString() ?? '',
      signatureSvgPath: payload['signature']?.toString() ?? '',
      agreedPersonalInfo: payload['agreed_personal_info'] as bool? ?? false,
      agreedStayProof: payload['agreed_stay_proof'] as bool? ?? false,
      uploadedFileId: _tripLodging[tripId]?.uploadedFileId,
    );
    return getLodgingFormData(tripId);
  }

  @override
  Future<LodgingFormData> saveLodgingFormTemplateLayout(
    int tripId,
    List<LodgingFormFieldItem> fields,
  ) async {
    return getLodgingFormData(tripId);
  }

  @override
  Future<LodgingFormData> analyzeLodgingFormTemplate(int tripId) async {
    return getLodgingFormData(tripId);
  }

  @override
  String? getLodgingFormTemplatePreviewUrl(int tripId) => null;

  @override
  String? getLodgingFormRenderedPdfUrl(int tripId) => null;

  @override
  Future<String> downloadLodgingFormPdf(int tripId) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/trip-$tripId-lodging-form-mock.txt');
    final formData = await getLodgingFormData(tripId);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(formData.instance.payload),
    );
    return file.path;
  }

  @override
  Future<Uint8List> fetchLodgingFormPdfBytes(int tripId) async {
    // 목 환경에는 실제 PDF 렌더러가 없어 인쇄·공유를 지원하지 않는다.
    throw UnsupportedError('목 환경에서는 숙박확인서 PDF를 지원하지 않습니다.');
  }

  @override
  Future<SettlementSummary> getSettlementSummary(int tripId) async {
    return _buildSettlementSummary(_requireTrip(tripId));
  }

  @override
  Future<void> applySettlement(
    int tripId, {
    String? applicantName,
    String? phoneNumber,
  }) async {
    final trip = _requireTrip(tripId);
    _trips[tripId] = trip.copyWith(
      status: '정산 신청 완료',
      settlementApplied: true,
    );
  }

  @override
  Future<NotificationSettings> updateNotificationSettings(
    int userId,
    NotificationSettings settings,
  ) async {
    _user = _user.copyWith(notificationSettings: settings);
    return settings;
  }

  // 커뮤니티 — mock 모드는 화면이 AppState 로컬퍼스트를 직접 쓰므로 서버 경로는 비활성.
  @override
  Future<List<CommunityPostData>> getCommunityFeed({int? userId}) async => const [];

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
    throw UnsupportedError('mock 모드는 로컬퍼스트 커뮤니티를 사용합니다');
  }

  @override
  Future<void> toggleCommunityLike(int postId, int userId) async {}

  @override
  Future<void> toggleCommunityBookmark(int postId, int userId) async {}

  @override
  Future<void> updateCommunityVisibility(
      int postId, int userId, String visibility) async {}

  @override
  Future<List<CommunityCommentData>> getCommunityComments(int postId,
          {int? userId}) async =>
      const [];

  @override
  Future<CommunityCommentData> addCommunityComment(
      int postId, int userId, String body,
      {int? parentId, int? mentionUserId}) async {
    throw UnsupportedError('mock 모드는 로컬퍼스트 커뮤니티를 사용합니다');
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
    throw UnsupportedError('mock 모드는 로컬퍼스트 커뮤니티를 사용합니다');
  }

  @override
  Future<void> deleteCommunityPost(int postId, int userId) async {}

  @override
  Future<void> toggleCommunityCommentLike(int commentId, int userId) async {}

  @override
  Future<void> deleteCommunityComment(int commentId, int userId) async {}

  @override
  Future<void> reportCommunity({
    required int userId,
    required String targetType,
    required int targetId,
    String? reason,
  }) async {}

  @override
  Future<CommunityMyPosts> getMyCommunityPosts(int userId) async =>
      const CommunityMyPosts(
          postCount: 0, receivedLikeCount: 0, receivedSaveCount: 0, posts: []);

  @override
  Future<List<CommunityPostData>> getMyCommunityBookmarks(int userId) async =>
      const [];

  final Map<int, List<ChecklistItem>> _checklists = {};

  @override
  Future<List<ChecklistItem>> getTripChecklist(int tripId) async {
    return _checklists.putIfAbsent(tripId, ChecklistItem.defaults);
  }

  @override
  Future<List<ChecklistItem>> updateTripChecklist(
    int tripId,
    List<ChecklistItem> items,
  ) async {
    _checklists[tripId] = List.of(items);
    return items;
  }

  @override
  Future<List<AppNotification>> getNotifications(int userId) async {
    return [..._notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAllNotificationsRead(int userId) async {
    _notifications =
        _notifications.map((n) => n.copyWith(read: true)).toList();
  }

  static List<AppNotification> _seedNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        type: NotificationType.regionOpen,
        title: '강진 반값여행 접수 시작 🎉',
        refType: 'REGION', refId: 2,
        body: '관심 등록한 강진의 6월 반값여행 접수가 열렸어요. 지금 신청해보세요.',
        createdAt: now.subtract(const Duration(minutes: 10)),
        read: false,
      ),
      AppNotification(
        type: NotificationType.courseDone,
        title: '유튜브 코스가 완성됐어요',
        refType: 'COURSE', refId: 1,
        body: '강진 유튜브 추천 코스를 내 코스함에 저장했어요. 확인해보세요.',
        createdAt: now.subtract(const Duration(hours: 1)),
        read: false,
      ),
      AppNotification(
        type: NotificationType.communityLike,
        title: '여행하는민트님 외 4명이 좋아해요',
        refType: 'POST', refId: 1,
        body: '내 글 "강진 여행 후기"에 좋아요가 달렸어요.',
        createdAt: now.subtract(const Duration(hours: 3)),
        read: false,
      ),
      AppNotification(
        type: NotificationType.settleDeadline,
        title: '영월 정산 신청 마감 D-3',
        refType: 'TRIP', refId: 1,
        body: '여행 종료 다음날부터 7일 이내에 정산을 신청하세요.',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
      AppNotification(
        type: NotificationType.communityComment,
        title: '강진가고파님이 댓글을 남겼어요',
        refType: 'POST', refId: 1,
        body: '가우도 주차는 어디 하셨어요?',
        createdAt: now.subtract(const Duration(days: 2)),
        read: true,
      ),
      AppNotification(
        type: NotificationType.settleDeadline,
        title: '완도 접수 마감 D-1',
        refType: 'REGION', refId: 1,
        body: '관심 등록한 완도 반값여행 접수가 곧 마감돼요.',
        createdAt: now.subtract(const Duration(days: 3)),
        read: true,
      ),
      AppNotification(
        type: NotificationType.benefit,
        title: '디지털 관광주민증 혜택 추가',
        refType: 'MERCHANT', refId: 1,
        body: '강진 가맹점에 디민증 추가 할인 혜택이 생겼어요.',
        createdAt: now.subtract(const Duration(days: 7)),
        read: true,
      ),
    ];
  }

  @override
  Future<List<RegionSummary>> addFavoriteRegion(int userId, int regionId) async {
    final region = _regionDetails[regionId]?.region;
    if (region == null) {
      throw Exception('지역 정보를 찾을 수 없습니다.');
    }
    final favorites = [..._user.favoriteRegions];
    if (!favorites.any((item) => item.id == regionId)) {
      favorites.add(region);
      _user = _user.copyWith(favoriteRegions: favorites);
    }
    return _user.favoriteRegions;
  }

  @override
  Future<List<RegionSummary>> removeFavoriteRegion(int userId, int regionId) async {
    final favorites = _user.favoriteRegions
        .where((item) => item.id != regionId)
        .toList(growable: false);
    _user = _user.copyWith(favoriteRegions: favorites);
    return _user.favoriteRegions;
  }

  @override
  Future<String> downloadMergedPdf(
      int tripId, List<int> uploadedFileIds, {String? fileName}) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/trip-$tripId-mock-bundle.txt');
    final payload = {
      'tripId': tripId,
      'uploadedFileIds': uploadedFileIds,
      'generatedAt': DateTime.now().toIso8601String(),
      'note':
          'Mock mode bundle. Use Spring + FastAPI integration for real PDF merge.',
    };
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  TripSummary _requireTrip(int tripId) {
    final trip = _trips[tripId];
    if (trip == null) {
      throw Exception('여행 정보를 찾을 수 없습니다.');
    }
    return trip;
  }

  SettlementSummary _buildSettlementSummary(TripSummary trip) {
    final remaining = (trip.refundConditionAmount - trip.totalSpentAmount)
        .clamp(0, trip.refundConditionAmount);
    return SettlementSummary(
      totalSpentAmount: trip.totalSpentAmount,
      refundConditionAmount: trip.refundConditionAmount,
      remainingAmount: remaining,
      statusMessage:
          '현재 ${trip.totalSpentAmount}원 소비 / 환급 조건 ${trip.refundConditionAmount}원까지 ${remaining}원 남음',
    );
  }

  int? _extractAmount(String source) {
    final matched = RegExp(r'(\d[\d,]{2,})').allMatches(source);
    if (matched.isEmpty) {
      return null;
    }
    return int.tryParse(matched.last.group(1)!.replaceAll(',', ''));
  }

  PaymentType _classifyPayment(String source) {
    final lowered = source.toLowerCase();
    if (lowered.contains('credit') || lowered.contains('card')) {
      return PaymentType.creditCard;
    }
    if (lowered.contains('check')) {
      return PaymentType.checkCard;
    }
    if (lowered.contains('pay') || lowered.contains('online')) {
      return PaymentType.onlinePayment;
    }
    if (lowered.contains('transfer')) {
      return PaymentType.bankTransfer;
    }
    if (lowered.contains('cash')) {
      return PaymentType.cashReceipt;
    }
    if (lowered.contains('simple')) {
      return PaymentType.simpleReceipt;
    }
    return PaymentType.unknown;
  }

  ReceiptUsageScope _resolveReceiptUsageScope(
    String source,
    ReceiptUsageScope requested,
  ) {
    if (requested == ReceiptUsageScope.lodging) {
      return requested;
    }
    final lowered = source.toLowerCase();
    if (lowered.contains('hotel') ||
        lowered.contains('motel') ||
        lowered.contains('stay') ||
        lowered.contains('guesthouse') ||
        lowered.contains('lodging') ||
        lowered.contains('숙박')) {
      return ReceiptUsageScope.lodging;
    }
    return requested;
  }

  String _mockLodgingName(String source) {
    final lowered = source.toLowerCase();
    if (lowered.contains('hotel')) {
      return '완도 오션 호텔';
    }
    if (lowered.contains('motel')) {
      return '완도 블루 모텔';
    }
    return '완도 바다 스테이';
  }

  (ReceiptReviewStatus, int, String) _reviewReceipt(
    PaymentType paymentType,
    ReceiptUsageScope usageScope,
    int? amount,
  ) {
    final approved = usageScope == ReceiptUsageScope.lodging
        ? {
            PaymentType.creditCard,
            PaymentType.checkCard,
            PaymentType.onlinePayment,
            PaymentType.cashReceipt,
          }
        : {
            PaymentType.creditCard,
            PaymentType.checkCard,
            PaymentType.onlinePayment,
          };
    if (approved.contains(paymentType)) {
      return (
        ReceiptReviewStatus.approved,
        amount ?? 0,
        usageScope == ReceiptUsageScope.lodging &&
                paymentType == PaymentType.cashReceipt
            ? '완도 숙박 결제 현금영수증 인정'
            : '완도 규칙 통과'
      );
    }
    return (
      ReceiptReviewStatus.rejected,
      0,
      '완도 정산 규칙상 인정되지 않는 영수증입니다.'
    );
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'application/octet-stream';
  }
}

