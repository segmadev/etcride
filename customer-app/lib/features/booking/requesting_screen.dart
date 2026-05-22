import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
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
  GoogleMapController? _mapCtrl;
  int _mapVersion = 0;

  BookingModel? _booking;
  bool          _cancelling = false;

  // Route state
  List<LatLng>   _routePoints    = [];
  bool           _routeLoaded    = false;
  int            _durationSec    = 0;   // actual driving duration from Directions API
  LatLngBounds?  _routeBounds;
  String?        _routePolylineUsed;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
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
    final points = encoded.isNotEmpty ? MapsService.decodePolyline(encoded) : fallbackPts;

    final distKm = b.distanceKm > 0 ? b.distanceKm : (b.routeDistanceMeters > 0 ? (b.routeDistanceMeters / 1000) : 0.0);
    final durationSec = b.routeDurationSeconds > 0
        ? b.routeDurationSeconds
        : (distKm > 0 ? ((distKm / 30) * 3600).round() : 0);

    if (!mounted) return;
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
          _booking!.driverId != b.driverId;
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
    if (b.status == BookingStatus.assigned ||
        b.status == BookingStatus.accepted ||
        b.status == BookingStatus.arrived) {
      _stop();
      context.go(AppRoutes.driverAssigned, extra: widget.bookingId);
    } else if (b.status == BookingStatus.inProgress) {
      _stop();
      context.go(AppRoutes.tripInProgress, extra: widget.bookingId);
    } else if (b.status == BookingStatus.paymentPending ||
        b.status == BookingStatus.completed) {
      _stop();
      context.go(AppRoutes.payment, extra: widget.bookingId);
    } else if (b.status == BookingStatus.cancelled) {
      _stop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking was cancelled.'),
          backgroundColor: AppColors.error));
      context.go(AppRoutes.home);
    }
  }

  // ── Map helpers ─────────────────────────────────────────────────────────────

  void _fitRoute() {
    final bounds = _routeBounds;
    if (bounds == null) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.cancelRide, style: AppTextStyles.h4),
        content: Text(AppStrings.cancelRideConfirm, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.keepSearching,
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.cancel,
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      _stop();
      await ref
          .read(bookingRepositoryProvider)
          .cancelBooking(widget.bookingId, reason: 'Cancelled by customer');
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
        setState(() => _cancelling = false);
        _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
      }
    }
  }

  void _stop() { _pollTimer?.cancel(); }

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

          // ── Top bar: [menu]  ···  [home] ─────────────────────────────────
          const TripTopBar(),

          // ── Info sheet ───────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _InfoSheet(
              pickupAddress: pickupAddr,
              destAddress:   destAddr,
              fare:          fare,
              vehicleType:   vtName.isNotEmpty ? vtName : 'Standard',
              distanceKm:    distKm,
              durationSec:   _durationSec,
              isDelivery:    isDelivery,
              cancelling:    _cancelling,
              status:        _booking?.status,
              onCancel:      _cancel,
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

class _InfoSheet extends StatefulWidget {
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
    this.status,
  });

  final String        pickupAddress;
  final String        destAddress;
  final double        fare;
  final String        vehicleType;
  final double        distanceKm;
  final int           durationSec;
  final bool          isDelivery;
  final bool          cancelling;
  final BookingStatus? status;
  final VoidCallback  onCancel;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  Timer? _timer;
  int    _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return m == 0 ? '${s}s' : '${m}m ${s}s';
  }

  String get _statusHeading => switch (widget.status) {
    BookingStatus.assigned => 'Driver found!',
    BookingStatus.accepted => 'Driver accepted!',
    BookingStatus.arrived  => 'Driver has arrived!',
    _                      => AppStrings.findingDriver,
  };

  String get _statusSubheading => switch (widget.status) {
    BookingStatus.assigned => 'Waiting for driver to confirm the trip…',
    BookingStatus.accepted => 'Your driver is on the way to you.',
    BookingStatus.arrived  => 'Your driver is waiting at the pickup point.',
    _                      => AppStrings.findingDriverSub,
  };

  // Use Google's duration when available; fall back to distance-based estimate
  String get _etaLabel {
    if (widget.durationSec > 0) {
      return AppFormatters.duration(widget.durationSec ~/ 60);
    }
    if (widget.distanceKm <= 0) return '—';
    final mins = (widget.distanceKm / 25 * 60).round().clamp(2, 9999);
    return AppFormatters.duration(mins);
  }

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

          // ── Status row ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusHeading, style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(_statusSubheading,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 5),
                    Text(_elapsedLabel,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── ETA row ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.access_time_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pick Up in ~$_etaLabel',
                      style: AppTextStyles.labelMedium),
                  Text('at $_scheduledTime from ${_short(widget.pickupAddress)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Destination row ───────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on_rounded,
                    size: 18, color: AppColors.destinationPin),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To ${_short(widget.destAddress)}',
                        style: AppTextStyles.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (widget.distanceKm > 0)
                      Text(AppFormatters.distance(widget.distanceKm),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Vehicle + fare ────────────────────────────────────────────
          Row(
            children: [
              Icon(
                widget.isDelivery
                    ? Icons.delivery_dining_rounded
                    : Icons.directions_car_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.vehicleType}  ·  ${AppFormatters.naira(widget.fare)}',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Share ─────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.share_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(AppStrings.shareTripStatus,
                      style: AppTextStyles.bodyMedium)),
              TextButton(
                onPressed: () {/* TODO: share */},
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary),
                child: Text(AppStrings.share,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Cancel ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.cancelling ? null : widget.onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.divider, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                foregroundColor: AppColors.error,
              ),
              child: Text(
                widget.cancelling ? 'Cancelling...' : AppStrings.cancelRequest,
                style: AppTextStyles.labelMedium.copyWith(
                    color: widget.cancelling
                        ? AppColors.textHint
                        : AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
        ),
      );
}
