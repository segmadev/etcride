import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import 'search_destination_screen.dart';
import 'select_ride_screen.dart';

class ConfirmPickupScreen extends ConsumerStatefulWidget {
  const ConfirmPickupScreen({super.key});
  @override
  ConsumerState<ConfirmPickupScreen> createState() => _ConfirmPickupScreenState();
}

class _ConfirmPickupScreenState extends ConsumerState<ConfirmPickupScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _pickupLatLng;
  String  _pickupAddress = 'Locating...';
  bool _resolving = false;

  static const _defaultCenter = LatLng(8.4966, 4.5421); // Ilorin

  @override
  void initState() {
    super.initState();
    _initPickup();
  }

  Future<Position?> _getPosition() async {
    if (kIsWeb) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) {
        return null;
      }
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

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

  Future<void> _initPickup() async {
    final draft = ref.read(bookingDraftProvider);

    if (draft.hasPickup) {
      // Already have a pickup from search screen
      _pickupLatLng   = LatLng(draft.pickupLat, draft.pickupLng);
      _pickupAddress  = draft.pickupAddress;
    } else {
      // Use device location
      try {
        final pos = await _getPosition();
        if (pos == null) {
          if (mounted) {
            if (kIsWeb) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enable location permission in your browser settings.'),
                  backgroundColor: AppColors.error,
                ),
              );
            } else {
              await context.push(AppRoutes.locationPermission);
            }
          }
          final retry = await _getPosition();
          if (retry != null) {
            _pickupLatLng = LatLng(retry.latitude, retry.longitude);
            await _reverseGeocode(_pickupLatLng!);
            if (mounted) setState(() {});
            return;
          }
          _pickupLatLng = _defaultCenter;
          _pickupAddress = 'Ilorin, Kwara State';
          return;
        }
        _pickupLatLng = LatLng(pos.latitude, pos.longitude);
        await _reverseGeocode(_pickupLatLng!);
      } catch (_) {
        _pickupLatLng = _defaultCenter;
        _pickupAddress = 'Ilorin, Kwara State';
      }
    }

    if (mounted) {
      setState(() {});
      _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupLatLng!, 16),
      );
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _resolving = true);
    try {
      final address = await MapsService.reverseGeocode(pos.latitude, pos.longitude);
      _pickupAddress = address ?? 'Selected location';
    } catch (_) {
      _pickupAddress = 'Selected location';
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Set<Marker> get _markers {
    final draft = ref.read(bookingDraftProvider);
    final markers = <Marker>{};

    // Pickup pin (draggable)
    if (_pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
        onDragEnd: (newPos) async {
          setState(() => _pickupLatLng = newPos);
          await _reverseGeocode(newPos);
        },
      ));
    }

    // Destination pin (fixed)
    if (draft.hasDestination) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(draft.destinationLat, draft.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: draft.destinationAddress),
      ));
    }

    return markers;
  }

  void _confirm() {
    if (_pickupLatLng == null) return;
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
      pickupAddress: _pickupAddress,
      pickupLat:     _pickupLatLng!.latitude,
      pickupLng:     _pickupLatLng!.longitude,
    ));
    final draft = ref.read(bookingDraftProvider);
    if (!draft.hasDestination) {
      showSearchDestinationDrawer(context);
    } else if (draft.bookingType == 'delivery') {
      context.push(AppRoutes.courierSelectVehicle);
    } else {
      showSelectRideDrawer(context);
    }
  }

  Future<void> _openSearch() async {
    await showSearchDestinationDrawer(
      context,
      openSelectRideAfter: false,
      focusPickupInitially: true,
      pickupOnly: true,
    );
    if (!mounted) return;
    await _initPickup();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final mapKey = ref.watch(mapApiKeyProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
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
                      initialCameraPosition: CameraPosition(
                        target: _pickupLatLng ?? _defaultCenter,
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      markers: _markers,
                      onMapCreated: (c) => _mapCtrl = c,
                    );
                  },
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickupLatLng ?? _defaultCenter,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _markers,
                  onMapCreated: (c) => _mapCtrl = c,
                ),

          // ── Back button ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),

          // ── Search button ───────────────────────────────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: GestureDetector(
              onTap: _openSearch,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.search_rounded, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),

          // ── Bottom card ───────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.confirmPickup,
                      style: AppTextStyles.h4),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SvgPicture.asset(
                        AppAssets.mapPin,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(AppColors.pickupPin, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolving
                            ? Text('Resolving address...',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary))
                            : Text(_pickupAddress,
                                style: AppTextStyles.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _openSearch,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: const Icon(Icons.search_rounded, size: 18, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  if (draft.hasDestination) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SvgPicture.asset(
                          AppAssets.mapPin,
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(AppColors.destinationPin, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(draft.destinationAddress,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: AppStrings.confirmPickupBtn,
                    onPressed: _pickupLatLng != null && !_resolving ? _confirm : null,
                    enabled: _pickupLatLng != null && !_resolving,
                  ),
                ],
              ),
            ),
          ),
        ],
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
