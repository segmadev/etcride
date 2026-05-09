import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../auth/complete_profile_screen.dart';
import '../../booking/search_destination_screen.dart';
import '../../../shared/providers/providers.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isComplete = user != null && user.name.isNotEmpty;

    return Drawer(
      backgroundColor: AppColors.white,
      width: MediaQuery.of(context).size.width * 0.72,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person_rounded, size: 36, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text('${AppStrings.hello} 👋', style: AppTextStyles.h2),
                    ],
                  ),

                  if (isComplete) ...[
                    const SizedBox(height: 4),
                    Text(user.name, style: AppTextStyles.h4),
                    Text('Passenger', style: AppTextStyles.bodySmall),
                  ] else ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () { Navigator.pop(context); showCompleteProfileDrawer(context); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(AppStrings.completeYourProfile,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
                              fontWeight: FontWeight.w600, color: AppColors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 24),

            // ── Nav items ────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(AppStrings.bookATrip, Icons.directions_car_outlined, () {
                    Navigator.pop(context);
                    showSearchDestinationDrawer(context);
                  }),
                  _DrawerItem(AppStrings.sendAPackage, Icons.inventory_2_outlined, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.courier);
                  }),
                  _DrawerItem(AppStrings.myTripHistory, Icons.history_rounded, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.tripHistory);
                  }),
                  _DrawerItem(AppStrings.settings, Icons.settings_outlined, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.settings);
                  }),
                  _DrawerItem(AppStrings.help, Icons.help_outline_rounded, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.help);
                  }),
                  _DrawerItem(AppStrings.support, Icons.headset_mic_outlined, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.contactSupport);
                  }),
                ],
              ),
            ),

            // ── Logout ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: () async {
                  await ref.read(authRepositoryProvider).logout();
                  ref.read(currentUserProvider.notifier).state = null;
                  if (context.mounted) context.go(AppRoutes.phone);
                },
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
                    const SizedBox(width: 12),
                    Text(AppStrings.logout,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: AppColors.textPrimary),
    title: Text(label, style: AppTextStyles.bodyLarge),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}
