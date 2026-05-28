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
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/trip_quick_nav.dart';

class DriverAssignedScreen extends ConsumerStatefulWidget {
  const DriverAssignedScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
  });

  final String assetPath;

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
        );
      },
    );
  }
}

class _DriverAssignedScreenState extends ConsumerState<DriverAssignedScreen> {
  BookingModel? _booking;
  Timer? _pollTimer;
  Timer? _driverAnimTimer;
  GoogleMapController? _mapCtrl;
  int _mapVersion = 0;
  bool _cancelling = false;
  final _noteCtrl = TextEditingController();

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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
      _fetchRoute(b);
      _loadTrack(b);

      switch (b.status) {
        case BookingStatus.inProgress:
          _pollTimer?.cancel();
          context.go(AppRoutes.tripInProgress, extra: widget.bookingId);
        case BookingStatus.completed:
        case BookingStatus.paymentPending:
          _pollTimer?.cancel();
          context.go(AppRoutes.payment, extra: widget.bookingId);
        case BookingStatus.cancelled:
          _pollTimer?.cancel();
          if (mounted) {
            ref.invalidate(activeBookingProvider('ride'));
            ref.invalidate(activeBookingProvider('delivery'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip was cancelled.'),
                  backgroundColor: AppColors.error),
            );
            context.go(AppRoutes.home);
          }
        default:
          break;
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

  Future<void> _cancel() async {
    final b = _booking;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        final sub = b?.status == BookingStatus.arrived
            ? 'Your driver has arrived. Are you sure you want to cancel?'
            : 'Are you sure you want to cancel?';
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
              Text('Cancel trip?', style: AppTextStyles.h4),
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
                  sub,
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
                    'CANCEL',
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
                    'KEEP TRIP',
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
      _pollTimer?.cancel();
      await ref.read(bookingRepositoryProvider)
          .cancelBooking(widget.bookingId, reason: 'Cancelled by customer');
      ref.invalidate(activeBookingProvider('ride'));
      ref.invalidate(activeBookingProvider('delivery'));
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() {
          _cancelling = false;
          _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
        });
      }
    }
  }

  Set<Marker> get _markers {
    final b = _booking;
    if (b == null) return {};
    return {
      if (b.pickupLat != 0)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(b.pickupLat, b.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (b.destinationLat != 0)
        Marker(
          markerId: const MarkerId('dest'),
          position: LatLng(b.destinationLat, b.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
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

  Future<void> _showCallSheet() async {
    final b = _booking;
    if (b == null) return;
    final name = b.driverName ?? 'Driver';
    final phone = b.driverPhone ?? '';
    await showModalBottomSheet<void>(
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
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Call $name', style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: phone.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.parse('tel:$phone');
                          await launchUrl(uri);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    phone.isEmpty ? '—' : phone,
                    style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChat() {
    final b = _booking;
    if (b == null) return;
    context.push(
      AppRoutes.driverChat,
      extra: widget.bookingId,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driverAnimTimer?.cancel();
    _noteCtrl.dispose();
    _mapVersion++;
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b       = _booking;
    final mapKey  = ref.watch(mapApiKeyProvider);
    final isArrived = b?.status == BookingStatus.arrived;

    final initialPos = b != null && b.pickupLat != 0
        ? LatLng(b.pickupLat, b.pickupLng)
        : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map with route ────────────────────────────────────────────────
          _RoutedMapView(
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

          // ── Arrived banner ────────────────────────────────────────────────
          if (isArrived)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          AppAssets.mapPin,
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 8),
                        Text('Your driver has arrived!',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom driver card ────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: b == null
                ? Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  )
                : _AssignedSheet(
                    booking: b,
                    noteCtrl: _noteCtrl,
                    cancelling: _cancelling,
                    onCancel: _cancel,
                    onCall: _showCallSheet,
                    onChat: _openChat,
                    onNeedHelp: () => context.push(AppRoutes.help),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AssignedSheet extends StatelessWidget {
  const _AssignedSheet({
    required this.booking,
    required this.noteCtrl,
    required this.cancelling,
    required this.onCancel,
    required this.onCall,
    required this.onChat,
    required this.onNeedHelp,
  });

  final BookingModel booking;
  final TextEditingController noteCtrl;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onNeedHelp;

  String _short(String addr) => addr.split(',').first.trim();

  int get _arrivingMins {
    final sec = booking.routeDurationSeconds;
    if (sec <= 0) return 4;
    final m = (sec / 60).ceil().clamp(1, 9999);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final name = booking.driverName ?? 'Driver';
    final plate = booking.vehiclePlate ?? '';
    final color = booking.vehicleColor ?? '';
    final vehicleName = booking.vehicleTypeName ?? 'Vehicle';

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
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Arriving in $_arrivingMins mins…',
              style: AppTextStyles.h4,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Meet your driver at the pickup spot.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person_rounded, size: 30, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = i < booking.driverRating.round().clamp(0, 5);
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: AppColors.primary,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: _EmbeddedPngFromSvgAsset(
                      assetPath: booking.bookingType == BookingType.delivery
                          ? AppAssets.courierIcon
                          : AppAssets.carIcon,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicleName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  if (plate.isNotEmpty) Text(plate, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  if (color.isNotEmpty) Text(color, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoundAction(
                icon: Icons.call_rounded,
                onTap: onCall,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add note for driver (optional)',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _RoundAction(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: onChat,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: const [
                  _PinIcon(),
                  SizedBox(height: 8),
                  _DottedVLine(height: 32),
                  SizedBox(height: 8),
                  _PinIcon(),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From ${_short(booking.pickupAddress)}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text('To ${_short(booking.destinationAddress)}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.share_outlined, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text('Share trip status', style: AppTextStyles.bodyMedium)),
              Text(
                'Share',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
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
                      cancelling ? '...' : 'CANCEL',
                      style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onNeedHelp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      'NEED HELP?',
                      style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.white),
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.mapPin,
      width: 18,
      height: 18,
      colorFilter: const ColorFilter.mode(AppColors.black, BlendMode.srcIn),
    );
  }
}

class _DottedVLine extends StatelessWidget {
  const _DottedVLine({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: height,
      child: CustomPaint(
        painter: _DottedVLinePainter(),
      ),
    );
  }
}

class _DottedVLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dot = 2.0;
    const gap = 6.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dot).clamp(0.0, size.height)), paint);
      y += dot + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Map view with stable update logic ────────────────────────────────────────

class _RoutedMapView extends StatefulWidget {
  const _RoutedMapView({
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
  State<_RoutedMapView> createState() => _RoutedMapViewState();
}

class _RoutedMapViewState extends State<_RoutedMapView> {
  late Set<Marker>   _m;
  late Set<Polyline> _p;

  @override
  void initState() { super.initState(); _m = widget.markers; _p = widget.polylines; }

  @override
  void didUpdateWidget(_RoutedMapView old) {
    super.didUpdateWidget(old);
    final mc = _hm(old.markers)    != _hm(widget.markers);
    final pc = _hp(old.polylines)  != _hp(widget.polylines);
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
