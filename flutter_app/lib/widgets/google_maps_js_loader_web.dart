// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js' as js;

Completer<bool>? _loading;

/// google_maps_flutter_web이 요구하는 `google.maps` JS를 dart-define 키로 1회 주입.
/// index.html에 키를 박지 않기 위한 런타임 로더.
Future<bool> ensureGoogleMapsJs(String apiKey) {
  if (_loading != null) return _loading!.future;
  final completer = _loading = Completer<bool>();
  if (js.context.hasProperty('google') &&
      (js.context['google'] as js.JsObject?)?.hasProperty('maps') == true) {
    completer.complete(true);
    return completer.future;
  }
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true;
  script.onLoad.listen((_) => completer.complete(true));
  script.onError.listen((_) => completer.complete(false));
  html.document.head!.append(script);
  return completer.future;
}
