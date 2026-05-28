import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../shared/widgets/app_button.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  Future<void> _allow(BuildContext context) async {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final scheme = Uri.base.scheme.toLowerCase();
      final isLocalhost = host == 'localhost' || host == '127.0.0.1';
      final isSecureOrigin = scheme == 'https' || isLocalhost;
      if (!isSecureOrigin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission on web requires HTTPS (or localhost).'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Click the lock icon in your browser address bar and allow Location.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!context.mounted) return;
        context.go(AppRoutes.home);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location request failed. Please allow Location in your browser settings.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final status = await Permission.locationWhenInUse.request();
    if (!context.mounted) return;
    if (status.isGranted) {
      context.go(AppRoutes.home);
      return;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location permission is required to use maps and search.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Back',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),

              // ── Illustration ─────────────────────────────────────────────
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: _EmbeddedPngFromSvgAsset(
                    assetPath: AppAssets.worldLocation,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Text ─────────────────────────────────────────────────────
              Text(AppStrings.enableLocation, style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                AppStrings.enableLocationSub,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // ── Privacy note ─────────────────────────────────────────────
              Text(
                AppStrings.locationPrivacy,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Allow button ─────────────────────────────────────────────
              AppButton(label: AppStrings.allowLocation, onPressed: () => _allow(context)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final BoxFit fit;

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
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
