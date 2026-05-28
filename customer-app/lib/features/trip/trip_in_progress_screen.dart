import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/maps/google_maps_js_loader.dart';
import '../../../core/maps/maps_service.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/driver_card.dart';
import '../../../shared/widgets/trip_quick_nav.dart';

class TripInProgressScreen extends ConsumerStatefulWidget {
  const TripInProgressScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripInProgressScreen> createState() =>
      _TripInProgressScreenState();
}

class _TripInProgressScreenState
    extends ConsumerState<TripInProgressScreen> {
  BookingModel? _booking;
  Timer? _pollTimer;
  Timer? _driverAnimTimer;
  GoogleMapController? _mapCtrl;
  int _mapVersion = 0;

  List<LatLng>  _routePoints = [];
  bool          _routeLoaded = false;
  LatLngBounds? _routeBounds;
  String?       _routePolylineUsed;

  LatLng? _driverPos;
  double  _driverRotation = 0;

  static const _defaultCenter = LatLng(8.4966, 4.5421);

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
      _fetchRoute(b);
      _loadTrack(b);

      if (b.status == BookingStatus.paymentPending ||
          b.status == BookingStatus.completed) {
        _pollTimer?.cancel();
        context.go(AppRoutes.payment, extra: widget.bookingId);
      } else if (b.status == BookingStatus.cancelled) {
        _pollTimer?.cancel();
        ref.invalidate(activeBookingProvider('ride'));
        ref.invalidate(activeBookingProvider('delivery'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip was cancelled.'), backgroundColor: AppColors.error),
          );
          context.go(AppRoutes.home);
        }
      } else if (b.status == BookingStatus.paid) {
        _pollTimer?.cancel();
        context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
      }
    } catch (_) {}
  }

  void _fetchRoute(BookingModel b) {
    if (b.pickupLat == 0 || b.destinationLat == 0) return;

    final encoded = (b.routePolyline ?? '').trim();
    if (_routeLoaded && (encoded.isEmpty || encoded == _routePolylineUsed)) return;
    final fallbackPts = [
      LatLng(b.pickupLat, b.pickupLng),
      LatLng(b.destinationLat, b.destinationLng),
    ];
    final points = encoded.isNotEmpty
        ? MapsService.decodePolylineBest(
            encoded,
            origin: fallbackPts.first,
            destination: fallbackPts.last,
          )
        : fallbackPts;
    if (encoded.isNotEmpty && !_routeLooksValid(points, fallbackPts.first, fallbackPts.last)) {
      return;
    }
    setState(() {
      _routePoints = points.length >= 2 ? points : fallbackPts;
      _routeBounds = MapsService.boundsFromPoints(_routePoints);
      _routeLoaded = true;
      _routePolylineUsed = encoded.isNotEmpty ? encoded : _routePolylineUsed;
    });
    _fitRoute();
  }

  Future<void> _loadTrack(BookingModel b) async {
    if (b.driverId == null) return;
    try {
      final t = await ref.read(bookingRepositoryProvider).trackBooking(widget.bookingId);
      if (!mounted) return;
      final lat = t.lat;
      final lng = t.lng;
      if (lat == null || lng == null) return;
      _animateDriverTo(LatLng(lat, lng));
    } catch (_) {}
  }

  void _animateDriverTo(LatLng next) {
    final prev = _driverPos;
    if (prev == null) {
      setState(() => _driverPos = next);
      return;
    }

    final rotation = _bearingDegrees(prev, next);
    _driverAnimTimer?.cancel();

    const steps = 20;
    var i = 0;
    _driverAnimTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      i++;
      final f = i / steps;
      final pos = LatLng(
        prev.latitude + (next.latitude - prev.latitude) * f,
        prev.longitude + (next.longitude - prev.longitude) * f,
      );
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _driverPos = pos;
        _driverRotation = rotation;
      });
      if (i >= steps) t.cancel();
    });
  }

  double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lat2 = _degToRad(to.latitude);
    final dLon = _degToRad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  double _degToRad(double d) => d * math.pi / 180;

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h = s1 * s1 + math.cos(lat1) * math.cos(lat2) * s2 * s2;
    return r * 2 * math.asin(math.sqrt(h));
  }

  bool _routeLooksValid(List<LatLng> pts, LatLng origin, LatLng dest) {
    if (pts.length < 2) return false;
    final a = pts.first;
    final b = pts.last;
    final s1 = _haversineKm(origin, a) + _haversineKm(dest, b);
    final s2 = _haversineKm(origin, b) + _haversineKm(dest, a);
    return (s1 < 2.0) || (s2 < 2.0);
  }

  void _fitRoute() {
    final bounds = _routeBounds;
    if (bounds == null) return;
    final spanLat = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final spanLng = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
    if (spanLat > 1.5 || spanLng > 1.5) return;
    final version = _mapVersion;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (version != _mapVersion) return;
      try {
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } catch (_) {
        _mapCtrl = null;
      }
    });
  }

  Set<Marker> get _markers {
    final b = _booking;
    if (b == null) return {};
    return {
      if (b.pickupLat != 0)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(b.pickupLat, b.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup', snippet: b.pickupAddress),
        ),
      if (b.destinationLat != 0)
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(b.destinationLat, b.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
              title: 'Destination', snippet: b.destinationAddress),
        ),
      if (_driverPos != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          rotation: _driverRotation,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
    };
  }

  Set<Polyline> get _polylines => _routePoints.length >= 2
      ? {
          Polyline(
            polylineId: const PolylineId('route'),
            points:     _routePoints,
            color:      AppColors.primary,
            width:      5,
            jointType:  JointType.round,
            startCap:   Cap.roundCap,
            endCap:     Cap.roundCap,
          ),
        }
      : {};

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driverAnimTimer?.cancel();
    _mapVersion++;
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b      = _booking;
    final mapKey = ref.watch(mapApiKeyProvider);

    final initialPos = b != null && b.destinationLat != 0
        ? LatLng(b.destinationLat, b.destinationLng)
        : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map with full route ───────────────────────────────────────────
          _RoutedTripMap(
            initialPos: initialPos,
            apiKey:     mapKey,
            markers:    _markers,
            polylines:  _polylines,
            onMapCreated: (c) {
              _mapCtrl = c;
              _mapVersion++;
              if (_routeBounds != null) _fitRoute();
            },
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  MapOverlayButton(
                    icon: Icons.menu_rounded,
                    iconWidget: SvgPicture.asset(
                      AppAssets.menuIcon,
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                    ),
                    onTap: () => _showTripMenu(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(AppStrings.headingToDestination,
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.white)),
                          const Spacer(),
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom driver card ────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: b == null
                ? Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  )
                : DriverCard(
                    booking: b,
                    statusIcon: const Icon(Icons.navigation_rounded,
                        size: 16, color: AppColors.primary),
                    statusLabel: 'Heading to destination',
                  ),
          ),
        ],
      ),
    );
  }
}

void _showTripMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripInProgressMenu(parentContext: context),
  );
}

class _TripInProgressMenu extends StatelessWidget {
  const _TripInProgressMenu({required this.parentContext});
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    void nav(String route) {
      Navigator.pop(context);
      parentContext.go(route);
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 8, 0, MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: _EmbeddedPngFromSvgAsset(
                        assetPath: AppAssets.carIcon,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Trip in Progress',
                    style: AppTextStyles.h4),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history_rounded,
                size: 22, color: AppColors.textPrimary),
            title: Text('My Trip History',
                style: AppTextStyles.bodyLarge),
            onTap: () => nav(AppRoutes.tripHistory),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded,
                size: 22, color: AppColors.textPrimary),
            title: Text('Help & Support', style: AppTextStyles.bodyLarge),
            onTap: () => nav(AppRoutes.help),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.color,
  });

  final String assetPath;
  final Color? color;

  static final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> _load() {
    return _cache.putIfAbsent(assetPath, () async {
      final svg = await rootBundle.loadString(assetPath);
      final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
      if (match == null) throw const FormatException('No embedded PNG found.');
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Image.memory(
          snap.data!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          color: color,
          colorBlendMode: BlendMode.srcIn,
        );
      },
    );
  }
}

// ── Stable map view ───────────────────────────────────────────────────────────

class _RoutedTripMap extends StatefulWidget {
  const _RoutedTripMap({
    required this.initialPos,
    required this.apiKey,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
  });
  final LatLng initialPos;
  final String apiKey;
  final Set<Marker>   markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController) onMapCreated;

  @override
  State<_RoutedTripMap> createState() => _RoutedTripMapState();
}

class _RoutedTripMapState extends State<_RoutedTripMap> {
  late Set<Marker>   _m;
  late Set<Polyline> _p;

  @override
  void initState() { super.initState(); _m = widget.markers; _p = widget.polylines; }

  @override
  void didUpdateWidget(_RoutedTripMap old) {
    super.didUpdateWidget(old);
    final mc = _hm(old.markers)   != _hm(widget.markers);
    final pc = _hp(old.polylines) != _hp(widget.polylines);
    if (mc || pc) setState(() { _m = widget.markers; _p = widget.polylines; });
  }

  String _hm(Set<Marker> s) => s.map((x) =>
      '${x.markerId.value}:${x.position.latitude.toStringAsFixed(5)}').join('|');
  String _hp(Set<Polyline> s) =>
      s.map((x) => '${x.polylineId.value}:${x.points.length}').join('|');

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<bool>(
        future: ensureGoogleMapsJsLoaded(apiKey: widget.apiKey),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done || snap.data != true) {
            return Container(color: AppColors.surface,
                child: const Center(child: CircularProgressIndicator()));
          }
          return _map();
        },
      );
    }
    return _map();
  }

  Widget _map() => GoogleMap(
        initialCameraPosition:
            CameraPosition(target: widget.initialPos, zoom: 14),
        markers:                 _m,
        polylines:               _p,
        myLocationEnabled:       true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled:     false,
        mapToolbarEnabled:       false,
        onMapCreated:            widget.onMapCreated,
      );
}
