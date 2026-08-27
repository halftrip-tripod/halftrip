import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.numberedMarkers = false,
    this.highlightedMarkerId,
    this.onViewportChanged,
    this.onMarkerTap,
    this.onMarkerDetailsRequested,
    this.initialCenterLatitude,
    this.initialCenterLongitude,
    this.height = 420,
  });

  final String apiKey;
  final List<PlaceMapMarkerData> markers;
  final String emptyMessage;
  final List<PlaceMapRoutePoint> routeMarkers;
  final bool connectSequentially;

  /// 일반 마커에도 리스트 순서(1,2,3…) 번호 핀을 쓸지 (코스 장소 검색용).
  final bool numberedMarkers;
  final int? highlightedMarkerId;
  final ValueChanged<PlaceMapViewport>? onViewportChanged;
  final ValueChanged<int>? onMarkerTap;
  final Future<PlaceMapMarkerData?> Function(PlaceMapMarkerData marker)?
      onMarkerDetailsRequested;
  final double? initialCenterLatitude;
  final double? initialCenterLongitude;
  final double height;

  @override
  State<GooglePlaceMapView> createState() => _GooglePlaceMapViewState();
}

class _GooglePlaceMapViewState extends State<GooglePlaceMapView> {
  late final Future<bool> _ready = _prepare();

  @override
  void initState() {
    super.initState();
    // 하이라이트 마커가 지정돼 들어오면 정보창을 처음부터 연다
    // (상세 일정 탭 → 지도 이동·장소 정보 연동용).
    for (final marker in widget.markers) {
      if (marker.id == widget.highlightedMarkerId) {
        _selectedMarker = marker;
        break;
      }
    }
  }

  // 하늘색=기본, 코랄=검색에서 선택된 장소.
  static const _skyPin = Color(0xFF0EA5E9);
  static const _coralPin = Color(0xFFF0655A);

  BitmapDescriptor? _pin;
  BitmapDescriptor? _pinHighlight;
  List<BitmapDescriptor> _numberedPins = const [];
  List<BitmapDescriptor> _markerNumberedPins = const [];
  List<BitmapDescriptor> _markerNumberedPinsSel = const [];
  PlaceMapMarkerData? _selectedMarker;
  GoogleMapController? _controller;

  Future<void> _notifyViewport() async {
    final controller = _controller;
    final callback = widget.onViewportChanged;
    if (controller == null || callback == null) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      callback(PlaceMapViewport(
        centerLatitude:
            (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        centerLongitude:
            (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
        minLatitude: bounds.southwest.latitude,
        maxLatitude: bounds.northeast.latitude,
        minLongitude: bounds.southwest.longitude,
        maxLongitude: bounds.northeast.longitude,
      ));
    } catch (_) {}
  }

  Future<bool> _prepare() async {
    final loaded = await ensureGoogleMapsJs(widget.apiKey);
    _pin = await _drawPin(_skyPin);
    _pinHighlight = await _drawPin(const Color(0xFF0369A1));
    await _buildNumberedPins();
    return loaded;
  }

  /// 번호 핀들을 마커 수에 맞춰 (재)생성. 코스 편집에서 장소를 추가·삭제하거나
  /// 검색을 다시 하면 개수가 바뀌므로 didUpdateWidget에서 다시 부른다.
  Future<void> _buildNumberedPins() async {
    // 코스 모드: 방문 순서 리스트와 동일한 번호 핀.
    _numberedPins = [
      for (var i = 0; i < widget.routeMarkers.length; i++)
        await _drawPin(_skyPin, label: '${i + 1}'),
    ];
    // 코스 장소 검색: 일반 마커도 리스트 순서 번호 핀 (마커 id = 리스트 인덱스).
    // 선택된 장소는 코랄로 강조하기 위해 두 벌 만들어 둔다.
    if (widget.numberedMarkers) {
      _markerNumberedPins = [
        for (final m in widget.markers)
          await _drawPin(_skyPin, label: '${m.id + 1}'),
      ];
      _markerNumberedPinsSel = [
        for (final m in widget.markers)
          await _drawPin(_coralPin, label: '${m.id + 1}'),
      ];
    }
  }

  @override
  void didUpdateWidget(covariant GooglePlaceMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 장소 추가/삭제(코스 편집 라이브 반영)·검색 재조회로 개수가 바뀌면 번호 핀을 다시 맞춘다.
    if (oldWidget.routeMarkers.length != widget.routeMarkers.length ||
        oldWidget.markers.length != widget.markers.length) {
      _buildNumberedPins().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// 번호 핀([label] 있음) = 원형 + 숫자. 단독 장소 핀([label] 없음) = 물방울(teardrop).
  static Future<BitmapDescriptor> _drawPin(Color color, {String? label}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (label != null) {
      // 원형 번호 핀 — 코스 순서·검색 결과.
      const size = 48.0;
      const center = Offset(size / 2, size / 2);
      canvas.drawCircle(center, 22, Paint()..color = Colors.black.withValues(alpha: .12));
      canvas.drawCircle(center, 20, Paint()..color = Colors.white);
      canvas.drawCircle(center, 16, Paint()..color = color);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
      final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 34, height: 34);
    }

    // 물방울 핀 — 단독 장소(장소 상세) 표시.
    const w = 44.0, h = 56.0, cx = 22.0, cy = 20.0, r = 16.0, tipY = 53.0;
    Path teardrop(double radius, double tip) {
      return Path()
        ..moveTo(cx, tip)
        ..quadraticBezierTo(cx - radius * 0.98, cy + radius * 0.72, cx - radius, cy)
        ..arcToPoint(Offset(cx + radius, cy), radius: Radius.circular(radius), clockwise: true)
        ..quadraticBezierTo(cx + radius * 0.98, cy + radius * 0.72, cx, tip)
        ..close();
    }

    canvas.drawPath(teardrop(r, tipY).shift(const Offset(0, 1.2)),
        Paint()..color = Colors.black.withValues(alpha: .18));
    canvas.drawPath(teardrop(r, tipY), Paint()..color = Colors.white);
    canvas.drawPath(teardrop(r - 3, tipY - 3), Paint()..color = color);
    canvas.drawCircle(const Offset(cx, cy), 5.5, Paint()..color = Colors.white);

    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 30, height: 38);
  }

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

  bool get _courseMode =>
      widget.connectSequentially && widget.routeMarkers.isNotEmpty;

  /// 경유지 좌표와 일치하는 일반 마커(장소 정보·탭 동작 보유)를 찾는다.
  PlaceMapMarkerData? _markerAt(double lat, double lng) {
    for (final m in widget.markers) {
      if ((m.latitude - lat).abs() < 1e-6 && (m.longitude - lng).abs() < 1e-6) {
        return m;
      }
    }
    return null;
  }

  Future<void> _selectMarker(PlaceMapMarkerData marker) async {
    setState(() => _selectedMarker = marker);
    widget.onMarkerTap?.call(marker.id);
    final loader = widget.onMarkerDetailsRequested;
    if (loader == null) {
      return;
    }
    final detailed = await loader(marker);
    if (!mounted || detailed == null) {
      return;
    }
    if (_selectedMarker?.id == marker.id) {
      setState(() => _selectedMarker = detailed);
    }
  }

  Future<void> _openPlaceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 일반(비코스) 마커 아이콘 — 하이라이트 > 번호핀(선택 시 코랄) > 기본 물방울.
  /// 재생성 중 개수가 어긋날 수 있어 인덱스는 항상 경계 검사한다.
  BitmapDescriptor _markerIcon(int idx, PlaceMapMarkerData m) {
    if (m.id == widget.highlightedMarkerId && _pinHighlight != null) {
      return _pinHighlight!;
    }
    if (widget.numberedMarkers && idx < _markerNumberedPins.length) {
      if (m.selected && idx < _markerNumberedPinsSel.length) {
        return _markerNumberedPinsSel[idx];
      }
      return _markerNumberedPins[idx];
    }
    return _pin ?? BitmapDescriptor.defaultMarker;
  }

  /// 코스 모드: 번호 핀 하나에 장소 정보·탭을 병합해 중복 핀 없이 표시.
  /// 일반 모드: 장소 핀 그대로.
  Set<Marker> get _gMarkers => {
        if (!_courseMode)
          for (final (idx, m) in widget.markers.indexed)
            Marker(
              markerId: MarkerId('place-${m.id}'),
              position: LatLng(m.latitude, m.longitude),
              // 네이티브 InfoWindow 대신 커스텀 상세 카드만 사용 (닫기 시 잔여 말풍선 방지)
              infoWindow: InfoWindow.noText,
              icon: _markerIcon(idx, m),
              // 번호 핀(원형)은 중앙, 물방울(단독 장소)은 하단 팁 기준.
              anchor: widget.numberedMarkers
                  ? const Offset(0.5, 0.5)
                  : const Offset(0.5, 1.0),
              onTap: () {
                _selectMarker(m);
              },
            ),
        if (_courseMode)
          for (var i = 0; i < widget.routeMarkers.length; i++)
            () {
              final route = widget.routeMarkers[i];
              final place = _markerAt(route.latitude, route.longitude);
              return Marker(
                markerId: MarkerId('route-${route.id}'),
                position: LatLng(route.latitude, route.longitude),
                // 네이티브 InfoWindow 대신 커스텀 상세 카드만 사용 (닫기 시 잔여 말풍선 방지)
                infoWindow: InfoWindow.noText,
                icon: (i < _numberedPins.length ? _numberedPins[i] : _pin) ??
                    BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                onTap: place == null
                    ? null
                    : () {
                        _selectMarker(place);
                      },
              );
            }(),
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
            return Stack(
              children: [
                GoogleMap(
                  // 지도가 ListView 등 스크롤 가능한 조상 안에 놓일 때 드래그/핀치줌
                  // 제스처를 부모 스크롤이 가로채 지도가 고정된 그림처럼 보이는 문제를 막는다.
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  initialCameraPosition:
                      CameraPosition(target: _center, zoom: 12),
                  markers: _gMarkers,
                  polylines: _polylines,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (_) => setState(() => _selectedMarker = null),
                  onMapCreated: (controller) {
                    _controller = controller;
                    // 초기 가시 영역도 한 번 알린다 (뷰포트 기반 마커 필터용).
                    _notifyViewport();
                  },
                  onCameraIdle: _notifyViewport,
                ),
                if (_selectedMarker != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    // 내용 높이만큼만 차지하고 뒤 지도가 보이게 bottom은 고정하지
                    // 않는다. 내용이 길면 카드 안에서 스크롤된다.
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: widget.height - 48),
                      child: _GooglePlaceInfoCard(
                        marker: _selectedMarker!,
                        onClose: () => setState(() => _selectedMarker = null),
                        onOpenPlaceUrl: _openPlaceUrl,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _businessStatusLabel(String? value) {
    switch ((value ?? '').trim()) {
      case 'OPERATIONAL':
        return '영업 중';
      case 'CLOSED_TEMPORARILY':
        return '임시 휴업';
      case 'CLOSED_PERMANENTLY':
        return '폐업';
      default:
        return (value ?? '').trim();
    }
  }
}

String _googleBusinessStatusLabel(String? value) {
  switch ((value ?? '').trim()) {
    case 'OPERATIONAL':
      return '영업 정보 제공 중';
    case 'CLOSED_TEMPORARILY':
      return '임시 휴업';
    case 'CLOSED_PERMANENTLY':
      return '폐업';
    default:
      return (value ?? '').trim();
  }
}

String _googlePriceLevelLabel(String? value) {
  switch ((value ?? '').trim()) {
    case 'PRICE_LEVEL_FREE':
      return '무료';
    case 'PRICE_LEVEL_INEXPENSIVE':
      return '저렴';
    case 'PRICE_LEVEL_MODERATE':
      return '보통';
    case 'PRICE_LEVEL_EXPENSIVE':
      return '비쌈';
    case 'PRICE_LEVEL_VERY_EXPENSIVE':
      return '매우 비쌈';
    default:
      return (value ?? '').trim();
  }
}

List<MapEntry<String, String>> _googlePlaceDetailRows(
  Map<String, dynamic> details,
) {
  const preferredKeys = [
    'formattedAddress',
    'shortFormattedAddress',
    'nationalPhoneNumber',
    'internationalPhoneNumber',
    'rating',
    'userRatingCount',
    'businessStatus',
    'priceLevel',
    'types',
    'websiteUri',
    'regularOpeningHours',
    'currentOpeningHours',
    'editorialSummary',
    'id',
    'name',
    'googleMapsUri',
  ];
  final rows = <MapEntry<String, String>>[];
  for (final key in preferredKeys) {
    final value = _googleDetailValue(details[key]);
    if (value.isNotEmpty) {
      rows.add(MapEntry(key, value));
    }
  }
  return rows;
}

String _googleDetailValue(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    return value.map(_googleDetailValue).where((item) => item.isNotEmpty).take(4).join(', ');
  }
  if (value is Map) {
    final text = value['text'];
    if (text is String && text.trim().isNotEmpty) return text.trim();
    final weekdayDescriptions = value['weekdayDescriptions'];
    if (weekdayDescriptions is List) {
      return weekdayDescriptions
          .map(_googleDetailValue)
          .where((item) => item.isNotEmpty)
          .take(3)
          .join('\n');
    }
    final lat = value['latitude'];
    final lng = value['longitude'];
    if (lat != null && lng != null) return '$lat, $lng';
  }
  return '';
}

class _GooglePlaceInfoCard extends StatelessWidget {
  const _GooglePlaceInfoCard({
    required this.marker,
    required this.onClose,
    required this.onOpenPlaceUrl,
  });

  final PlaceMapMarkerData marker;
  final VoidCallback onClose;
  final ValueChanged<String> onOpenPlaceUrl;

  @override
  Widget build(BuildContext context) {
    final address = (marker.roadAddress ?? '').trim().isNotEmpty
        ? marker.roadAddress!.trim()
        : marker.address.trim();
    final category = (marker.categoryName ?? marker.regionLabel ?? '').trim();
    final phone = (marker.phoneNumber ?? '').trim();
    final placeUrl = (marker.placeUrl ?? '').trim();
    final websiteUri = (marker.websiteUri ?? '').trim();
    final internationalPhone = (marker.internationalPhoneNumber ?? '').trim();
    final businessStatus = _googleBusinessStatusLabel(marker.businessStatus);
    final priceLevel = _googlePriceLevelLabel(marker.priceLevel);
    final rating = marker.rating == null
        ? ''
        : '${marker.rating!.toStringAsFixed(1)}점'
            '${marker.userRatingCount == null ? '' : ' · 리뷰 ${marker.userRatingCount}개'}';
    final openingHours = marker.openingHours.take(7).toList();
    final summary = (marker.editorialSummary ?? '').trim();

    Widget infoRow(String value, {required IconData icon}) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF008C95)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13,
                  height: 1.28,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget actionButton({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6FAFD),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF008C95)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget hoursSection() {
      if (openingHours.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    '영업시간',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...openingHours.take(2).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    marker.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (rating.isNotEmpty || category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rating,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFFFFB300),
                        ),
                      ],
                    ),
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ],
            if (websiteUri.isNotEmpty || placeUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (placeUrl.isNotEmpty)
                    actionButton(
                      icon: Icons.place_outlined,
                      label: '지도',
                      onTap: () => onOpenPlaceUrl(placeUrl),
                    ),
                  if (websiteUri.isNotEmpty)
                    actionButton(
                      icon: Icons.language,
                      label: '웹사이트',
                      onTap: () => onOpenPlaceUrl(websiteUri),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            infoRow(address, icon: Icons.location_on_outlined),
            infoRow(businessStatus, icon: Icons.storefront),
            infoRow(phone.isNotEmpty ? phone : internationalPhone,
                icon: Icons.call),
            infoRow(priceLevel, icon: Icons.payments_outlined),
            infoRow(summary, icon: Icons.notes_outlined),
            hoursSection(),
            ],
          ),
        ),
      ),
    );
  }
}
