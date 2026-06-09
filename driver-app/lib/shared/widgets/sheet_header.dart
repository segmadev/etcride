import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, this.title, this.onClose});

  final String? title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null || onClose != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(title!, style: AppTextStyles.h4),
                  ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
