import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/trip_quick_nav.dart';

class RequestingScreen extends ConsumerStatefulWidget {
  const RequestingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<RequestingScreen> createState() => _RequestingScreenState();
}

class _RequestingScreenState extends ConsumerState<RequestingScreen> {
  Timer? _pollTimer;
  Timer? _assignedTimer;       // 1-min countdown after driver is assigned
  GoogleMapController? _mapCtrl;
  int _mapVersion = 0;

  BookingModel? _booking;
  bool _cancelling      = false;
  bool _showFindAnother = false;   // becomes true after 1 min in 'assigned' state
  bool _findingAnother  = false;

  // Route state
  List<LatLng>   _routePoints    = [];
  bool           _routeLoaded    = false;
  int            _durationSec    = 0;
  LatLngBounds?  _routeBounds;
  String?        _routePolylineUsed;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadBooking() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
      _fetchRoute(b);
      _handleStatus(b);
    } catch (_) {}
  }

  Future<void> _fetchRoute(BookingModel b) async {
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

    final distKm = b.distanceKm > 0 ? b.distanceKm : (b.routeDistanceMeters > 0 ? (b.routeDistanceMeters / 1000) : 0.0);
    final durationSec = b.routeDurationSeconds > 0
        ? b.routeDurationSeconds
        : (distKm > 0 ? ((distKm / 30) * 3600).round() : 0);

    if (!mounted) return;
    if (encoded.isNotEmpty && !_routeLooksValid(points, fallbackPts.first, fallbackPts.last)) {
      return;
    }
    setState(() {
      _routePoints = points.length >= 2 ? points : fallbackPts;
      _durationSec = durationSec;
      _routeBounds = MapsService.boundsFromPoints(_routePoints);
      _routeLoaded = true;
      _routePolylineUsed = encoded.isNotEmpty ? encoded : _routePolylineUsed;
    });
    _fitRoute();
  }

  Future<void> _poll() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      final changed = _booking == null ||
          _booking!.status != b.status ||
          _booking!.driverId != b.driverId ||
          _booking!.lastEvent != b.lastEvent;
      if (changed) setState(() => _booking = b);
      _fetchRoute(b);
      _handleStatus(b);
    } catch (e) {
      final is404 = e.toString().contains('404') ||
          e.toString().toLowerCase().contains('not found');
      if (is404 && mounted) {
        _stop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Booking not found. It may have been cancelled.'),
            backgroundColor: AppColors.error));
        context.go(AppRoutes.home);
      }
    }
  }

  void _handleStatus(BookingModel b) {
    if (!mounted) return;
    // Driver accepted or already arrived → go to driver-assigned screen
    if (b.status == BookingStatus.accepted || b.status == BookingStatus.arrived) {
      _stop();
      context.go(AppRoutes.driverAssigned, extra: widget.bookingId);
      return;
    }
    if (b.status == BookingStatus.inProgress) {
      _stop();
      context.go(AppRoutes.tripInProgress, extra: widget.bookingId);
      return;
    }
    if (b.status == BookingStatus.paymentPending ||
        b.status == BookingStatus.completed) {
      _stop();
      context.go(AppRoutes.payment, extra: widget.bookingId);
      return;
    }
    if (b.status == BookingStatus.cancelled) {
      _stop();
      ref.invalidate(activeBookingProvider('ride'));
      ref.invalidate(activeBookingProvider('delivery'));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking was cancelled.'),
          backgroundColor: AppColors.error));
      context.go(AppRoutes.home);
      return;
    }
    // 'assigned' — driver found but not yet accepted
    if (b.status == BookingStatus.assigned) {
      _startAssignedTimer();
    } else {
      // 'pending' — searching or driver declined
      _cancelAssignedTimer();
    }
  }

  void _startAssignedTimer() {
    if (_assignedTimer?.isActive == true) return;
    _assignedTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _showFindAnother = true);
    });
  }

  void _cancelAssignedTimer() {
    _assignedTimer?.cancel();
    _assignedTimer = null;
    if (_showFindAnother && mounted) setState(() => _showFindAnother = false);
  }

  Future<void> _findAnotherDriver() async {
    setState(() => _findingAnother = true);
    try {
      _cancelAssignedTimer();
      await ref.read(bookingRepositoryProvider).findAnotherDriver(widget.bookingId);
      if (mounted) setState(() => _findingAnother = false);
    } catch (e) {
      if (mounted) {
        setState(() => _findingAnother = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  // ── Map helpers ─────────────────────────────────────────────────────────────

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180);
    final dLng = (b.longitude - a.longitude) * (3.141592653589793 / 180);
    final lat1 = a.latitude * (3.141592653589793 / 180);
    final lat2 = b.latitude * (3.141592653589793 / 180);
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
        _mapCtrl?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80));
      } catch (_) {
        _mapCtrl = null;
      }
    });
  }

  Set<Marker> _buildMarkers(BookingModel b) => {
    if (b.pickupLat != 0)
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(b.pickupLat, b.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: b.pickupAddress),
      ),
    if (b.destinationLat != 0)
      Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(b.destinationLat, b.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: b.destinationAddress),
      ),
  };

  // ── Cancel ──────────────────────────────────────────────────────────────────

  Future<void> _cancel() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 22),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Cancel ride?', style: AppTextStyles.h4),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Are you sure you want to cancel?',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "We’re still finding you a driver. Are you sure you want to cancel?",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9D9D9),
                    foregroundColor: const Color(0xFF6B6B6B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    'CANCEL REQUEST',
                    style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    'KEEP SEARCHING',
                    style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      _stop();
      await ref
          .read(bookingRepositoryProvider)
          .cancelBooking(widget.bookingId, reason: 'Cancelled by customer');
      ref.invalidate(activeBookingProvider('ride'));
      ref.invalidate(activeBookingProvider('delivery'));
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
        setState(() => _cancelling = false);
        _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
      }
    }
  }

  void _stop() {
    _pollTimer?.cancel();
    _assignedTimer?.cancel();
  }

  @override
  void dispose() {
    _stop();
    _mapVersion++;
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final b      = _booking;
    final draft  = ref.watch(bookingDraftProvider);
    final mapKey = ref.watch(mapApiKeyProvider);

    final pickupAddr = b?.pickupAddress      ?? draft.pickupAddress;
    final destAddr   = b?.destinationAddress ?? draft.destinationAddress;
    final fare       = b?.estimatedFare      ?? draft.estimatedFare;
    final vtName     = b?.vehicleTypeName    ?? draft.vehicleTypeName;
    final distKm     = b?.distanceKm         ?? draft.distanceKm;
    final isDelivery = b?.bookingType == BookingType.delivery;

    final initialPos = (b != null && b.pickupLat != 0)
        ? LatLng(b.pickupLat, b.pickupLng)
        : (draft.hasPickup
            ? LatLng(draft.pickupLat, draft.pickupLng)
            : const LatLng(8.4966, 4.5421));

    final markers   = b != null ? _buildMarkers(b) : <Marker>{};
    final polylines = _routePoints.length >= 2
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
        : <Polyline>{};

    return Scaffold(
      body: Stack(
        children: [
          // ── Stable map ────────────────────────────────────────────────────
          _StableMapView(
            initialPos: initialPos,
            apiKey:     mapKey,
            markers:    markers,
            polylines:  polylines,
            onMapCreated: (c) {
              _mapCtrl = c;
              _mapVersion++;
              if (_routeBounds != null) _fitRoute();
            },
          ),

          // ── Back button ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  MapOverlayButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),

          // ── Info sheet ───────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _InfoSheet(
              pickupAddress:      pickupAddr,
              destAddress:        destAddr,
              fare:               fare,
              vehicleType:        vtName.isNotEmpty ? vtName : 'Standard',
              distanceKm:         distKm,
              durationSec:        _durationSec,
              isDelivery:         isDelivery,
              cancelling:         _cancelling,
              status:             _booking?.status,
              lastEvent:          _booking?.lastEvent,
              driverEtaMinutes:   _booking?.driverEtaMinutes ?? 0,
              alternativeTypes:   _booking?.alternativeTypes ?? const [],
              showFindAnother:    _showFindAnother,
              findingAnother:     _findingAnother,
              onCancel:           _cancel,
              onFindAnother:      _findAnotherDriver,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stable map widget ─────────────────────────────────────────────────────────

class _StableMapView extends StatefulWidget {
  const _StableMapView({
    required this.initialPos,
    required this.apiKey,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
  });

  final LatLng      initialPos;
  final String      apiKey;
  final Set<Marker>   markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController) onMapCreated;

  @override
  State<_StableMapView> createState() => _StableMapViewState();
}

class _StableMapViewState extends State<_StableMapView> {
  late Set<Marker>   _markers;
  late Set<Polyline> _polylines;

  @override
  void initState() {
    super.initState();
    _markers   = widget.markers;
    _polylines = widget.polylines;
  }

  @override
  void didUpdateWidget(_StableMapView old) {
    super.didUpdateWidget(old);
    final mc = _hashMarkers(old.markers)    != _hashMarkers(widget.markers);
    final pc = _hashPolylines(old.polylines) != _hashPolylines(widget.polylines);
    if (mc || pc) {
      setState(() {
        _markers   = widget.markers;
        _polylines = widget.polylines;
      });
    }
  }

  String _hashMarkers(Set<Marker> m) => m
      .map((x) => '${x.markerId.value}:'
          '${x.position.latitude.toStringAsFixed(5)},'
          '${x.position.longitude.toStringAsFixed(5)}')
      .join('|');

  String _hashPolylines(Set<Polyline> p) =>
      p.map((x) => '${x.polylineId.value}:${x.points.length}').join('|');

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<bool>(
        future: ensureGoogleMapsJsLoaded(apiKey: widget.apiKey),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done || snap.data != true) {
            return _MapPlaceholder(pos: widget.initialPos);
          }
          return _buildMap();
        },
      );
    }
    return _buildMap();
  }

  Widget _buildMap() => GoogleMap(
        initialCameraPosition:
            CameraPosition(target: widget.initialPos, zoom: 14),
        markers:                 _markers,
        polylines:               _polylines,
        myLocationEnabled:       false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled:     false,
        mapToolbarEnabled:       false,
        onMapCreated:            widget.onMapCreated,
      );
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.pos});
  final LatLng pos;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.map_outlined, color: AppColors.textHint, size: 48),
        ),
      );
}

// ── Info sheet ────────────────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.pickupAddress,
    required this.destAddress,
    required this.fare,
    required this.vehicleType,
    required this.distanceKm,
    required this.durationSec,
    required this.isDelivery,
    required this.cancelling,
    required this.onCancel,
    required this.onFindAnother,
    required this.showFindAnother,
    required this.findingAnother,
    required this.driverEtaMinutes,
    required this.alternativeTypes,
    this.status,
    this.lastEvent,
  });

  final String         pickupAddress;
  final String         destAddress;
  final double         fare;
  final String         vehicleType;
  final double         distanceKm;
  final int            durationSec;
  final bool           isDelivery;
  final bool           cancelling;
  final BookingStatus? status;
  final String?        lastEvent;
  final int            driverEtaMinutes;
  final List<dynamic>  alternativeTypes;
  final bool           showFindAnother;
  final bool           findingAnother;
  final VoidCallback   onCancel;
  final VoidCallback   onFindAnother;

  String get _scheduledTime {
    final now = TimeOfDay.now();
    final h   = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m   = now.minute.toString().padLeft(2, '0');
    final p   = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m$p';
  }

  String _short(String addr) {
    if (addr.isEmpty) return '';
    return addr.split(',').first.trim();
  }

  bool get _isAssigned => status == BookingStatus.assigned;
  bool get _isDeclined => lastEvent == 'driver_declined' && status == BookingStatus.pending;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Status heading ────────────────────────────────────────────────
          if (_isAssigned) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text('Driver found!', style: AppTextStyles.h4, textAlign: TextAlign.center),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Waiting for driver to accept your request…',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (driverEtaMinutes > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated arrival: $driverEtaMinutes min${driverEtaMinutes == 1 ? "" : "s"}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ] else if (_isDeclined) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text('Driver declined', style: AppTextStyles.h4, textAlign: TextAlign.center),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'We\'re finding you another driver…',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text('Finding your driver…', style: AppTextStyles.h4, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'This usually takes a few seconds',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],

          // ── Alternative types suggestion ──────────────────────────────────
          if (alternativeTypes.isNotEmpty && status == BookingStatus.pending) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No $vehicleType drivers nearby. Try:',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: alternativeTypes.take(3).map((t) {
                      final m     = t as Map<String, dynamic>? ?? {};
                      final name  = m['name']?.toString() ?? '';
                      final count = int.tryParse(m['available_count']?.toString() ?? '0') ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$name ($count available)',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'To ${_short(destAddress)}',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'at $_scheduledTime from ${_short(pickupAddress)}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${vehicleType.toUpperCase()} ~${AppFormatters.naira(fare)}',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.share_outlined, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Share trip status', style: AppTextStyles.bodyMedium),
              ),
              Text(
                'Share',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── "Find another driver" button (shown after 1 min in assigned state) ─
          if (showFindAnother) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: findingAnother ? null : onFindAnother,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  findingAnother ? 'Searching…' : 'FIND ANOTHER DRIVER',
                  style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary, letterSpacing: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: cancelling ? null : onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: const Color(0xFF6B6B6B),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text(
                cancelling ? '...' : 'CANCEL REQUEST',
                style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
