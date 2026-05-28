import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/maps/maps_service.dart';
import '../../../core/maps/boundary_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';

class CourierScreen extends ConsumerStatefulWidget {
  const CourierScreen({super.key});

  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
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

  Future<void> _loadCurrentLocation() async {
    setState(() => _loading = true);
    try {
      final pos = await _getPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location permission in your browser/device settings.'),
              backgroundColor: AppColors.error,
            ),
          );
          if (!kIsWeb) {
            context.push(AppRoutes.locationPermission);
          }
        }
        _pickupCtrl.text = 'My Location';
        return;
      }
      final address = await MapsService.reverseGeocode(pos.latitude, pos.longitude);
      _pickupCtrl.text = address ?? 'My Location';

      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            bookingType:   'delivery',
            pickupAddress: _pickupCtrl.text,
            pickupLat:     pos.latitude,
            pickupLng:     pos.longitude,
          ));
    } catch (_) {
      _pickupCtrl.text = 'My Location';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continue() async {
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) {
      setState(() => _error = 'Please enter a delivery address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final loc = await MapsService.geocode(dest);
      if (loc == null) throw Exception('Location not found');

      final mapSettings = ref.read(mapSettingsProvider).valueOrNull;
      final boundary    = (mapSettings?['boundary']    as List?)  ?? const [];
      final enforcement = (mapSettings?['enforcement'] as bool?)  ?? false;
      if (!BoundaryService.isAllowed(
        lat: loc.lat, lng: loc.lng,
        boundary: boundary, enforcement: enforcement,
      )) {
        setState(() => _error = 'That delivery address is outside our service area.');
        return;
      }

      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            bookingType:        'delivery',
            destinationAddress: loc.formattedAddress,
            destinationLat:     loc.lat,
            destinationLng:     loc.lng,
          ));

      if (!mounted) return;
      context.push(AppRoutes.courierReceiveDetails);
    } catch (_) {
      setState(() => _error = 'Could not find that address. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadingOverlay.wrap(
        loading: _loading,
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: const BackButton(color: AppColors.textPrimary),
            title: Text(AppStrings.sendPackage, style: AppTextStyles.h4),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Illustration
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _EmbeddedPngFromSvgAsset(
                          assetPath: AppAssets.courierIcon,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(AppStrings.fastDelivery,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 28),

                AppTextField(
                  controller: _pickupCtrl,
                  label: 'Pickup Location',
                  hint: 'Your current location',
                  suffixIcon: SvgPicture.asset(
                    AppAssets.mapPin,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(AppColors.pickupPin, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _destCtrl,
                  label: 'Delivery Address',
                  hint: 'Where should we deliver?',
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _continue(),
                  suffixIcon: SvgPicture.asset(
                    AppAssets.mapPin,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(AppColors.destinationPin, BlendMode.srcIn),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ],

                const SizedBox(height: 32),
                AppButton(label: AppStrings.continueBtn, onPressed: _continue),
              ],
            ),
          ),
        ),
      );
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
