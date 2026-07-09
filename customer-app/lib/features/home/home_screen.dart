import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../data/models/booking_model.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/biometric_service.dart';
import '../../shared/providers/providers.dart';
import 'widgets/home_drawer.dart';
import 'widgets/home_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _defaultCamera = CameraPosition(
    target: LatLng(8.4966, 4.5421), // Ilorin, Kwara State
    zoom: 14,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _locateUser();
    _checkBiometricPrompt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationService.instance.consumePending(context);
    });
  }

  Future<void> _checkBiometricPrompt() async {
    // Check if biometrics are available but not enabled
    final available = await BiometricService.instance.isAvailable;
    final enabled = await BiometricService.instance.isEnabled;

    if (available && !enabled && mounted) {
      // Show biometric enable prompt after a delay so UI is fully loaded
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _showBiometricPrompt();
      });
    }
  }

  void _showBiometricPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Biometric Sign-In'),
        content: const Text(
          'Use your fingerprint or face to quickly sign in to your account. It\'s secure and convenient.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/settings');
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _getPosition() async {
    if (kIsWeb) {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          return null;
        }
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) { return null; }
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _locateUser() async {
    try {
      final pos = await _getPosition();
      if (pos == null) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          context.push(AppRoutes.locationPermission);
        });
        return;
      }
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(ll, 15));
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('user'),
            position: ll,
            infoWindow: const InfoWindow(title: 'Your location'),
          ),
        };
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mapKey = ref.watch(mapApiKeyProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HomeDrawer(),
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────────
          kIsWeb
              ? FutureBuilder<bool>(
                  future: ensureGoogleMapsJsLoaded(apiKey: mapKey),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _WebMapPlaceholder();
                    }
                    if (snap.data != true) {
                      return const _WebMapPlaceholder();
                    }
                    return GoogleMap(
                      initialCameraPosition: _defaultCamera,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      markers: _markers,
                      onMapCreated: (c) => _mapController = c,
                    );
                  },
                )
              : GoogleMap(
                  initialCameraPosition: _defaultCamera,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _markers,
                  onMapCreated: (c) => _mapController = c,
                ),

          // ── Top: hamburger menu ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.menuIcon,
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Refresh map button (right side) ───────────────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: GestureDetector(
              onTap: _locateUser,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(AppStrings.refreshMap, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
            ),
          ),

          // ── Active trip floating button ───────────────────────────────────
          const _ActiveTripBanner(),

          // ── Bottom sheet ──────────────────────────────────────────────────
          const HomeBottomSheet(),
        ],
      ),
    );
  }
}

class _ActiveTripBanner extends ConsumerWidget {
  const _ActiveTripBanner();

  void _resume(BuildContext context, BookingModel b) {
    switch (b.status) {
      case BookingStatus.pending:
        context.go(AppRoutes.requesting, extra: b.id);
      case BookingStatus.assigned:
      case BookingStatus.accepted:
      case BookingStatus.arrived:
      case BookingStatus.pickedUp:
        context.go(AppRoutes.driverAssigned, extra: b.id);
      case BookingStatus.inProgress:
        context.go(AppRoutes.tripInProgress, extra: b.id);
      case BookingStatus.paymentPending:
        if (b.paymentStatus == 'paid' && b.bookingType == BookingType.delivery) {
          context.go(AppRoutes.driverAssigned, extra: b.id);
        } else if (b.paymentStatus == 'paid') {
          context.go(AppRoutes.tripCompleted, extra: b.id);
        } else {
          context.go(AppRoutes.payment, extra: b.id);
        }
      case BookingStatus.completed:
      case BookingStatus.paid:
        context.go(AppRoutes.tripCompleted, extra: b.id);
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(activeBookingProvider('ride'));
    final deliveryAsync = ref.watch(activeDeliveryBookingsProvider);

    final ride = rideAsync.valueOrNull;
    final deliveries = deliveryAsync.valueOrNull ?? [];

    final BookingModel? active = ride ?? (deliveries.isNotEmpty ? deliveries.first : null);
    if (active == null) return const SizedBox.shrink();

    final isDelivery = active.bookingType == BookingType.delivery;
    final label = isDelivery ? 'Delivery in progress' : 'Trip in progress';
    final icon = isDelivery ? Icons.local_shipping_rounded : Icons.directions_car_rounded;

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.38 + 12,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => _resume(context, active),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.white),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebMapPlaceholder extends StatelessWidget {
  const _WebMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(Icons.map_outlined, color: AppColors.textHint, size: 48),
    );
  }
}
