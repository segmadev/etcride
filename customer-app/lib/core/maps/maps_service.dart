import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final data = await _c.get<Map<String, dynamic>>(
        ApiEndpoints.geocode,
        params: {'latlng': '$lat,$lng'},
      );
      final results = data?['results'] as List?;
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

  /// Decodes a Google Maps encoded polyline string into a list of [LatLng].
  static List<LatLng> decodePolyline(String encoded) {
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

      result.add(LatLng(lat / 1e5, lng / 1e5));
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
