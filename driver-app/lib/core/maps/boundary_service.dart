/// Point-in-polygon boundary enforcement for the service area.
/// Handles both {lat/lng} map format and [lat, lng] list format.
class BoundaryService {
  BoundaryService._();

  /// Returns true when the point is allowed to be used (either enforcement is
  /// off, the boundary is empty, or the point falls inside the polygon).
  static bool isAllowed({
    required double lat,
    required double lng,
    required List<dynamic> boundary,
    required bool enforcement,
  }) {
    if (!enforcement || boundary.isEmpty) return true;
    return _insidePolygon(lat, lng, boundary);
  }

  // Ray-casting algorithm — O(n), works for any simple polygon.
  static bool _insidePolygon(double lat, double lng, List<dynamic> poly) {
    bool inside = false;
    final n = poly.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final a = _point(poly[i]);
      final b = _point(poly[j]);
      if (a == null || b == null) continue;
      if (((a.lng > lng) != (b.lng > lng)) &&
          lat < (b.lat - a.lat) * (lng - a.lng) / (b.lng - a.lng) + a.lat) {
        inside = !inside;
      }
    }
    return inside;
  }

  static _LL? _point(dynamic raw) {
    if (raw is Map) {
      final lat = raw['lat'] ?? raw['latitude'];
      final lng = raw['lng'] ?? raw['longitude'];
      if (lat == null || lng == null) return null;
      return _LL((lat as num).toDouble(), (lng as num).toDouble());
    }
    if (raw is List && raw.length >= 2) {
      return _LL((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    }
    return null;
  }
}

class _LL {
  const _LL(this.lat, this.lng);
  final double lat;
  final double lng;
}
