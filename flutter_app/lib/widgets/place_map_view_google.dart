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
  late final Future<bool> _ready = ensureGoogleMapsJs(widget.apiKey);
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
            icon: m.id == widget.highlightedMarkerId
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure)
                : BitmapDescriptor.defaultMarker,
            onTap: () => widget.onMarkerTap?.call(m.id),
          ),
        for (var i = 0; i < widget.routeMarkers.length; i++)
          Marker(
            markerId: MarkerId('route-${widget.routeMarkers[i].id}'),
            position: LatLng(widget.routeMarkers[i].latitude,
                widget.routeMarkers[i].longitude),
            infoWindow: InfoWindow(title: '경유지 ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
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
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FutureBuilder<bool>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.data != true) {
              return const Center(child: CircularProgressIndicator());
            }
            return GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 12),
              markers: _gMarkers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (c) => _controller = c,
            );
          },
        ),
      ),
    );
  }
}
