import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_gateway_model.dart';
import '../providers/payment_providers.dart';

class PaymentMethodSelector extends ConsumerWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewaysAsync = ref.watch(paymentGatewaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        gatewaysAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 48,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Failed to load payment methods',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          data: (gateways) {
            // Add cash option (always available)
            final allOptions = [
              (
                name: 'cash',
                label: 'Cash',
                icon: '💵',
                method: PaymentMethod.cash,
              ),
              ...gateways.map((g) => (
                    name: g.name,
                    label: g.displayName,
                    icon: g.icon,
                    method: PaymentMethod.fromString(g.name),
                  )),
            ];

            return Column(
              children: allOptions.map((opt) {
                final gatewayConfig = gateways.firstWhere(
                  (g) => g.name == opt.name,
                  orElse: () => PaymentGatewayModel(
                    id: 0,
                    name: opt.name,
                    displayName: opt.label,
                  ),
                );

                return _Tile(
                  label: opt.label,
                  icon: opt.icon,
                  selected: selected == opt.method,
                  enabled: enabled,
                  minAmount: gatewayConfig.minAmount,
                  maxAmount: gatewayConfig.maxAmount,
                  onTap: enabled ? () => onChanged(opt.method) : null,
                );
              }).toList(),
            );
          },
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
    this.onTap,
    this.minAmount = 0,
    this.maxAmount = 999999.99,
  });

  final String icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final double minAmount;
  final double maxAmount;

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
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (minAmount > 0 || maxAmount < 999999.99)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '₦${minAmount.toStringAsFixed(0)} - ₦${maxAmount.toStringAsFixed(0)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
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
