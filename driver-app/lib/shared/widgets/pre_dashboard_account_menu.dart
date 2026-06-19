import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/providers.dart';

class PreDashboardAccountMenu extends ConsumerWidget {
  const PreDashboardAccountMenu({
    super.key,
    this.compact = false,
  });

  final bool compact;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(driverAuthRepositoryProvider).logout();
    ref.read(currentDriverProvider.notifier).state = null;
    if (!context.mounted) {
      return;
    }
    context.go(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account actions',
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      position: PopupMenuPosition.under,
      onSelected: (action) async {
        switch (action) {
          case _AccountAction.editProfile:
            context.push(AppRoutes.driverProfile);
          case _AccountAction.logout:
            await _logout(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          value: _AccountAction.editProfile,
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Text(
                'Edit Profile',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_AccountAction>(
          value: _AccountAction.logout,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text(
                'Log Out',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: compact ? 38 : 42,
        height: compact ? 38 : 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: AppColors.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}

enum _AccountAction {
  editProfile,
  logout,
}
