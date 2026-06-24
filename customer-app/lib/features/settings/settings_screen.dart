import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricsAvailable = false;
  bool _biometricsEnabled   = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final bio = BiometricService.instance;
    final available = await bio.isAvailable;
    final enabled   = available ? await bio.isEnabled : false;
    if (mounted) setState(() { _biometricsAvailable = available; _biometricsEnabled = enabled; });
  }

  Future<void> _toggleBiometrics(bool value) async {
    // If enabling, require biometric authentication to confirm device ownership
    if (value) {
      try {
        final authenticated = await BiometricService.instance.authenticate();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication canceled.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Keep toggle disabled
          if (mounted) setState(() => _biometricsEnabled = false);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        // Keep toggle disabled
        if (mounted) setState(() => _biometricsEnabled = false);
        return;
      }
    }
    // Either disabling, or authentication succeeded
    await BiometricService.instance.setEnabled(enabled: value);
    if (mounted) setState(() => _biometricsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: [
            _Header(
              title: AppStrings.settingsTitle,
              onMenu: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
            ),
            const SizedBox(height: 22),

            _SectionTitle('Account'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.person_outline_rounded,
                label: AppStrings.profile,
                onTap: () => context.push(AppRoutes.profile),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.account_balance_wallet_outlined,
                label: AppStrings.walletPayments,
                badge: const _ComingSoonPill(),
                onTap: () => _comingSoon(context),
              ),
            ),

            const SizedBox(height: 26),
            _SectionTitle('Preferences'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.notifications_none_rounded,
                label: AppStrings.notifications,
                onTap: () => context.push(AppRoutes.notifications),
              ),
            ),
            if (_biometricsAvailable) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _SettingsToggleRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometric Sign-In',
                  value: _biometricsEnabled,
                  onChanged: _toggleBiometrics,
                ),
              ),
            ],

            const SizedBox(height: 26),
            _SectionTitle('About'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.description_outlined,
                label: AppStrings.legalDocuments,
                onTap: () => context.push(AppRoutes.legalDocuments),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.grid_view_rounded,
                label: AppStrings.appVersion,
                subtitle: '1.0',
                showChevron: false,
              ),
            ),

            const SizedBox(height: 26),
            _SectionTitle('Security'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.logout_rounded,
                label: AppStrings.logout,
                onTap: () async {
                  await ref.read(authRepositoryProvider).logout();
                  ref.read(currentUserProvider.notifier).state = null;
                  if (context.mounted) context.go(AppRoutes.phone);
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _SettingsRow(
                icon: Icons.delete_outline_rounded,
                label: AppStrings.deleteAccount,
                labelColor: AppColors.error,
                iconColor: AppColors.error,
                chevronColor: AppColors.error,
                onTap: () => _showDeleteDialog(context, ref),
              ),
            ),
          ],
        ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onMenu,
  });

  final String title;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onMenu,
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
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Text(title, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700));
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.badge,
    this.onTap,
    this.showChevron = true,
    this.labelColor = AppColors.textPrimary,
    this.iconColor = AppColors.textPrimary,
    this.chevronColor = AppColors.textHint,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color labelColor;
  final Color iconColor;
  final Color chevronColor;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 10),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 22),
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'COMING SOON!',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.2,
          ),
        ),
      );
}
