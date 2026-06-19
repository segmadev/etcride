import 'dart:math' as math;
import 'package:dio/dio.dart' show Dio;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Calls Google Maps APIs through the backend proxy.
/// - No direct browser requests → no CORS errors.
/// - API key stays on the server → not exposed in client logs or network tab.
class MapsService {
  MapsService._();

  static ApiClient get _c => ApiClient.instance;

  // ── Places Autocomplete ─────────────────────────────────────────────────────

  static Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? sessionToken,
  }) async {
    if (query.trim().isEmpty) return const [];
    try {
      final data = await _c.get<Map<String, dynamic>>(
        ApiEndpoints.placesAutocomplete,
        params: {
          'input': query,
          if (sessionToken != null) 'sessiontoken': sessionToken,
        },
      );
      final predictions = data?['predictions'] as List?;
      if (predictions == null) return const [];
      return predictions
          .cast<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Place Details: placeId → LatLng ─────────────────────────────────────────

  static Future<({double lat, double lng})?> placeDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    if (placeId.isEmpty) return null;
    try {
      final data = await _c.get<Map<String, dynamic>>(
        ApiEndpoints.placeDetails,
        params: {
          'place_id': placeId,
          if (sessionToken != null) 'sessiontoken': sessionToken,
        },
      );
      final loc = (data?['result'] as Map?)?['geometry']?['location'];
      if (loc == null) return null;
      return (
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Reverse geocoding: LatLng → address string ──────────────────────────────
  //
  // Strategy:
  //   • Web    → call Google Maps REST API directly from the browser.
  //              Backend proxy fails in dev (XAMPP has no internet access).
  //   • Native → OS geocoder via `geocoding` package (no API key, no server).
  //              Falls back to direct Google API call if OS geocoder fails.

  static Future<String?> reverseGeocode(double lat, double lng) async {
    if (kIsWeb) return _reverseGeocodeGoogleApi(lat, lng);
    return _reverseGeocodeNative(lat, lng);
  }

  static Future<String?> _reverseGeocodeNative(double lat, double lng) async {
    try {
      final marks = await geo.placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return _reverseGeocodeGoogleApi(lat, lng);
      final p = marks.first;
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty && p.name != p.street) p.name!,
        if ((p.street ?? '').isNotEmpty) p.street!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      if (parts.isEmpty) return _reverseGeocodeGoogleApi(lat, lng);
      return parts.join(', ');
    } catch (_) {
      return _reverseGeocodeGoogleApi(lat, lng);
    }
  }

  static Future<String?> _reverseGeocodeGoogleApi(double lat, double lng) async {
    final key = AppConfig.googleMapsKey;
    if (key.isEmpty) return null;
    try {
      final resp = await Dio().get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '$lat,$lng', 'key': key},
      );
      final results = resp.data?['results'] as List?;
      if (results == null || results.isEmpty) return null;
      for (final r in results) {
        final types = (r['types'] as List?)?.cast<String>() ?? [];
        if (types.contains('street_address') ||
            types.contains('premise') ||
            types.contains('route')) {
          return r['formatted_address'] as String?;
        }
      }
      return (results.first as Map)['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Forward geocoding: address → LatLng ─────────────────────────────────────

  static Future<({double lat, double lng, String formattedAddress})?> geocode(
    String address,
  ) async {
    if (address.trim().isEmpty) return null;
    try {
      final data = await _c.get<Map<String, dynamic>>(
        ApiEndpoints.geocode,
        params: {'address': address},
      );
      final results = data?['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final loc       = (results.first as Map)['geometry']['location'];
      final formatted = (results.first as Map)['formatted_address'] as String? ?? address;
      return (
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
        formattedAddress: formatted,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Directions: origin → destination route polyline ────────────────────────
  //
  // Returns real road points from Google Directions API via the backend proxy.
  // Falls back silently to a straight [origin, destination] line on any error.

  static Future<List<LatLng>> getDirectionsRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final data = await _c.get<Map<String, dynamic>>(
        ApiEndpoints.directions,
        params: {
          'origin':      '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
        },
      );
      final polyline = data?['polyline'] as String? ?? '';
      debugPrint('[MapsService.directions] polyline.length=${polyline.length}  data=$data');
      if (polyline.isEmpty) return [origin, destination];
      return decodePolyline(polyline);
    } catch (e, st) {
      debugPrint('[MapsService.directions] error: $e\n$st');
      return [origin, destination];
    }
  }

  static LatLngBounds? boundsFromPoints(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    var minLat = pts.first.latitude,  maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = _sin2(dLat / 2) + math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * _sin2(dLng / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double _toRad(double d) => d * math.pi / 180;
  static double _sin2(double x) { final s = math.sin(x); return s * s; }

  static List<LatLng> decodePolylineBest(
    String encoded, {
    LatLng? origin,
    LatLng? destination,
  }) {
    final pts5 = _decodePolyline(encoded, 1e5);
    if (origin == null || destination == null) return pts5;
    final pts6 = _decodePolyline(encoded, 1e6);

    double score(List<LatLng> pts) {
      if (pts.length < 2) return double.infinity;
      final a = pts.first;
      final b = pts.last;
      final s1 = _haversineKm(origin.latitude, origin.longitude, a.latitude, a.longitude) +
          _haversineKm(destination.latitude, destination.longitude, b.latitude, b.longitude);
      final s2 = _haversineKm(origin.latitude, origin.longitude, b.latitude, b.longitude) +
          _haversineKm(destination.latitude, destination.longitude, a.latitude, a.longitude);
      return math.min(s1, s2);
    }

    final s5 = score(pts5);
    final s6 = score(pts6);
    if (s6 + 0.05 < s5) return pts6;
    return pts5;
  }

  static List<LatLng> decodePolyline(String encoded) {
    return _decodePolyline(encoded, 1e5);
  }

  static List<LatLng> _decodePolyline(String encoded, double div) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, b = 0, result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

      result.add(LatLng(lat / div, lng / div));
    }
    return result;
  }
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final sf = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlaceSuggestion(
      placeId:       json['place_id']?.toString() ?? '',
      mainText:      sf['main_text']?.toString() ?? json['description']?.toString() ?? '',
      secondaryText: sf['secondary_text']?.toString() ?? '',
      fullText:      json['description']?.toString() ?? '',
    );
  }
}
