import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';

class KycPendingScreen extends ConsumerWidget {
  const KycPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 40, 26, 40),
          child: Column(
            children: [
              const Spacer(),

              // Illustration
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2A322).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 58,
                    color: Color(0xFFE2A322),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Application\nUnder Review',
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Hi ${driver?.name.split(' ').first ?? 'there'}, your verification documents have been submitted successfully.\n\nOur team will review your application and notify you once approved. This usually takes 1–2 business days.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text:
                          'You will receive an email notification when your account is approved.',
                    ),
                    const Divider(height: 20),
                    _InfoRow(
                      icon: Icons.admin_panel_settings_outlined,
                      text:
                          'An admin can also manually verify your account to speed up the process.',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Log out option
              AppButton(
                label:    'SIGN OUT',
                variant:  AppButtonVariant.ghost,
                onPressed: () async {
                  await ref.read(driverAuthRepositoryProvider).logout();
                  ref.read(currentDriverProvider.notifier).state = null;
                  if (!context.mounted) return;
                  context.go(AppRoutes.signIn);
                },
              ),

              const SizedBox(height: 16),

              // Refresh / check status
              const _RefreshButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton();

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      // Always fetch fresh data from the backend — never rely on local cache.
      final driver = await ref.read(driverAuthRepositoryProvider).getProfile();

      // Keep the in-memory provider in sync so every other screen reflects it.
      ref.read(currentDriverProvider.notifier).state = driver;

      if (!mounted) return;

      switch (driver.kycStatus) {
        case 'verified':
          context.go(AppRoutes.verified);
        case 'rejected':
          context.go(AppRoutes.kyc);
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Still under review. We'll notify you when approved."),
            ),
          );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reach server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: _checking ? null : _check,
        child: _checking
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Check Status',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      );
}
