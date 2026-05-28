class PlaceMapMarkerData {
  const PlaceMapMarkerData({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.selected,
    this.regionLabel,
    this.imageAssetPath,
    this.actionLabel,
    this.phoneNumber,
    this.roadAddress,
    this.categoryName,
    this.placeUrl,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool selected;
  final String? regionLabel;
  final String? imageAssetPath;
  final String? actionLabel;
  final String? phoneNumber;
  final String? roadAddress;
  final String? categoryName;
  final String? placeUrl;
}

class PlaceMapRoutePoint {
  const PlaceMapRoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final double latitude;
  final double longitude;
}

class PlaceMapViewport {
  const PlaceMapViewport({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double centerLatitude;
  final double centerLongitude;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
}
