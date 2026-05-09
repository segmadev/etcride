import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/driver_card.dart';
import '../../../shared/widgets/google_map_view.dart';

class TripInProgressScreen extends ConsumerStatefulWidget {
  const TripInProgressScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends ConsumerState<TripInProgressScreen> {
  BookingModel? _booking;
  Timer? _pollTimer;
  GoogleMapController? _mapCtrl;

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

      if (b.status == BookingStatus.paymentPending ||
          b.status == BookingStatus.completed) {
        _pollTimer?.cancel();
        context.go(AppRoutes.payment, extra: widget.bookingId);
      } else if (b.status == BookingStatus.paid) {
        _pollTimer?.cancel();
        context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
      }
    } catch (_) {}
  }

  Set<Marker> get _markers {
    final b = _booking;
    if (b == null) return {};
    return {
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(b.destinationLat, b.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: b.destinationAddress),
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

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────────
          GoogleMapView(
            initialPosition: b != null
                ? LatLng(b.destinationLat, b.destinationLng)
                : _defaultCenter,
            apiKey: mapKey,
            markers: _markers,
            myLocationEnabled: true,
            onMapCreated: (c) => _mapCtrl = c,
          ),

          // ── Top status bar ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          color: AppColors.success, shape: BoxShape.circle),
                    ),
                  ],
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
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary)),
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
