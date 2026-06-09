import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

enum AppButtonVariant { primary, primaryAmber, secondary, ghost }

/// Reusable full-width pill button matching the Figma design.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.enabled = true,
    this.icon,
    this.height = 56.0,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool enabled;
  final Widget? icon;
  final double height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !loading;

    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = isEnabled ? AppColors.black : AppColors.disabled;
        fg = AppColors.white;
      case AppButtonVariant.primaryAmber:
        bg = isEnabled ? AppColors.primary : AppColors.disabled;
        fg = AppColors.white;
      case AppButtonVariant.secondary:
        bg = AppColors.inputFill;
        fg = AppColors.textPrimary;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        border = Border.all(color: AppColors.divider);
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(height / 2),
            border: border,
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      IconTheme(data: IconThemeData(color: fg, size: 18), child: icon!),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: fg,
                        fontSize: fontSize,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Small pill button used for tags (e.g. "COMING SOON!", "NEW").
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.success,
    this.textColor = AppColors.white,
  });
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: textColor, letterSpacing: 0.4,
        fontFamily: 'Inter',
      ),
    ),
  );
}
