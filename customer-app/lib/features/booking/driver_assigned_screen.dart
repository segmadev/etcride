import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/driver_card.dart';
import '../../shared/widgets/google_map_view.dart';
import '../../shared/widgets/app_button.dart';

class DriverAssignedScreen extends ConsumerStatefulWidget {
  const DriverAssignedScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends ConsumerState<DriverAssignedScreen> {
  BookingModel? _booking;
  Timer? _pollTimer;
  GoogleMapController? _mapCtrl;
  bool _cancelling = false;

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

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Trip?', style: AppTextStyles.h4),
        content: Text(
            _booking?.status == BookingStatus.arrived
                ? 'Your driver has arrived. Are you sure you want to cancel?'
                : 'Are you sure you want to cancel this trip?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Trip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      _pollTimer?.cancel();
      await ref.read(bookingRepositoryProvider)
          .cancelBooking(widget.bookingId, reason: 'Cancelled by customer');
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() { _cancelling = false; _pollTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _load()); });
      }
    }
  }

  Set<Marker> get _markers {
    final b = _booking;
    if (b == null) return {};
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(b.pickupLat, b.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
    };
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b      = _booking;
    final mapKey = ref.watch(mapApiKeyProvider);
    final isArrived = b?.status == BookingStatus.arrived;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          GoogleMapView(
            initialPosition: b != null
                ? LatLng(b.pickupLat, b.pickupLng)
                : _defaultCenter,
            apiKey: mapKey,
            markers: _markers,
            onMapCreated: (c) => _mapCtrl = c,
          ),

          // ── Arrived banner ────────────────────────────────────────────────
          if (isArrived)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Your driver has arrived!',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Driver card ───────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: b == null
                ? Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : DriverCard(
                    booking: b,
                    statusIcon: Icon(
                      isArrived
                          ? Icons.check_circle_rounded
                          : Icons.directions_car_rounded,
                      size: 16,
                      color: isArrived ? AppColors.success : AppColors.textSecondary,
                    ),
                    statusLabel: isArrived
                        ? 'Driver is at your pickup location'
                        : '~5 min away · Meet at pickup',
                    trailing: b.status.canCancel
                        ? Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: TextButton(
                              onPressed: _cancelling ? null : _cancel,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(_cancelling ? '...' : 'Cancel',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.error)),
                            ),
                          )
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}
