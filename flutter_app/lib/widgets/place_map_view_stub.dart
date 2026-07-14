import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import 'place_map_models.dart';
import 'place_map_view_google.dart';

class PlaceMapView extends StatelessWidget {
  const PlaceMapView({
    super.key,
    required this.markers,
    required this.emptyMessage,
    required this.kakaoEnabled,
    this.routeMarkers = const [],
    this.connectSequentially = false,
    this.highlightedMarkerId,
    this.onMarkerTap,
    this.onMarkerDoubleTap,
    this.onMarkerAction,
    this.onViewportChanged,
    this.initialCenterLatitude,
    this.initialCenterLongitude,
    this.height = 420,
  });

  final List<PlaceMapMarkerData> markers;
  final String emptyMessage;
  final bool kakaoEnabled;
  final List<PlaceMapRoutePoint> routeMarkers;
  final bool connectSequentially;
  final int? highlightedMarkerId;
  final ValueChanged<int>? onMarkerTap;
  final ValueChanged<int>? onMarkerDoubleTap;
  final ValueChanged<int>? onMarkerAction;
  final ValueChanged<PlaceMapViewport>? onViewportChanged;
  final double? initialCenterLatitude;
  final double? initialCenterLongitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    // MAP_PROVIDER=google이면 구글맵으로 위임 (웹은 JS 런타임 주입, 네이티브는 SDK).
    final config = AppConfig.fromEnvironment();
    if (config.canUseGoogleMap) {
      return GooglePlaceMapView(
        apiKey: config.googleMapApiKey,
        markers: markers,
        emptyMessage: emptyMessage,
        routeMarkers: routeMarkers,
        connectSequentially: connectSequentially,
        highlightedMarkerId: highlightedMarkerId,
        onMarkerTap: onMarkerTap,
        initialCenterLatitude: initialCenterLatitude,
        initialCenterLongitude: initialCenterLongitude,
        height: height,
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F4EF), Color(0xFFF7F4E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (markers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                ),
              ),
            );
          }

          final width = constraints.maxWidth;
          final mapHeight = constraints.maxHeight;
          final positions = _buildMarkerPositions(width, mapHeight);
          final routePositions = _buildRoutePositions(width, mapHeight);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapBackgroundPainter(
                    markerPositions: positions.values.toList(),
                    routePositions:
                        connectSequentially ? routePositions : const [],
                  ),
                ),
              ),
              ...markers.map((marker) {
                final position = positions[marker.id]!;
                final selected = highlightedMarkerId == marker.id;
                return Positioned(
                  left: position.dx - 22,
                  top: position.dy - 52,
                  child: GestureDetector(
                    onTap: () => onMarkerTap?.call(marker.id),
                    onDoubleTap: () => onMarkerDoubleTap?.call(marker.id),
                    child: _MarkerPin(
                      label: '${markers.indexOf(marker) + 1}',
                      selected: selected || marker.selected,
                    ),
                  ),
                );
              }),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      kakaoEnabled
                          ? '프로토타입 지도에서 마커를 눌러 장소를 확인할 수 있어요.'
                          : '지금은 프로토타입 지도로 마커 위치와 동선을 보여주고 있어요.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<int, Offset> _buildMarkerPositions(double width, double height) {
    final latitudes = markers.map((marker) => marker.latitude).toList();
    final longitudes = markers.map((marker) => marker.longitude).toList();
    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLng = longitudes.reduce(math.min);
    final maxLng = longitudes.reduce(math.max);
    const horizontalPadding = 44.0;
    const verticalPadding = 58.0;
    final usableWidth = math.max(width - horizontalPadding * 2, 1.0);
    final usableHeight = math.max(height - verticalPadding * 2, 1.0);

    return {
      for (final marker in markers)
        marker.id: Offset(
          horizontalPadding +
              _normalize(marker.longitude, minLng, maxLng) * usableWidth,
          verticalPadding +
              (1 - _normalize(marker.latitude, minLat, maxLat)) * usableHeight,
        ),
    };
  }

  List<Offset> _buildRoutePositions(double width, double height) {
    final markerPositions = _buildMarkerPositions(width, height);
    if (routeMarkers.isEmpty) {
      return markers
          .where((marker) => markerPositions.containsKey(marker.id))
          .map((marker) => markerPositions[marker.id]!)
          .toList();
    }
    return routeMarkers
        .map(
          (point) => markerPositions[point.id] ?? const Offset(-1000, -1000),
        )
        .where((point) => point.dx >= 0 && point.dy >= 0)
        .toList();
  }

  double _normalize(double value, double min, double max) {
    if ((max - min).abs() < 0.00001) {
      return 0.5;
    }
    return (value - min) / (max - min);
  }
}

class _MapBackgroundPainter extends CustomPainter {
  const _MapBackgroundPainter({
    required this.markerPositions,
    required this.routePositions,
  });

  final List<Offset> markerPositions;
  final List<Offset> routePositions;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFD8E7E1)
      ..strokeWidth = 1;

    for (var i = 1; i < 6; i++) {
      final dy = size.height / 6 * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final dx = size.width / 5 * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }

    final softRoad = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadLine = Paint()
      ..color = const Color(0x88BFD5CA)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.58,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.48,
        size.width * 0.92,
        size.height * 0.3,
      );
    canvas.drawPath(roadPath, softRoad);
    canvas.drawPath(roadPath, roadLine);

    final riverPaint = Paint()
      ..color = const Color(0xFFB6DFFF)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(size.width * 0.14, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.72,
        size.width * 0.48,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.9,
        size.width * 0.9,
        size.height * 0.76,
      );
    canvas.drawPath(riverPath, riverPaint);

    if (routePositions.length >= 2) {
      final routePath = Path()..moveTo(routePositions.first.dx, routePositions.first.dy);
      for (final point in routePositions.skip(1)) {
        routePath.lineTo(point.dx, point.dy);
      }
      final routePaint = Paint()
        ..color = const Color(0xFF7C3AED)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(routePath, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) {
    return oldDelegate.markerPositions != markerPositions ||
        oldDelegate.routePositions != routePositions;
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? const Color(0xFF16A34A) : const Color(0xFF8B5CF6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          width: 10,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
