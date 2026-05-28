import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _faqs = const [
    (
      'How do I cancel a ride?',
      'You can cancel a ride before the driver arrives from the trip screen. Cancellation fees may apply depending on how long the driver has been assigned.',
    ),
    (
      'Why was I charged extra?',
      'Extra charges can happen due to route changes, tolls, or waiting time. Contact support if you believe it was incorrect.',
    ),
    (
      'How do I add payment method?',
      'Go to the payment selection screen during booking and choose your preferred payment method.',
    ),
  ];

  int _expanded = 0;

  Future<void> _viewAllFaqs() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 16),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(AppStrings.faqs, style: AppTextStyles.h3),
              const SizedBox(height: 16),
              ..._faqs.map((faq) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FaqCard(
                    question: faq.$1,
                    answer: faq.$2,
                    expanded: false,
                    onTap: () {},
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: [
            SizedBox(
              height: 72,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _CircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.home);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(AppStrings.helpSupport, style: AppTextStyles.h2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Get Help Fast', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _RowNav(
              icon: Icons.local_offer_outlined,
              label: AppStrings.reportAnIssue,
              onTap: () => context.push(AppRoutes.reportIssue),
            ),
            const SizedBox(height: 8),
            _RowNav(
              icon: Icons.headset_mic_outlined,
              label: AppStrings.contactSupport,
              onTap: () => context.push(AppRoutes.contactSupport),
            ),
            const SizedBox(height: 22),
            Text('Common Topics', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TopicTile(
                    label: 'Payments & Wallet',
                    onTap: () => context.push(AppRoutes.commonTopics, extra: 'Payments & Wallet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopicTile(
                    label: 'Trips & Deliveries',
                    onTap: () => context.push(AppRoutes.commonTopics, extra: 'Trips & Deliveries'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TopicTile(
                    label: 'Account & Profile',
                    onTap: () => context.push(AppRoutes.commonTopics, extra: 'Account & Profile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopicTile(
                    label: 'Safety',
                    onTap: () => context.push(AppRoutes.commonTopics, extra: 'Safety'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(AppStrings.faqs, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (var i = 0; i < _faqs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FaqCard(
                  question: _faqs[i].$1,
                  answer: _faqs[i].$2,
                  expanded: _expanded == i,
                  onTap: () => setState(() => _expanded = _expanded == i ? -1 : i),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _viewAllFaqs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  'VIEW ALL FAQS',
                  style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _RowNav extends StatelessWidget {
  const _RowNav({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            SizedBox(width: 34, child: Icon(icon, size: 20, color: AppColors.textPrimary)),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      answer,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              expanded ? Icons.remove : Icons.add,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
