import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Circular back button matching the Figma design (circle with border).
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap, this.color});
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap ?? () => Navigator.of(context).maybePop(),
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? AppColors.white,
        border: Border.all(color: AppColors.divider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
    ),
  );
}
