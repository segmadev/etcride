import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/live_chat_widget.dart';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(String? email) async {
    if (email == null || email.trim().isEmpty) return;
    final uri = Uri.parse('mailto:${email.trim()}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commonAsync = ref.watch(commonDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(),
              const SizedBox(height: 20),
              Text('Help & Support', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Reach out to us if you need assistance with the app or a trip.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              commonAsync.when(
                data: (details) {
                  final phone = details['support_phone']?.toString();
                  final email = details['support_email']?.toString();
                  return Column(
                    children: [
                      _SupportRow(
                        icon: Icons.call_outlined,
                        label: 'Call Support',
                        value: (phone?.isNotEmpty ?? false) ? phone! : 'Not available',
                        onTap: (phone?.isNotEmpty ?? false) ? () => _call(phone) : null,
                      ),
                      const SizedBox(height: 12),
                      _SupportRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email Support',
                        value: (email?.isNotEmpty ?? false) ? email! : 'Not available',
                        onTap: (email?.isNotEmpty ?? false) ? () => _email(email) : null,
                      ),
                      const SizedBox(height: 12),
                      LiveChatButton(
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      _SupportRow(
                        icon: Icons.description_outlined,
                        label: 'Legal Documents',
                        value: 'Terms & Conditions and Privacy Policy',
                        onTap: () => context.push(AppRoutes.legalDocuments),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(
                  'Could not load support details.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.h4),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
