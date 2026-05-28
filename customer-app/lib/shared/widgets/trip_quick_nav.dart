import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';

// ── Floating map overlay button (circle with shadow) ─────────────────────────

class MapOverlayButton extends StatelessWidget {
  const MapOverlayButton({super.key, required this.icon, required this.onTap, this.color, this.iconWidget});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: iconWidget ??
              Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
        ),
      );
}

// ── Top-left row: [menu]  ···  [home] ────────────────────────────────────────

class TripTopBar extends StatelessWidget {
  const TripTopBar({super.key, this.showHome = true, this.trailing});
  final bool showHome;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              MapOverlayButton(
                icon: Icons.menu_rounded,
                iconWidget: SvgPicture.asset(
                  AppAssets.menuIcon,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                ),
                onTap: () => _showQuickNav(context),
              ),
              const Spacer(),
              if (trailing != null) trailing!
              else if (showHome)
                MapOverlayButton(
                  icon: Icons.home_rounded,
                  onTap: () => context.go(AppRoutes.home),
                ),
            ],
          ),
        ),
      );
}

// ── Quick-nav bottom sheet ────────────────────────────────────────────────────

void _showQuickNav(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickNavSheet(parentContext: context),
  );
}

class _QuickNavSheet extends ConsumerWidget {
  const _QuickNavSheet({required this.parentContext});
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    void nav(String route) {
      Navigator.pop(context);   // close sheet
      parentContext.go(route);
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 8, 0, MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // User header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person_rounded,
                      size: 24, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name.isNotEmpty == true ? user!.name : 'Guest',
                          style: AppTextStyles.labelLarge),
                      Text('Passenger',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Go Home (prominent) ──────────────────────────────────────────
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Back to Home',
            color: AppColors.primary,
            onTap: () => nav(AppRoutes.home),
          ),

          _NavItem(
            icon: Icons.history_rounded,
            label: 'My Trip History',
            onTap: () => nav(AppRoutes.tripHistory),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: () => nav(AppRoutes.profile),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => nav(AppRoutes.settings),
          ),
          _NavItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => nav(AppRoutes.help),
          ),

          const Divider(height: 1),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 22, color: color ?? AppColors.textPrimary),
        title: Text(label,
            style: AppTextStyles.bodyLarge
                .copyWith(color: color ?? AppColors.textPrimary)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      );
}
