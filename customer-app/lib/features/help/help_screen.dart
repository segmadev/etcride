import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How do I book a ride?',
      'Tap "Where to?" on the home screen, search for your destination, confirm your pickup, choose a vehicle type, and confirm the ride.',
    ),
    (
      'How is the fare calculated?',
      'Fares are calculated based on distance, vehicle type, and applicable zone pricing. You see an estimate before confirming.',
    ),
    (
      'What if my driver doesn\'t show up?',
      'You can cancel the request from the Requesting screen and try again, or contact our support team.',
    ),
    (
      'How do I send a package?',
      'Tap "Couriers" on the home screen or "Send a package" in the menu, enter pickup and delivery address, fill in recipient details, and confirm.',
    ),
    (
      'How do I pay?',
      'You can pay with cash or bank transfer. Select your payment method when confirming your ride.',
    ),
    (
      'How do I report an issue?',
      'Go to Help → Report an Issue and describe the problem. Our team responds within 24 hours.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(AppStrings.helpSupport, style: AppTextStyles.h4),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Quick action cards
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.headset_mic_rounded,
                    label: AppStrings.contactSupport,
                    color: AppColors.primary,
                    onTap: () => context.push(AppRoutes.contactSupport),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.flag_rounded,
                    label: AppStrings.reportAnIssue,
                    color: AppColors.error,
                    onTap: () => context.push(AppRoutes.reportIssue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Text(AppStrings.faqs, style: AppTextStyles.h4),
            const SizedBox(height: 16),

            ..._faqs.map((faq) =>
                _FaqTile(question: faq.$1, answer: faq.$2)),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      );
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question, answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              title: Text(widget.question, style: AppTextStyles.bodyLarge),
              trailing: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded,
                    color: AppColors.textSecondary),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(widget.answer,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
}
