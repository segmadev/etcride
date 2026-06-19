import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Back control with icon and label matching the app design.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap, this.color, this.textColor});
  final VoidCallback? onTap;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap ?? () => Navigator.of(context).maybePop(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? AppColors.white,
            border: Border.all(color: AppColors.divider, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: textColor ?? AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Back',
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor ?? AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
