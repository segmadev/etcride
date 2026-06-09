import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/repositories/driver_repository.dart';

/// Manages periodic GPS pings while the driver is online.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _tag = '[LocationService]';

  Timer?            _timer;
  DriverRepository? _repo;
  Position?         _lastPosition;

  final ValueNotifier<Position?> positionNotifier = ValueNotifier(null);

  bool get isTracking => _timer?.isActive == true;
  Position? get lastPosition => _lastPosition;

  // ── Public API ───────────────────────────────────────────────────────────────

  Future<void> start(DriverRepository repo) async {
    debugPrint('$_tag start() called — kIsWeb=$kIsWeb, checking permission');
    _repo = repo;
    final granted = await _ensurePermission();
    debugPrint('$_tag start() permission granted=$granted');
    if (!granted) return;

    _timer?.cancel();
    await _ping();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
    debugPrint('$_tag start() timer running, pinging every 30 s');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('$_tag stop() — timer cancelled');
  }

  Future<void> refreshPosition() async {
    debugPrint('$_tag refreshPosition() called, kIsWeb=$kIsWeb');

    final granted = await _ensurePermission();
    debugPrint('$_tag refreshPosition() permission granted=$granted');
    if (!granted) return;

    // On web, getLastKnownPosition() is not supported — skip straight to fresh fix.
    if (!kIsWeb) {
      try {
        debugPrint('$_tag getLastKnownPosition() starting…');
        final last = await Geolocator.getLastKnownPosition();
        debugPrint('$_tag getLastKnownPosition() → ${last == null ? "null" : "${last.latitude}, ${last.longitude}"}');
        if (last != null) {
          _lastPosition          = last;
          positionNotifier.value = last;
          debugPrint('$_tag positionNotifier updated with last-known fix');
        }
      } catch (e, st) {
        debugPrint('$_tag getLastKnownPosition() threw: $e\n$st');
      }
    }

    // Fresh high-accuracy fix (no artificial timeout — let the OS/browser decide).
    try {
      debugPrint('$_tag getCurrentPosition() starting…');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint('$_tag getCurrentPosition() → ${pos.latitude}, ${pos.longitude}  acc=${pos.accuracy}m');
      _lastPosition          = pos;
      positionNotifier.value = pos;
      if (isTracking && _repo != null) {
        debugPrint('$_tag pinging server with fresh position…');
        await _repo!.pingLocation(pos.latitude, pos.longitude);
        debugPrint('$_tag server ping complete');
      }
    } catch (e, st) {
      debugPrint('$_tag getCurrentPosition() threw: $e\n$st');
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────────────

  Future<bool> _ensurePermission() async {
    // On native platforms, also check the GPS hardware switch.
    if (!kIsWeb) {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('$_tag _ensurePermission() locationServiceEnabled=$svcEnabled');
      if (!svcEnabled) return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    debugPrint('$_tag _ensurePermission() checkPermission=$perm');

    if (perm == LocationPermission.denied) {
      debugPrint('$_tag _ensurePermission() requesting permission…');
      perm = await Geolocator.requestPermission();
      debugPrint('$_tag _ensurePermission() after request=$perm');
    }

    final ok = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    debugPrint('$_tag _ensurePermission() → granted=$ok (perm=$perm)');
    return ok;
  }

  Future<void> _ping() async {
    if (_repo == null) {
      debugPrint('$_tag _ping() skipped — _repo is null');
      return;
    }
    debugPrint('$_tag _ping() starting…');
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint('$_tag _ping() got fix: ${pos.latitude}, ${pos.longitude}');
      _lastPosition          = pos;
      positionNotifier.value = pos;
      await _repo!.pingLocation(pos.latitude, pos.longitude);
      debugPrint('$_tag _ping() server updated');
    } catch (e, st) {
      debugPrint('$_tag _ping() threw: $e\n$st');
    }
  }
}
