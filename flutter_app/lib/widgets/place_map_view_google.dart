import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_maps_js_loader_stub.dart'
    if (dart.library.html) 'google_maps_js_loader_web.dart';
import 'place_map_models.dart';

/// 구글맵 기반 장소 지도 — MAP_PROVIDER=google일 때 PlaceMapView가 위임.
/// Android는 manifest 키, 웹은 런타임 JS 주입(ensureGoogleMapsJs)으로 동작.
class GooglePlaceMapView extends StatefulWidget {
  const GooglePlaceMapView({
    super.key,
    required this.apiKey,
    required this.markers,
    required this.emptyMessage,
    this.routeMarkers = const [],
    this.connectSequentially = false,
    this.highlightedMarkerId,
    this.onMarkerTap,
    this.initialCenterLatitude,
    this.initialCenterLongitude,
    this.height = 420,
  });

  final String apiKey;
  final List<PlaceMapMarkerData> markers;
  final String emptyMessage;
  final List<PlaceMapRoutePoint> routeMarkers;
  final bool connectSequentially;
  final int? highlightedMarkerId;
  final ValueChanged<int>? onMarkerTap;
  final double? initialCenterLatitude;
  final double? initialCenterLongitude;
  final double height;

  @override
  State<GooglePlaceMapView> createState() => _GooglePlaceMapViewState();
}

class _GooglePlaceMapViewState extends State<GooglePlaceMapView> {
  late final Future<bool> _ready = _prepare();

  BitmapDescriptor? _pin;
  BitmapDescriptor? _pinHighlight;

  Future<bool> _prepare() async {
    final loaded = await ensureGoogleMapsJs(widget.apiKey);
    _pin = await _drawPin(const Color(0xFF0EA5E9));
    _pinHighlight = await _drawPin(const Color(0xFF0369A1));
    return loaded;
  }

  /// 디자인 시스템 하늘색 원형 핀 (흰 테두리 + 중앙 점) — 기본 빨간 핀 대체.
  static Future<BitmapDescriptor> _drawPin(Color color) async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    canvas.drawCircle(center, 22,
        Paint()..color = Colors.black.withValues(alpha: .12));
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(center, 16, Paint()..color = color);
    canvas.drawCircle(center, 5.5, Paint()..color = Colors.white);
    final image = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 34, height: 34);
  }

  /// 하프트립 톤 지도 스타일 — 파스텔 배경·하늘색 물·POI 아이콘 최소화.
  static const _halftripStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f8fafc"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bae6fd"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#0284c7"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#eef4ee"}]},
  {"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#dcefdc"}]},
  {"featureType":"poi.park","elementType":"labels.text","stylers":[{"visibility":"on"},{"color":"#4d7c5f"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e2e8f0"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dbeafe"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#bfdbfe"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#cbd5e1"}]}
]
''';
  GoogleMapController? _controller;

  LatLng get _center {
    if (widget.initialCenterLatitude != null &&
        widget.initialCenterLongitude != null) {
      return LatLng(
          widget.initialCenterLatitude!, widget.initialCenterLongitude!);
    }
    if (widget.markers.isNotEmpty) {
      final lat = widget.markers.map((m) => m.latitude).reduce((a, b) => a + b) /
          widget.markers.length;
      final lng =
          widget.markers.map((m) => m.longitude).reduce((a, b) => a + b) /
              widget.markers.length;
      return LatLng(lat, lng);
    }
    return const LatLng(36.35, 127.8); // 한반도 남부 기본
  }

  Set<Marker> get _gMarkers => {
        for (final m in widget.markers)
          Marker(
            markerId: MarkerId('place-${m.id}'),
            position: LatLng(m.latitude, m.longitude),
            infoWindow: InfoWindow(title: m.name, snippet: m.address),
            icon: (m.id == widget.highlightedMarkerId
                    ? _pinHighlight
                    : _pin) ??
                BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
            onTap: () => widget.onMarkerTap?.call(m.id),
          ),
        for (var i = 0; i < widget.routeMarkers.length; i++)
          Marker(
            markerId: MarkerId('route-${widget.routeMarkers[i].id}'),
            position: LatLng(widget.routeMarkers[i].latitude,
                widget.routeMarkers[i].longitude),
            infoWindow: InfoWindow(title: '경유지 ${i + 1}'),
            icon: _pin ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
          ),
      };

  Set<Polyline> get _polylines {
    if (!widget.connectSequentially || widget.routeMarkers.length < 2) {
      return const {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('course'),
        color: const Color(0xFF0EA5E9),
        width: 4,
        points: [
          for (final r in widget.routeMarkers) LatLng(r.latitude, r.longitude),
        ],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty && widget.routeMarkers.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text(widget.emptyMessage)),
      );
    }
    // 지도 비율 4:3 고정 (호출부 height 대신 가로 기준).
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FutureBuilder<bool>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.data != true) {
              return const Center(child: CircularProgressIndicator());
            }
            return GoogleMap(
              style: _halftripStyle,
              initialCameraPosition: CameraPosition(target: _center, zoom: 12),
              markers: _gMarkers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (c) => _controller = c,
            );
          },
        ),
      ),
    );
  }
}
