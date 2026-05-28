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
import '../../core/maps/google_maps_js_loader.dart';
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

          // ── Bottom sheet ──────────────────────────────────────────────────
          const HomeBottomSheet(),
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
