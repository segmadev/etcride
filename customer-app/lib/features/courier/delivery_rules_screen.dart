import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../booking/select_ride_screen.dart';

class DeliveryRulesScreen extends StatelessWidget {
  const DeliveryRulesScreen({super.key});

  static const _rules = [
    (
      'No dangerous items',
      'Firearms, explosives, or hazardous chemicals are strictly prohibited.',
      Icons.dangerous_rounded,
    ),
    (
      'No illegal items',
      'Drugs or any other illegal substances are not accepted.',
      Icons.block_rounded,
    ),
    (
      'Package weight limit',
      'Maximum package weight is 20 kg per delivery.',
      Icons.scale_rounded,
    ),
    (
      'Fragile items',
      'Please declare if your package is fragile so it can be handled carefully.',
      Icons.local_shipping_rounded,
    ),
    (
      'Accurate description',
      'Provide an accurate description of the package contents.',
      Icons.description_rounded,
    ),
    (
      'Recipient availability',
      'Ensure the recipient is available to receive the package at delivery time.',
      Icons.person_pin_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(AppStrings.deliveryRules, style: AppTextStyles.h4),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(AppStrings.deliveryRulesSub,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.black)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rules list
                    ..._rules.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(r.$3,
                                    size: 20, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.$1,
                                        style: AppTextStyles.bodyLarge),
                                    const SizedBox(height: 2),
                                    Text(r.$2,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color:
                                                    AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: AppButton(
                label: AppStrings.gotIt,
                onPressed: () => showSelectRideDrawer(context),
              ),
            ),
          ],
        ),
      );
}
