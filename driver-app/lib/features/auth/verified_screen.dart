import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';

class DriverVerifiedScreen extends StatelessWidget {
  const DriverVerifiedScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 40),
          child: Column(
            children: [
              const Spacer(),

              // Animated checkmark
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2A322).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: Color(0xFFE2A322),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'You\'re Verified!',
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              Text(
                message ??
                    'Your identity has been confirmed.\nYou can now start accepting rides.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              AppButton(
                label:     'GO TO DASHBOARD',
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
