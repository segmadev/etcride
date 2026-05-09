import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.settingsTitle, style: AppTextStyles.h4),
      ),
      body: ListView(
        children: [
          // ── Account ────────────────────────────────────────────────────────
          _SectionHeader('Account'),
          _SettingsTile(
            Icons.person_rounded,
            AppStrings.profile,
            () => context.push(AppRoutes.profile),
          ),
          _SettingsTile(
            Icons.notifications_rounded,
            AppStrings.notifications,
            () => context.push(AppRoutes.notifications),
          ),

          // ── Payments ───────────────────────────────────────────────────────
          _SectionHeader('Payments'),
          _SettingsTile(
            Icons.account_balance_wallet_rounded,
            AppStrings.walletPayments,
            () => _comingSoon(context),
            trailing: _ComingSoonBadge(),
          ),

          // ── Support ────────────────────────────────────────────────────────
          _SectionHeader('Support'),
          _SettingsTile(
            Icons.help_outline_rounded,
            AppStrings.helpSupport,
            () => context.push(AppRoutes.help),
          ),
          _SettingsTile(
            Icons.gavel_rounded,
            AppStrings.legalDocuments,
            () => context.push(AppRoutes.legalDocuments),
          ),

          // ── App ────────────────────────────────────────────────────────────
          _SectionHeader('App'),
          _SettingsTile(
            Icons.info_outline_rounded,
            AppStrings.appVersion,
            null,
            trailing: Text('1.0.0',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // ── Logout ─────────────────────────────────────────────────────────
          ListTile(
            leading:
                const Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text(AppStrings.logout,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.error)),
            onTap: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(currentUserProvider.notifier).state = null;
              if (context.mounted) context.go(AppRoutes.phone);
            },
          ),

          // ── Delete account ─────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: AppColors.error),
            title: Text(AppStrings.deleteAccount,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
            onTap: () => _showDeleteDialog(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.comingSoon)),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account?', style: AppTextStyles.h4),
        content: Text(
          'This action is permanent and cannot be undone. All your data will be lost.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).logout();
              ref.read(currentUserProvider.notifier).state = null;
              if (context.mounted) context.go(AppRoutes.phone);
            },
            child: Text('Delete',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(this.icon, this.label, this.onTap, {this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 22, color: AppColors.textPrimary),
        title: Text(label, style: AppTextStyles.bodyLarge),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        onTap: onTap,
      );
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('Soon',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.primary)),
      );
}
