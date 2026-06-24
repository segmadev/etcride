import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
import '../../../shared/widgets/app_bottom_drawer.dart';
import '../home/widgets/home_drawer.dart';

class TripInProgressScreen extends ConsumerStatefulWidget {
  const TripInProgressScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripInProgressScreen> createState() =>
      _TripInProgressScreenState();
}

class _TripInProgressScreenState
    extends ConsumerState<TripInProgressScreen> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  BookingModel? _booking;
  Timer?        _pollTimer;
  bool _isRefreshing = false;
  late final AnimationController _refreshCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

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
    _refreshCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshMap() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _refreshCtrl.repeat();

    try {
      await _load();
    } finally {
      _refreshCtrl.stop();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showReportSheet(BuildContext context) {
    if (_booking == null) {
      print('DEBUG: Booking is null, cannot show report sheet');
      return;
    }
    print('DEBUG: Showing report sheet for booking: ${_booking!.id}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportTripSheet(bookingId: _booking!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b      = _booking;
    final mapKey = ref.watch(mapApiKeyProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HomeDrawer(),
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
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _refreshCtrl,
                    child: MapOverlayButton(
                      icon: Icons.refresh_rounded,
                      onTap: _isRefreshing ? () {} : _refreshMap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  MapOverlayButton(
                    icon: Icons.flag_rounded,
                    onTap: () => _showReportSheet(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A000000), // 10% black transparent
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x33000000), // 20% black border
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(AppStrings.headingToDestination,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom driver card (collapsible — drag down to see full map) ───
          Positioned.fill(
            child: b == null
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.white,
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    ),
                  )
                : CollapsibleMapSheet(
                    initialChildSize: 0.34,
                    child: DriverCard(
                      booking: b,
                      statusIcon: const Icon(Icons.navigation_rounded,
                          size: 16, color: AppColors.primary),
                      statusLabel: b.bookingType == BookingType.delivery
                          ? 'Package in transit'
                          : 'Heading to destination',
                      onChat: () => context.push(
                        AppRoutes.driverChat,
                        extra: b.id,
                      ),
                    ),
                  ),
          ),
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

  List<LatLng>  _routePts      = [];   // full decoded route
  List<LatLng>  _trimmedPts    = [];   // route trimmed to driver's current position
  bool          _routeLoaded   = false;
  String?       _polyUsed;
  LatLngBounds? _routeBounds;

  // Custom animated car icon
  BitmapDescriptor? _carIcon;
  static BitmapDescriptor? _cachedCarIcon;

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
    _loadCarIcon();
  }

  Future<void> _loadCarIcon() async {
    if (_cachedCarIcon != null) {
      setState(() => _carIcon = _cachedCarIcon);
      return;
    }
    try {
      final icon = await _buildCircleMarkerIcon(
        Icons.directions_car_rounded,
        bg: const Color(0xFFE2A322),
      );
      _cachedCarIcon = icon;
      if (mounted) setState(() => _carIcon = icon);
    } catch (_) {}
  }

  static Future<BitmapDescriptor> _buildCircleMarkerIcon(
    IconData icon, {
    Color bg   = const Color(0xFFE2A322),
    double size = 40,
  }) async {
    final dpr      = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final physSize = (size * dpr).roundToDouble();
    final r        = physSize / 2;
    final rec      = ui.PictureRecorder();
    final canvas   = Canvas(rec);
    canvas.drawCircle(Offset(r, r), r, Paint()..color = bg);
    canvas.drawCircle(
      Offset(r, r), r - dpr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * dpr,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: physSize * 0.52,
          fontFamily: icon.fontFamily,
          color: Colors.white,
          package: icon.fontPackage,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((physSize - tp.width) / 2, (physSize - tp.height) / 2));
    final img  = await rec.endRecording().toImage(physSize.toInt(), physSize.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: dpr);
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
      _trimmedPts  = route;  // initially show full route
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
      if (i >= steps) {
        t.cancel();
        // Trim route and pan camera after marker arrives
        if (mounted) {
          setState(() => _trimmedPts = _trimRoute(_routePts, target));
          _followCamera(target);
        }
      }
    });
  }

  /// Returns the route from the segment closest to [driverPos] to the end.
  List<LatLng> _trimRoute(List<LatLng> full, LatLng driverPos) {
    if (full.length < 2) return full;
    var bestIdx  = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < full.length; i++) {
      final d = _haversineM(full[i], driverPos);
      if (d < bestDist) { bestDist = d; bestIdx = i; }
    }
    if (bestIdx >= full.length - 1) return [full.last];
    return [driverPos, ...full.sublist(bestIdx + 1)];
  }

  static double _haversineM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(s1*s1 + math.cos(lat1)*math.cos(lat2)*s2*s2));
  }

  /// Pan camera to keep driver + destination in frame.
  void _followCamera(LatLng driverPos) {
    final b = widget.booking;
    if (b == null || _ctrl == null || b.destinationLat == 0) return;
    final dest = LatLng(b.destinationLat, b.destinationLng);
    if (_haversineM(driverPos, dest) < 10) return;
    final sw = LatLng(
      math.min(driverPos.latitude, dest.latitude),
      math.min(driverPos.longitude, dest.longitude),
    );
    final ne = LatLng(
      math.max(driverPos.latitude, dest.latitude),
      math.max(driverPos.longitude, dest.longitude),
    );
    try {
      _ctrl!.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 100),
      );
    } catch (_) { _ctrl = null; }
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
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
    };
  }

  Set<Polyline> get _polylines {
    final pts = _trimmedPts.length >= 2 ? _trimmedPts
        : (_routePts.length >= 2 ? _routePts : null);
    if (pts == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points:     pts,
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

// ── Report Trip Sheet ──────────────────────────────────────────────────────────

class _ReportTripSheet extends ConsumerStatefulWidget {
  const _ReportTripSheet({required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<_ReportTripSheet> createState() => _ReportTripSheetState();
}

class _ReportTripSheetState extends ConsumerState<_ReportTripSheet> {
  late final TextEditingController _reasonCtrl = TextEditingController();
  late final TextEditingController _descCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _reported = false;
  String? _cancellationReason;
  late final TextEditingController _cancellationDescCtrl = TextEditingController();
  bool _isRequestingCancellation = false;

  final List<String> _reportReasons = [
    'Driver behavior',
    'Wrong route',
    'Vehicle condition',
    'Safety concern',
    'Other',
  ];

  final List<String> _cancellationReasons = [
    'Driver issue',
    'Wrong address',
    'Changed plans',
    'Too expensive',
    'Emergency',
    'Other',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _descCtrl.dispose();
    _cancellationDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    print('DEBUG: _submitReport called');
    print('DEBUG: Reason: ${_reasonCtrl.text}, Desc: ${_descCtrl.text}');

    if (_reasonCtrl.text.isEmpty) {
      print('DEBUG: Reason is empty');
      _showError('Please select a reason');
      return;
    }
    if (_descCtrl.text.isEmpty) {
      print('DEBUG: Description is empty');
      _showError('Please add a description');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      print('DEBUG: Calling reportTrip API');
      final repo = ref.read(tripReportsRepositoryProvider);
      print('DEBUG: Repository obtained: $repo');

      final response = await repo.reportTrip(
        bookingId: widget.bookingId,
        reason: _reasonCtrl.text,
        description: _descCtrl.text,
      );

      print('DEBUG: API response: $response');

      if (mounted) {
        _showSuccess('Trip reported successfully');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _reported = true);
        }
      }
    } catch (e, stack) {
      print('DEBUG: Error in _submitReport: $e');
      print('DEBUG: Stack trace: $stack');
      if (mounted) {
        _showError('Failed to report trip: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _requestCancellation() async {
    if (_cancellationReason == null) {
      _showError('Please select a cancellation reason');
      return;
    }
    if (_cancellationDescCtrl.text.isEmpty) {
      _showError('Please add description');
      return;
    }

    setState(() => _isRequestingCancellation = true);
    try {
      await ref.read(tripReportsRepositoryProvider).requestCancellation(
        bookingId: widget.bookingId,
        reason: _cancellationReason!,
        description: _cancellationDescCtrl.text,
      );

      if (mounted) {
        _showSuccess('Cancellation request submitted for admin review');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to request cancellation: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isRequestingCancellation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _reported ? 'Request Cancellation' : 'Report This Trip',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 16),
              if (!_reported) ...[
                const Text('What happened?', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _reasonCtrl.text.isEmpty ? null : _reasonCtrl.text,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select a reason'),
                    ),
                    items: _reportReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(reason),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _reasonCtrl.text = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Description', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    hintText: 'Describe what happened...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Report Trip'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 12),
                      Text(
                        'Trip reported successfully',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Request Cancellation?', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                const Text(
                  'You can request cancellation. This will be reviewed by our team.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _cancellationReason,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select cancellation reason'),
                    ),
                    items: _cancellationReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(reason),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _cancellationReason = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cancellationDescCtrl,
                  decoration: InputDecoration(
                    hintText: 'Additional details...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                  minLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRequestingCancellation ? null : _requestCancellation,
                        child: _isRequestingCancellation
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Request Cancellation'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
