import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LOCATION PERMISSION SCREEN
//
//  Shown (via Navigator.push) when the driver tries to go online but hasn't
//  granted location permission yet.
//
//  Returns:
//    true  — permission was granted (caller may proceed)
//    false — user dismissed or permission permanently denied
// ─────────────────────────────────────────────────────────────────────────────

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final perm = await Geolocator.requestPermission();
      if (!mounted) return;
      final granted = perm == LocationPermission.always ||
                      perm == LocationPermission.whileInUse;
      Navigator.of(context).pop(granted);
    } catch (_) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
    if (!mounted) return;
    // After returning from settings, re-check
    final perm = await Geolocator.checkPermission();
    if (!mounted) return;
    final granted = perm == LocationPermission.always ||
                    perm == LocationPermission.whileInUse;
    Navigator.of(context).pop(granted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),

              const Spacer(),

              // Illustration
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3CD), // light amber
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 60,
                      color: Color(0xFFE2A322),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Title
              Text(
                'Enable Location Access',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 14),

              // Body
              Text(
                'To receive nearby trip assignments and keep your position updated, '
                'EtcRide needs access to your device location.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // Bullet points
              _PermissionBullet(
                icon: Icons.near_me_rounded,
                text: 'Get matched to trips closest to you',
              ),
              _PermissionBullet(
                icon: Icons.update_rounded,
                text: 'Your location updates automatically while you\'re online',
              ),
              _PermissionBullet(
                icon: Icons.lock_outline_rounded,
                text: 'Location is only shared when you are online and working',
              ),

              const Spacer(),

              // Primary action
              FutureBuilder<LocationPermission>(
                future: Geolocator.checkPermission(),
                builder: (context, snap) {
                  final perm = snap.data;
                  final isPermanentlyDenied =
                      perm == LocationPermission.deniedForever;

                  if (isPermanentlyDenied) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Location permission is blocked. Open App Settings to allow it.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'OPEN APP SETTINGS',
                          variant: AppButtonVariant.primary,
                          height: 54,
                          onPressed: _openSettings,
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Not Now',
                          variant: AppButtonVariant.ghost,
                          height: 48,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'ALLOW LOCATION ACCESS',
                        variant: AppButtonVariant.primary,
                        loading: _requesting,
                        height: 54,
                        onPressed: _requesting ? null : _requestPermission,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Not Now',
                        variant: AppButtonVariant.ghost,
                        height: 48,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission bullet ─────────────────────────────────────────────────────────

class _PermissionBullet extends StatelessWidget {
  const _PermissionBullet({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3CD),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 16, color: const Color(0xFFE2A322)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
