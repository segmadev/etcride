import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/router.dart';

class CommonTopicDetailScreen extends StatelessWidget {
  const CommonTopicDetailScreen({
    super.key,
    required this.category,
    required this.topic,
  });

  final String category;
  final String topic;

  @override
  Widget build(BuildContext context) {
    final content = _topicContent(category: category, topic: topic);

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
                    child: Text(topic, style: AppTextStyles.h2, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...content,
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.contactSupport),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  'CONTACT SUPPORT',
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

List<Widget> _topicContent({required String category, required String topic}) {
  if (category == 'Account & Profile' && topic == 'My Account is blocked') {
    return [
      Text('Why is my account blocked?', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(
        'Your account may be temporarily restricted if we detect unusual activity or a possible violation of our policies. This helps us keep your account and the platform safe for everyone.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 22),
      Text('Common reasons this may happen', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      _Bullets(
        items: const [
          'Multiple failed login attempts',
          'Suspicious or unusual activity on your account',
          'Violation of our Terms of Use',
          'Payment-related issues or disputes',
          'Reports from drivers or other users',
        ],
      ),
      const SizedBox(height: 22),
      Text('Is the restriction permanent?', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(
        'Not always. Some restrictions are temporary and may be lifted automatically after a review. In other cases, further verification may be required.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
    ];
  }

  return [
    Text('Details', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Text(
      'Information for this topic will be available soon.',
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    ),
  ];
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.circle, size: 6, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

