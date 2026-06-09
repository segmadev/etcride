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
  Timer?        _pollTimer;

  // Raw driver GPS from each poll — passed to the map widget which handles
  // animation internally (avoids 25fps parent rebuilds that cause blink).
  LatLng? _driverTarget;

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

  Future<void> _loadTrack(BookingModel b) async {
    if (b.driverId == null) return;
    try {
      final t = await ref.read(bookingRepositoryProvider).trackBooking(widget.bookingId);
      if (!mounted) return;
      final lat = t.lat;
      final lng = t.lng;
      if (lat == null || lng == null) return;
      final next = LatLng(lat, lng);
      if (_driverTarget?.latitude  != next.latitude ||
          _driverTarget?.longitude != next.longitude) {
        setState(() => _driverTarget = next);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b      = _booking;
    final mapKey = ref.watch(mapApiKeyProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map — self-contained (owns route + animation + JS loader) ─────
          _RoutedTripMap(
            booking:      b,
            apiKey:       mapKey,
            driverTarget: _driverTarget,
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

// ── Trip map — self-contained: owns route, animation, JS-loader future ────────

class _RoutedTripMap extends StatefulWidget {
  const _RoutedTripMap({
    required this.booking,
    required this.apiKey,
    required this.driverTarget,
  });
  final BookingModel? booking;
  final String        apiKey;
  final LatLng?       driverTarget;

  @override
  State<_RoutedTripMap> createState() => _RoutedTripMapState();
}

class _RoutedTripMapState extends State<_RoutedTripMap> {
  // Cached so FutureBuilder never sees a new Future instance → no blink
  Future<bool>? _loadFuture;

  GoogleMapController? _ctrl;
  int _camVersion = 0;

  List<LatLng>  _routePts    = [];
  bool          _routeLoaded = false;
  String?       _polyUsed;
  LatLngBounds? _routeBounds;

  LatLng? _driverPos;
  double  _driverRot = 0;
  Timer?  _animTimer;

  static const _kDefaultCenter = LatLng(8.4966, 4.5421);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _loadFuture = ensureGoogleMapsJsLoaded(apiKey: widget.apiKey);
    _buildRoute(widget.booking);
    if (widget.driverTarget != null) _driverPos = widget.driverTarget;
  }

  @override
  void didUpdateWidget(_RoutedTripMap old) {
    super.didUpdateWidget(old);
    final b = widget.booking;
    if (b?.id != old.booking?.id || b?.routePolyline != old.booking?.routePolyline) {
      _buildRoute(b);
    }
    final t = widget.driverTarget;
    if (t != null && t != old.driverTarget) _animateDriverTo(t);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _ctrl?.dispose();
    _ctrl = null;
    super.dispose();
  }

  // ── Route ────────────────────────────────────────────────────────────────────

  void _buildRoute(BookingModel? b) {
    if (b == null || b.pickupLat == 0 || b.destinationLat == 0) return;
    final encoded = (b.routePolyline ?? '').trim();
    if (_routeLoaded && (encoded.isEmpty || encoded == _polyUsed)) return;

    final pickup = LatLng(b.pickupLat, b.pickupLng);
    final dest   = LatLng(b.destinationLat, b.destinationLng);
    final pts    = encoded.isNotEmpty
        ? MapsService.decodePolylineBest(encoded, origin: pickup, destination: dest)
        : [pickup, dest];

    if (encoded.isNotEmpty && !_routeValid(pts, pickup, dest)) return;
    final route = pts.length >= 2 ? pts : [pickup, dest];
    final allPts = <LatLng>[...route, if (_driverPos != null) _driverPos!];

    setState(() {
      _routePts    = route;
      _routeBounds = MapsService.boundsFromPoints(allPts);
      _routeLoaded = true;
      if (encoded.isNotEmpty) _polyUsed = encoded;
    });
    _fitCamera();
  }

  bool _routeValid(List<LatLng> pts, LatLng origin, LatLng dest) {
    if (pts.length < 2) return false;
    double hav(LatLng a, LatLng b) {
      const r = 6371.0;
      final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
      final dLng = (b.longitude - a.longitude) * math.pi / 180;
      final lat1 = a.latitude * math.pi / 180;
      final lat2 = b.latitude * math.pi / 180;
      final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
      return r * 2 * math.asin(math.sqrt(s1 * s1 + math.cos(lat1) * math.cos(lat2) * s2 * s2));
    }
    return hav(origin, pts.first) + hav(dest, pts.last) < 2.0 ||
           hav(origin, pts.last)  + hav(dest, pts.first) < 2.0;
  }

  void _fitCamera() {
    if (!mounted || _ctrl == null || _routeBounds == null) return;
    final b = _routeBounds!;
    if ((b.northeast.latitude  - b.southwest.latitude).abs()  > 1.5) return;
    if ((b.northeast.longitude - b.southwest.longitude).abs() > 1.5) return;
    final v = ++_camVersion;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _ctrl == null || v != _camVersion) return;
      try { _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(b, 80)); }
      catch (_) { _ctrl = null; }
    });
  }

  // ── Driver animation ─────────────────────────────────────────────────────────

  void _animateDriverTo(LatLng target) {
    final from = _driverPos ?? target;
    if (from == target) return;
    _driverRot = _bearing(from, target);
    _animTimer?.cancel();
    const steps = 20;
    var i = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      final f = (i / steps).clamp(0.0, 1.0);
      setState(() => _driverPos = LatLng(
        from.latitude  + (target.latitude  - from.latitude)  * f,
        from.longitude + (target.longitude - from.longitude) * f,
      ));
      if (i >= steps) t.cancel();
    });
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLng = (to.longitude  - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Markers & polylines ──────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final b = widget.booking;
    if (b == null) return {};
    return {
      if (b.pickupLat != 0)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(b.pickupLat, b.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup', snippet: b.pickupAddress),
        ),
      if (b.destinationLat != 0)
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(b.destinationLat, b.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: b.destinationAddress),
        ),
      if (_driverPos != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          rotation: _driverRot,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
    };
  }

  Set<Polyline> get _polylines {
    if (_routePts.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points:     _routePts,
        color:      AppColors.primary,
        width:      5,
        jointType:  JointType.round,
        startCap:   Cap.roundCap,
        endCap:     Cap.roundCap,
      ),
    };
  }

  LatLng get _initialTarget {
    final b = widget.booking;
    if (b != null && b.destinationLat != 0) return LatLng(b.destinationLat, b.destinationLng);
    if (_driverPos != null) return _driverPos!;
    return _kDefaultCenter;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return _map();
    return FutureBuilder<bool>(
      future: _loadFuture, // stable — never triggers re-flash
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data != true) {
          return Container(color: AppColors.surface,
              child: const Center(child: CircularProgressIndicator()));
        }
        return _map();
      },
    );
  }

  Widget _map() => GoogleMap(
        initialCameraPosition: CameraPosition(target: _initialTarget, zoom: 14),
        markers:                 _markers,
        polylines:               _polylines,
        myLocationEnabled:       false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled:     false,
        mapToolbarEnabled:       false,
        onMapCreated: (c) {
          _ctrl = c;
          _camVersion++;
          _fitCamera();
        },
      );
}
