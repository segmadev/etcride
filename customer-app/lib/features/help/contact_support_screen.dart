import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() =>
      _ContactSupportScreenState();
}

class _ContactSupportScreenState
    extends ConsumerState<ContactSupportScreen> {
  final _msgCtrl = TextEditingController();
  String _supportEmail = 'support@etcride.ng';
  String _supportPhone = '';

  @override
  void initState() {
    super.initState();
    _loadCommonDetails();
  }

  Future<void> _loadCommonDetails() async {
    try {
      final data =
          await ref.read(contentRepositoryProvider).getCommonDetails();
      if (mounted) {
        setState(() {
          _supportEmail =
              data['support_email']?.toString().isNotEmpty == true
                  ? data['support_email']!.toString()
                  : _supportEmail;
          _supportPhone =
              data['support_phone']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(AppStrings.contactSupport, style: AppTextStyles.h4),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Illustration
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headset_mic_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.getHelpFast,
                  style: AppTextStyles.h3, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Our team is ready to assist you with any questions or issues.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Phone
              if (_supportPhone.isNotEmpty) ...[
                _ContactOption(
                  icon: Icons.call_rounded,
                  label: 'Call Support',
                  subtitle: _supportPhone,
                  color: AppColors.success,
                  onTap: () =>
                      launchUrl(Uri.parse('tel:$_supportPhone')),
                ),
                const SizedBox(height: 12),
              ],

              // Email
              _ContactOption(
                icon: Icons.email_rounded,
                label: 'Email Support',
                subtitle: _supportEmail,
                color: AppColors.primary,
                onTap: () =>
                    launchUrl(Uri.parse('mailto:$_supportEmail')),
              ),

              const SizedBox(height: 32),

              // Compose
              AppTextField(
                controller: _msgCtrl,
                label: 'Send a message',
                hint: 'Describe your issue...',
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),

              AppButton(
                label: 'SEND VIA EMAIL',
                onPressed: () {
                  final body =
                      Uri.encodeComponent(_msgCtrl.text.trim());
                  launchUrl(Uri.parse(
                      'mailto:$_supportEmail?subject=Support%20Request&body=$body'));
                },
              ),
            ],
          ),
        ),
      );
}

class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodyLarge),
                    Text(subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      );
}
