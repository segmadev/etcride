import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_gateway_model.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.gateways,
    this.enabled = true,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;
  final List<PaymentGatewayModel> gateways;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        if (gateways.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No payment methods available.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          )
        else
          Column(
            children: gateways.map((g) {
              final method = PaymentMethod.fromString(g.name);
              return _Tile(
                label: g.displayName.isNotEmpty ? g.displayName : g.name,
                icon: g.icon,
                logoUrl: g.logoUrl,
                selected: selected == method,
                enabled: enabled,
                onTap: enabled ? () => onChanged(method) : null,
              );
            }).toList(),
          ),
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
    this.logoUrl,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final bool enabled;
  final String? logoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            SizedBox(
              width: 32,
              height: 32,
              child: logoUrl != null && logoUrl!.isNotEmpty
                  ? Image.network(
                      logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Text(icon, style: const TextStyle(fontSize: 20)),
                    )
                  : Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
