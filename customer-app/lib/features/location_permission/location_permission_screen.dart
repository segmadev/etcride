import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_back_button.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  Future<void> _allow(BuildContext context) async {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const AppBackButton(),
              const Spacer(flex: 2),

              // ── Illustration ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, size: 56, color: AppColors.primary),
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
