// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:js/js.dart' as package_js;

import 'place_map_models.dart';

class PlaceMapView extends StatefulWidget {
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
  State<PlaceMapView> createState() => _PlaceMapViewState();
}

class _PlaceMapViewState extends State<PlaceMapView> {
  static int _nextId = 0;
  static Future<void>? _sdkLoader;

  late final String _viewType;
  late final html.DivElement _container;
  late final html.EventListener _visibilityChangeListener;

  StreamSubscription<html.Event>? _resizeSubscription;
  Timer? _relayoutTimer;
  final List<js.JsObject> _markerOverlayObjects = [];
  final List<Object> _mapJsCallbacks = [];
  int _renderVersion = 0;

  js.JsObject? _map;
  js.JsObject? _bounds;
  js.JsObject? _polyline;
  js.JsObject? _activeOverlay;

  String? _statusMessage = '카카오맵을 불러오는 중입니다.';

  @override
  void initState() {
    super.initState();
    _viewType = 'kakao-place-map-${_nextId++}';
    _container = html.DivElement()
      ..id = _viewType
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.borderRadius = '24px'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = '#f8fafc';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return _container;
    });
    _visibilityChangeListener = (_) => _scheduleRelayout();
    html.document.addEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    _resizeSubscription = html.window.onResize.listen((_) {
      _scheduleRelayout();
    });

    scheduleMicrotask(_renderMap);
  }

  @override
  void didUpdateWidget(covariant PlaceMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRebuildMap(oldWidget, widget)) {
      scheduleMicrotask(_renderMap);
    }
  }

  @override
  void dispose() {
    _renderVersion++;
    _relayoutTimer?.cancel();
    _resizeSubscription?.cancel();
    html.document.removeEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    super.dispose();
  }

  void _invokeMarkerCallback(ValueChanged<int>? callback, int placeId) {
    if (callback == null || !mounted) {
      return;
    }
    scheduleMicrotask(() {
      if (!mounted) {
        return;
      }
      try {
        callback(placeId);
      } catch (error) {
        _showMessage('마커 선택 처리 중 오류가 발생했습니다.\n$error');
      }
    });
  }

  bool _shouldRebuildMap(PlaceMapView oldWidget, PlaceMapView newWidget) {
    if (oldWidget.kakaoEnabled != newWidget.kakaoEnabled ||
        oldWidget.connectSequentially != newWidget.connectSequentially ||
        oldWidget.emptyMessage != newWidget.emptyMessage ||
        oldWidget.height != newWidget.height ||
        oldWidget.markers.length != newWidget.markers.length ||
        oldWidget.routeMarkers.length != newWidget.routeMarkers.length) {
      return true;
    }

    for (var index = 0; index < oldWidget.markers.length; index++) {
      final before = oldWidget.markers[index];
      final after = newWidget.markers[index];
      if (before.id != after.id ||
          before.name != after.name ||
          before.address != after.address ||
          before.latitude != after.latitude ||
          before.longitude != after.longitude ||
          before.selected != after.selected ||
          before.regionLabel != after.regionLabel ||
          before.imageAssetPath != after.imageAssetPath ||
          before.actionLabel != after.actionLabel) {
        return true;
      }
    }

    for (var index = 0; index < oldWidget.routeMarkers.length; index++) {
      final before = oldWidget.routeMarkers[index];
      final after = newWidget.routeMarkers[index];
      if (before.id != after.id ||
          before.latitude != after.latitude ||
          before.longitude != after.longitude) {
        return true;
      }
    }

    return false;
  }

  Future<void> _renderMap() async {
    if (!mounted) {
      return;
    }
    final renderVersion = ++_renderVersion;

    if (widget.markers.isEmpty &&
        (widget.initialCenterLatitude == null ||
            widget.initialCenterLongitude == null)) {
      _showMessage(widget.emptyMessage);
      return;
    }

    if (!widget.kakaoEnabled) {
      _showMessage(
        '카카오맵 키가 연결되지 않았습니다. '
        'MAP_PROVIDER=kakao 와 KAKAO_MAP_APP_KEY 값을 확인해 주세요.',
      );
      return;
    }

    try {
      _showOverlay('카카오맵을 불러오는 중입니다.');
      await _ensureSdkLoaded();
      if (!mounted) {
        return;
      }

      final kakaoObject = js.context['kakao'];
      if (kakaoObject == null) {
        _showMessage(
          '카카오맵 SDK를 불러오지 못했습니다. '
          '브라우저 콘솔과 네트워크 상태를 확인해 주세요.',
        );
        return;
      }

      final kakao = kakaoObject as js.JsObject;
      final maps = kakao['maps'] as js.JsObject?;
      if (maps == null) {
        _showMessage(
          '카카오맵 SDK는 로드됐지만 maps 객체를 찾지 못했습니다.',
        );
        return;
      }

      maps.callMethod('load', [
        package_js.allowInterop((_) {
          if (!mounted || renderVersion != _renderVersion) {
            return;
          }
          _buildMap(kakao);
          if (mounted) {
            setState(() {
              _statusMessage = null;
            });
          }
        }),
      ]);
    } catch (error) {
      _showMessage('카카오맵을 표시하는 중 오류가 발생했습니다.\n$error');
    }
  }

  Future<void> _ensureSdkLoaded() {
    _sdkLoader ??= _loadSdk();
    return _sdkLoader!;
  }

  Future<void> _loadSdk() {
    final completer = Completer<void>();
    final existingKakao = js.context['kakao'];
    if (existingKakao != null) {
      completer.complete();
      return completer.future;
    }

    final script = html.ScriptElement()
      ..id = 'travel-support-kakao-sdk'
      ..src =
          'https://dapi.kakao.com/v2/maps/sdk.js?appkey=${const String.fromEnvironment('KAKAO_MAP_APP_KEY')}&autoload=false'
      ..async = true;

    script.onLoad.listen((_) => completer.complete());
    script.onError.listen((_) {
      completer.completeError(StateError('Failed to load Kakao Map SDK'));
    });

    html.document.head?.append(script);
    return completer.future;
  }

  void _buildMap(js.JsObject kakao) {
    if (!mounted) {
      return;
    }
    final maps = kakao['maps'] as js.JsObject;
    final markers = widget.markers;

    _container.children.clear();
    _polyline = null;
    _activeOverlay = null;
    _markerOverlayObjects.clear();
    _mapJsCallbacks.clear();

    final center = js.JsObject(
      maps['LatLng'] as js.JsFunction,
      [
        markers.isNotEmpty
            ? markers.first.latitude
            : widget.initialCenterLatitude ?? 0,
        markers.isNotEmpty
            ? markers.first.longitude
            : widget.initialCenterLongitude ?? 0,
      ],
    );

    final map = js.JsObject(
      maps['Map'] as js.JsFunction,
      [
        _container,
        js.JsObject.jsify({
          'center': center,
          'level': markers.isNotEmpty ? 9 : 5,
        }),
      ],
    );

    final bounds = js.JsObject(maps['LatLngBounds'] as js.JsFunction);
    void openOverlay(
      PlaceMapMarkerData markerData,
      js.JsObject position,
    ) {
      _activeOverlay?.callMethod('setMap', [null]);
      final overlay = js.JsObject(
        maps['CustomOverlay'] as js.JsFunction,
        [
          js.JsObject.jsify({
            'position': position,
            'yAnchor': 1.12,
            'xAnchor': 0.5,
            'clickable': true,
            'content': _buildOverlayContent(markerData),
          }),
        ],
      );
      overlay.callMethod('setMap', [map]);
      _activeOverlay = overlay;
    }

    for (var index = 0; index < markers.length; index++) {
      final markerData = markers[index];

      final position = js.JsObject(
        maps['LatLng'] as js.JsFunction,
        [markerData.latitude, markerData.longitude],
      );
      bounds.callMethod('extend', [position]);
      final markerContent = _buildMarkerContent(
        label: '${index + 1}',
        selected: widget.highlightedMarkerId == markerData.id ||
            markerData.selected,
      );

      void handleMarkerTap() {
        openOverlay(markerData, position);
        _invokeMarkerCallback(
          widget.onMarkerTap,
          markerData.id,
        );
      }

      markerContent.onClick.listen((event) {
        event.preventDefault();
        event.stopPropagation();
        handleMarkerTap();
      });

      final markerOverlay = js.JsObject(
        maps['CustomOverlay'] as js.JsFunction,
        [
          js.JsObject.jsify({
            'position': position,
            'yAnchor': 1,
            'xAnchor': 0.5,
            'clickable': true,
            'content': markerContent,
          }),
        ],
      );
      markerOverlay.callMethod('setMap', [map]);
      _markerOverlayObjects.add(markerOverlay);

      if (widget.highlightedMarkerId != null &&
          widget.highlightedMarkerId == markerData.id) {
        openOverlay(markerData, position);
      }
    }

    _map = map;
    _bounds = bounds;

    if (widget.onViewportChanged != null) {
      final idleCallback = package_js.allowInterop((_) {
        _emitViewportChanged();
      });
      _mapJsCallbacks.add(idleCallback);
      final event = maps['event'] as js.JsObject?;
      event?.callMethod('addListener', [map, 'idle', idleCallback]);
    }

    if (widget.connectSequentially && widget.routeMarkers.length >= 2) {
      try {
        final path = widget.routeMarkers
            .map(
              (point) => js.JsObject(
                maps['LatLng'] as js.JsFunction,
                [point.latitude, point.longitude],
              ),
            )
            .toList(growable: false);

        _polyline = js.JsObject(
          maps['Polyline'] as js.JsFunction,
          [
            js.JsObject.jsify({
              'map': map,
              'path': path,
              'strokeWeight': 4,
              'strokeColor': '#16A34A',
              'strokeOpacity': 0.95,
              'strokeStyle': 'dash',
            }),
          ],
        );
      } catch (_) {
        _polyline = null;
      }
    }

    if (markers.isNotEmpty) {
      map.callMethod('setBounds', [bounds]);
    }
    _emitViewportChanged();
    _scheduleRelayout();
  }

  void _emitViewportChanged() {
    if (!mounted || _map == null || widget.onViewportChanged == null) {
      return;
    }
    try {
      final center = _map!.callMethod('getCenter') as js.JsObject;
      final bounds = _map!.callMethod('getBounds') as js.JsObject;
      final southWest = bounds.callMethod('getSouthWest') as js.JsObject;
      final northEast = bounds.callMethod('getNorthEast') as js.JsObject;

      widget.onViewportChanged!(
        PlaceMapViewport(
          centerLatitude: _jsNumber(center.callMethod('getLat')),
          centerLongitude: _jsNumber(center.callMethod('getLng')),
          minLatitude: _jsNumber(southWest.callMethod('getLat')),
          maxLatitude: _jsNumber(northEast.callMethod('getLat')),
          minLongitude: _jsNumber(southWest.callMethod('getLng')),
          maxLongitude: _jsNumber(northEast.callMethod('getLng')),
        ),
      );
    } catch (_) {
      // Ignore viewport callback failures.
    }
  }

  double _jsNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  html.DivElement _buildOverlayContent(PlaceMapMarkerData marker) {
    final root = html.DivElement()
      ..style.width = '248px'
      ..style.background = '#ffffff'
      ..style.border = '1px solid #dbe4ee'
      ..style.borderRadius = '22px'
      ..style.boxShadow = '0 16px 32px rgba(15, 23, 42, 0.18)'
      ..style.padding = '14px';

    final imageBox = html.DivElement()
      ..style.width = '100%'
      ..style.height = '112px'
      ..style.borderRadius = '16px'
      ..style.overflow = 'hidden'
      ..style.background = '#f8fafc'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.marginBottom = '12px';

    if ((marker.imageAssetPath ?? '').isNotEmpty) {
      imageBox.append(
        html.ImageElement(src: _resolveDomImageSource(marker.imageAssetPath!))
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover',
      );
    } else {
      imageBox.append(
        html.SpanElement()
          ..text = '사진 없음'
          ..style.color = '#94a3b8'
          ..style.fontSize = '13px'
          ..style.fontWeight = '700',
      );
    }

    root.append(imageBox);

    if ((marker.regionLabel ?? '').isNotEmpty) {
      root.append(
        html.SpanElement()
          ..text = marker.regionLabel!
          ..style.display = 'inline-block'
          ..style.padding = '6px 10px'
          ..style.borderRadius = '999px'
          ..style.background = '#e8f7ee'
          ..style.color = '#15803d'
          ..style.fontSize = '12px'
          ..style.fontWeight = '800'
          ..style.marginBottom = '10px',
      );
    }

    root.append(
      html.DivElement()
        ..text = marker.name
        ..style.fontSize = '18px'
        ..style.fontWeight = '900'
        ..style.color = '#0f172a'
        ..style.marginBottom = '8px',
    );

    root.append(
      html.DivElement()
        ..text = marker.address
        ..style.fontSize = '13px'
        ..style.lineHeight = '1.5'
        ..style.color = '#64748b'
        ..style.marginBottom = '10px',
    );

    if ((marker.roadAddress ?? '').isNotEmpty) {
      root.append(
        html.DivElement()
          ..text = '도로명: ${marker.roadAddress!}'
          ..style.fontSize = '12px'
          ..style.lineHeight = '1.5'
          ..style.color = '#475569'
          ..style.marginBottom = '6px',
      );
    }
    if ((marker.phoneNumber ?? '').isNotEmpty) {
      root.append(
        html.DivElement()
          ..text = '전화: ${marker.phoneNumber!}'
          ..style.fontSize = '12px'
          ..style.lineHeight = '1.5'
          ..style.color = '#475569'
          ..style.marginBottom = '6px',
      );
    }
    if ((marker.categoryName ?? '').isNotEmpty) {
      root.append(
        html.DivElement()
          ..text = '분류: ${marker.categoryName!}'
          ..style.fontSize = '12px'
          ..style.lineHeight = '1.5'
          ..style.color = '#475569'
          ..style.marginBottom = '10px',
      );
    }

    if ((marker.placeUrl ?? '').isNotEmpty) {
      root.append(
        html.AnchorElement(href: marker.placeUrl!)
          ..text = '카카오 장소 상세 보기'
          ..target = '_blank'
          ..style.display = 'inline-block'
          ..style.marginBottom = marker.actionLabel == null ? '0' : '14px'
          ..style.color = '#0F766E'
          ..style.fontSize = '12px'
          ..style.fontWeight = '800'
          ..style.textDecoration = 'none',
      );
    }

    if ((marker.actionLabel ?? '').isNotEmpty) {
      final button = html.ButtonElement()
        ..text = marker.actionLabel!
        ..style.width = '100%'
        ..style.height = '46px'
        ..style.border = '0'
        ..style.cursor = 'pointer'
        ..style.borderRadius = '14px'
        ..style.background = '#16a34a'
        ..style.color = '#ffffff'
        ..style.fontSize = '14px'
        ..style.fontWeight = '800';
      button.onClick.listen((event) {
        event.preventDefault();
        event.stopPropagation();
        _invokeMarkerCallback(widget.onMarkerAction, marker.id);
      });
      root.append(button);
    }

    return root;
  }

  String _resolveDomImageSource(String rawPath) {
    if (rawPath.startsWith('http://') ||
        rawPath.startsWith('https://') ||
        rawPath.startsWith('data:')) {
      return rawPath;
    }
    if (rawPath.startsWith('assets/')) {
      return Uri.base.resolve('assets/$rawPath').toString();
    }
    return Uri.base.resolve(rawPath).toString();
  }

  html.DivElement _buildMarkerContent({
    required String label,
    required bool selected,
  }) {
    final root = html.DivElement()
      ..style.width = '42px'
      ..style.height = '54px'
      ..style.cursor = 'pointer'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center';

    root.append(
      html.ImageElement(src: _markerSvg(label: label, selected: selected))
        ..style.width = '42px'
        ..style.height = '54px'
        ..style.display = 'block'
        ..style.pointerEvents = 'none',
    );

    return root;
  }

  String _markerSvg({
    required String label,
    required bool selected,
  }) {
    final fill = selected ? '#16A34A' : '#7C3AED';
    final stroke = selected ? '#166534' : '#6D28D9';
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="42" height="54" viewBox="0 0 42 54">
  <path d="M21 2C10.5066 2 2 10.5066 2 21C2 35.25 21 52 21 52C21 52 40 35.25 40 21C40 10.5066 31.4934 2 21 2Z" fill="$fill" stroke="$stroke" stroke-width="2"/>
  <circle cx="21" cy="21" r="11" fill="white"/>
  <text x="21" y="25" text-anchor="middle" font-size="12" font-weight="700" fill="$fill" font-family="Arial, sans-serif">$label</text>
</svg>
''';
    return 'data:image/svg+xml;charset=UTF-8,${Uri.encodeComponent(svg)}';
  }

  void _scheduleRelayout() {
    _relayoutTimer?.cancel();
    _relayoutTimer = Timer(const Duration(milliseconds: 80), _relayoutMap);
    Timer(const Duration(milliseconds: 250), _relayoutMap);
    Timer(const Duration(milliseconds: 700), _relayoutMap);
  }

  void _relayoutMap() {
    if (!mounted || _map == null) {
      return;
    }
    if (_container.clientWidth == 0 || _container.clientHeight == 0) {
      return;
    }

    try {
      _map!.callMethod('relayout');
      if (_bounds != null) {
        _map!.callMethod('setBounds', [_bounds!]);
      }
    } catch (_) {
      // Retry timers handle temporary layout timing.
    }
  }

  void _showOverlay(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = message;
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }

    _container.children.clear();
    _container.text = '';
    final paragraph = html.ParagraphElement()
      ..text = message
      ..style.margin = '0'
      ..style.padding = '24px'
      ..style.textAlign = 'center'
      ..style.color = '#475569'
      ..style.fontSize = '14px'
      ..style.lineHeight = '1.6'
      ..style.whiteSpace = 'pre-line';
    _container.append(paragraph);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlElementView(viewType: _viewType),
        ),
        if (_statusMessage != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
