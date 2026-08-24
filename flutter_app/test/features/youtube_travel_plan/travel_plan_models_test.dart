import 'package:flutter_test/flutter_test.dart';
import 'package:travel_support_mvp/features/youtube_travel_plan/travel_plan_models.dart';
import 'package:travel_support_mvp/models/app_models.dart';

void main() {
  group('TravelPlanItem.fromYoutubeStop', () {
    test('keeps unknown dates, food, and menu price empty', () {
      final item = TravelPlanItem.fromYoutubeStop(
        _stop(category: '관광지'),
        jobId: 'job-1',
      );

      expect(item.date, isNull);
      expect(item.startTime, isNull);
      expect(item.endTime, isNull);
      expect(item.foodName, isNull);
      expect(item.menuPriceAmount, isNull);
      expect(item.foodVerificationStatus, FoodVerificationStatus.notApplicable);
    });

    test('uses Google price level only as restaurant reference data', () {
      final item = TravelPlanItem.fromYoutubeStop(
        _stop(category: '식당', priceLevel: 'PRICE_LEVEL_MODERATE'),
        jobId: 'job-2',
      );

      expect(item.category, TravelCategory.food);
      expect(item.restaurantPriceLevel, 'PRICE_LEVEL_MODERATE');
      expect(
        item.restaurantPriceSource,
        RestaurantPriceSource.googlePriceLevel,
      );
      expect(item.menuPriceAmount, isNull);
      expect(item.foodName, isNull);
      expect(item.foodVerificationStatus, FoodVerificationStatus.unknown);
    });

    test('preserves an exact Google price range without converting it', () {
      final item = TravelPlanItem.fromYoutubeStop(
        _stop(
          category: '카페',
          details: const {
            'priceRange': {
              'startPrice': {'currencyCode': 'KRW', 'units': '5000'},
              'endPrice': {'currencyCode': 'KRW', 'units': '12000'},
            },
          },
        ),
        jobId: 'job-3',
      );

      expect(item.restaurantPriceMin, 5000);
      expect(item.restaurantPriceMax, 12000);
      expect(item.restaurantPriceCurrency, 'KRW');
      expect(
        item.restaurantPriceSource,
        RestaurantPriceSource.googlePriceRange,
      );
      expect(item.menuPriceAmount, isNull);
    });
  });
}

YoutubeCourseJobStop _stop({
  required String category,
  String priceLevel = '',
  Map<String, dynamic> details = const {},
}) {
  return YoutubeCourseJobStop(
    order: 1,
    placeName: '테스트 장소',
    address: '테스트 주소',
    latitude: 34.3,
    longitude: 126.7,
    category: category,
    phoneNumber: '',
    placeUrl: '',
    websiteUri: '',
    internationalPhoneNumber: '',
    rating: null,
    userRatingCount: 0,
    businessStatus: '',
    priceLevel: priceLevel,
    types: const [],
    openingHours: const [],
    editorialSummary: '',
    googlePlaceDetails: details,
    source: 'youtube',
    reason: '',
  );
}
