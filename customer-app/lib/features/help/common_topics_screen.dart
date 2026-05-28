import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/router.dart';

class CommonTopicsScreen extends StatelessWidget {
  const CommonTopicsScreen({super.key, required this.category});
  final String category;

  static const _topics = <String, List<String>>{
    'Account & Profile': [
      'My Account is blocked',
      'How to change my info?',
      'How to delete my account',
      'Change phone number',
    ],
    'Payments & Wallet': [
      'Why was I charged extra?',
      'How do I add payment method?',
      'Refunds and disputes',
    ],
    'Trips & Deliveries': [
      'How do I cancel a ride?',
      'Driver arrived, what next?',
      'Delivery rules',
    ],
    'Safety': [
      'Report safety concerns',
      'Emergency contacts',
      'Rider guidelines',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final items = _topics[category] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: [
            SizedBox(
              height: 74,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _CircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => context.pop(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('Common Topics', style: AppTextStyles.h2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(category, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            for (final t in items) ...[
              _TopicRow(
                label: t,
                onTap: () => context.push(
                  AppRoutes.commonTopicDetail,
                  extra: {'category': category, 'topic': t},
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
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

