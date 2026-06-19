import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;
  final bool enabled;

  static const _options = [
    (method: PaymentMethod.cash,        icon: Icons.money_rounded,       label: 'Cash'),
    (method: PaymentMethod.flutterwave, icon: Icons.credit_card_rounded,  label: 'Card / Flutterwave'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        ..._options.map((opt) => _Tile(
              icon: opt.icon,
              label: opt.label,
              selected: selected == opt.method,
              enabled: enabled,
              onTap: enabled ? () => onChanged(opt.method) : null,
            )),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
