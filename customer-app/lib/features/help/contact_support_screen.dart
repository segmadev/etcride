import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const active = [
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
    ];

    const closed = [
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
      (
        'How satisfied are you with our support?',
        'It is clear that the situation was certainly the fault of the ...',
        'Apr 22 • 9:03AM',
      ),
    ];

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
                    child: Text('All Messages', style: AppTextStyles.h2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Active', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final m in active) ...[
              _MessageRow(title: m.$1, subtitle: m.$2, date: m.$3),
              const Divider(height: 1),
            ],
            const SizedBox(height: 22),
            Text('Closed', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Opacity(
              opacity: 0.35,
              child: Column(
                children: [
                  for (final m in closed) ...[
                    _MessageRow(title: m.$1, subtitle: m.$2, date: m.$3),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.title, required this.subtitle, required this.date});
  final String title;
  final String subtitle;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
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
