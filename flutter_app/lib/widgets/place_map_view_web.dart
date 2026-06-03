// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
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
  final List<Object> _markerOverlayObjects = [];
  final List<Object> _mapJsCallbacks = [];
  int _renderVersion = 0;

  Object? _map;
  Object? _bounds;
  Object? _polyline;
  Object? _activeOverlay;

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

      final kakaoObject = _getWindowProperty('kakao');
      html.window.console.log(
        '[halftrip:kakao] origin=${html.window.location.origin} '
        'kakaoLoaded=${kakaoObject != null}',
      );
      if (kakaoObject == null) {
        _showMessage(
          '카카오맵 SDK를 불러오지 못했습니다. '
          '브라우저 콘솔과 네트워크 상태를 확인해 주세요.',
        );
        return;
      }

      final kakao = kakaoObject;
      final maps = await _waitForMapsObject(kakao);
      if (maps == null) {
        html.window.console.error(
          '[halftrip:kakao] maps object not found. Check Kakao web origin allowlist.',
        );
        _showMessage(
          '카카오맵 SDK는 로드됐지만 maps 객체를 찾지 못했습니다.',
        );
        return;
      }

      if (!mounted || renderVersion != _renderVersion) {
        return;
      }
      final loadFn = _getProperty(maps, 'load');
      html.window.console.log(
        '[halftrip:kakao] mapsFound=true loadFn=${loadFn != null}',
      );
      if (loadFn != null) {
        final loadCallback = package_js.allowInterop(() {
          if (!mounted || renderVersion != _renderVersion) {
            return;
          }
          html.window.console.log('[halftrip:kakao] maps.load callback fired');
          _buildMap(kakao);
          if (mounted) {
            setState(() {
              _statusMessage = null;
            });
          }
        });
        _mapJsCallbacks.add(loadCallback);
        js_util.callMethod(maps, 'load', [loadCallback]);
      } else {
        _buildMap(kakao);
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      }
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
          'https://dapi.kakao.com/v2/maps/sdk.js?appkey=${const String.fromEnvironment('KAKAO_MAP_APP_KEY')}&autoload=false';

    script.onLoad.listen((_) {
      html.window.console.log('[halftrip:kakao] sdk script loaded');
      completer.complete();
    });
    script.onError.listen((_) {
      html.window.console.error('[halftrip:kakao] sdk script failed to load');
      completer.completeError(StateError('Failed to load Kakao Map SDK'));
    });

    html.document.head?.append(script);
    return completer.future;
  }

  void _buildMap(Object kakao) {
    if (!mounted) {
      return;
    }
    final maps = _getProperty(kakao, 'maps');
    final latLngCtor = maps == null ? null : _getProperty(maps, 'LatLng');
    final mapCtor = maps == null ? null : _getProperty(maps, 'Map');
    final boundsCtor = maps == null ? null : _getProperty(maps, 'LatLngBounds');
    final overlayCtor = maps == null ? null : _getProperty(maps, 'CustomOverlay');
    final polylineCtor = maps == null ? null : _getProperty(maps, 'Polyline');
    if (maps == null ||
        latLngCtor == null ||
        mapCtor == null ||
        boundsCtor == null ||
        overlayCtor == null) {
      html.window.console.error(
        '[halftrip:kakao] constructor missing '
        'maps=${maps != null} latLng=${latLngCtor != null} map=${mapCtor != null} '
        'bounds=${boundsCtor != null} overlay=${overlayCtor != null} polyline=${polylineCtor != null}',
      );
      _showMessage('Kakao map object initialization failed.');
      return;
    }
    final markers = widget.markers;

    _container.children.clear();
    _polyline = null;
    _activeOverlay = null;
    _markerOverlayObjects.clear();
    _mapJsCallbacks.clear();

    final center = js_util.callConstructor(
      latLngCtor,
      [
        markers.isNotEmpty
            ? markers.first.latitude
            : widget.initialCenterLatitude ?? 0,
        markers.isNotEmpty
            ? markers.first.longitude
            : widget.initialCenterLongitude ?? 0,
      ],
    );

    final map = js_util.callConstructor(
      mapCtor,
      [
        _container,
        js_util.jsify({
          'center': center,
          'level': markers.isNotEmpty ? 9 : 2,
        }),
      ],
    );

    final bounds = js_util.callConstructor(boundsCtor, const []);
    void openOverlay(
      PlaceMapMarkerData markerData,
      Object position,
    ) {
      _callMethod(_activeOverlay, 'setMap', [null]);
      final overlay = js_util.callConstructor(
        overlayCtor,
        [
          js_util.jsify({
            'position': position,
            'yAnchor': 1.12,
            'xAnchor': 0.5,
            'clickable': true,
            'content': _buildOverlayContent(markerData),
          }),
        ],
      );
      _callMethod(overlay, 'setMap', [map]);
      _activeOverlay = overlay;
    }

    for (var index = 0; index < markers.length; index++) {
      final markerData = markers[index];

      final position = js_util.callConstructor(
        latLngCtor,
        [markerData.latitude, markerData.longitude],
      );
      _callMethod(bounds, 'extend', [position]);
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

      final markerOverlay = js_util.callConstructor(
        overlayCtor,
        [
          js_util.jsify({
            'position': position,
            'yAnchor': 1,
            'xAnchor': 0.5,
            'clickable': true,
            'content': markerContent,
          }),
        ],
      );
      _callMethod(markerOverlay, 'setMap', [map]);
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
      final event = _getProperty(maps, 'event');
      _callMethod(event, 'addListener', [map, 'idle', idleCallback]);
    }

    if (widget.connectSequentially &&
        widget.routeMarkers.length >= 2 &&
        polylineCtor != null) {
      try {
        final path = widget.routeMarkers
            .map(
              (point) => js_util.callConstructor(
                latLngCtor,
                [point.latitude, point.longitude],
              ),
            )
            .toList(growable: false);

        _polyline = js_util.callConstructor(
          polylineCtor,
          [
            js_util.jsify({
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
      _callMethod(map, 'setBounds', [bounds]);
    }
    _emitViewportChanged();
    _scheduleRelayout();
  }

  void _emitViewportChanged() {
    if (!mounted || _map == null || widget.onViewportChanged == null) {
      return;
    }
    try {
      final center = _callMethod(_map, 'getCenter');
      final bounds = _callMethod(_map, 'getBounds');
      final southWest = _callMethod(bounds, 'getSouthWest');
      final northEast = _callMethod(bounds, 'getNorthEast');
      if (center == null || bounds == null || southWest == null || northEast == null) {
        return;
      }

      widget.onViewportChanged!(
        PlaceMapViewport(
          centerLatitude: _jsNumber(_callMethod(center, 'getLat')),
          centerLongitude: _jsNumber(_callMethod(center, 'getLng')),
          minLatitude: _jsNumber(_callMethod(southWest, 'getLat')),
          maxLatitude: _jsNumber(_callMethod(northEast, 'getLat')),
          minLongitude: _jsNumber(_callMethod(southWest, 'getLng')),
          maxLongitude: _jsNumber(_callMethod(northEast, 'getLng')),
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

  Object? _getProperty(Object? target, String property) {
    if (target == null) {
      return null;
    }
    try {
      return js_util.getProperty(target, property);
    } catch (_) {
      return null;
    }
  }

  Object? _callMethod(Object? target, String method, [List<dynamic> args = const []]) {
    if (target == null) {
      return null;
    }
    try {
      return js_util.callMethod(target, method, args);
    } catch (_) {
      return null;
    }
  }

  Object? _getWindowProperty(String property) {
    try {
      return js_util.getProperty(html.window, property);
    } catch (_) {
      return null;
    }
  }

  Object? _resolveMapsObject(Object? kakaoObject) {
    if (kakaoObject == null) {
      return null;
    }
    try {
      if (kakaoObject is js.JsObject) {
        final viaIndex = kakaoObject['maps'];
        if (viaIndex != null) {
          return viaIndex;
        }
      }
    } catch (_) {
      // ignore and try generic property access
    }
    return _getProperty(kakaoObject, 'maps');
  }

  Future<Object?> _waitForMapsObject(Object kakaoObject) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final maps = _resolveMapsObject(kakaoObject);
      if (maps != null) {
        if (attempt > 0) {
          html.window.console.log(
            '[halftrip:kakao] maps became available after retry=$attempt',
          );
        }
        return maps;
      }
      if (attempt == 0) {
        html.window.console.warn(
          '[halftrip:kakao] maps missing after first lookup. Retrying...',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
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
      _callMethod(_map, 'relayout');
      if (_bounds != null) {
        _callMethod(_map, 'setBounds', [_bounds!]);
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
