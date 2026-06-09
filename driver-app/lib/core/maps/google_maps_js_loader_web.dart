import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<bool> ensureGoogleMapsJsLoaded({required String apiKey}) async {
  if (apiKey.trim().isEmpty) return false;

  if (_hasGoogleMaps()) return true;

  final existing = web.document.querySelector('script[data-etc="gmaps"]');
  if (existing != null) {
    await _waitForMaps();
    return true;
  }

  final script = web.HTMLScriptElement()
    ..type = 'text/javascript'
    ..async = true
    ..defer = true
    ..setAttribute('data-etc', 'gmaps')
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places&v=weekly';

  final c = Completer<void>();
  script.addEventListener(
    'error',
    ((web.Event _) {
      if (!c.isCompleted) c.completeError(StateError('Failed to load Google Maps JS'));
    }).toJS,
  );
  script.addEventListener(
    'load',
    ((web.Event _) {
      if (!c.isCompleted) c.complete();
    }).toJS,
  );

  web.document.head?.append(script);

  try {
    await c.future.timeout(const Duration(seconds: 15));
  } catch (_) {
    return false;
  }

  try {
    await _waitForMaps();
    return true;
  } catch (_) {
    return false;
  }
}

bool _hasGoogleMaps() {
  final g = (web.window as JSObject).getProperty('google'.toJS);
  if (g == null) return false;
  final maps = (g as JSObject).getProperty('maps'.toJS);
  if (maps == null) return false;
  final mapTypeId = (maps as JSObject).getProperty('MapTypeId'.toJS);
  return mapTypeId != null;
}

Future<void> _waitForMaps() async {
  final start = DateTime.now();
  while (true) {
    if (_hasGoogleMaps()) return;
    if (DateTime.now().difference(start) > const Duration(seconds: 15)) {
      throw TimeoutException('google.maps not ready');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
