import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/services/chat_notification_service.dart';
import '../../../shared/widgets/live_chat_widget.dart';
import '../../auth/complete_profile_screen.dart';
import '../../booking/search_destination_screen.dart';
import '../../../shared/providers/providers.dart';
import './home_bottom_sheet.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  String _titleCaseName(String v) {
    final cleaned = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : (w.length == 1
                ? w.toUpperCase()
                : (w[0].toUpperCase() + w.substring(1).toLowerCase())))
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(authInitProvider);
    final user = ref.watch(currentUserProvider);
    final initializing = init.isLoading && user == null;
    final isComplete = user != null &&
        user.name.isNotEmpty &&
        (user.phone.isNotEmpty || user.email.isNotEmpty);

    return Drawer(
      backgroundColor: AppColors.white,
      width: MediaQuery.of(context).size.width * 0.72,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(Icons.person_rounded, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text('${AppStrings.hello} 👋', style: AppTextStyles.h2),
                    ],
                  ),

                  if (!initializing && isComplete) ...[
                    const SizedBox(height: 4),
                    Text(_titleCaseName(user.name), style: AppTextStyles.h4),
                    Text('Passenger', style: AppTextStyles.bodySmall),
                  ] else ...[
                    const SizedBox(height: 8),
                    if (!initializing)
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

            const Divider(height: 30),

            // ── Nav items ────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 10),
                  _DrawerItem.svg(
                    AppStrings.bookATrip,
                    onTap: () {
                      Navigator.pop(context);
                      showSearchDestinationDrawer(context);
                    },
                  ),
                  _DrawerItem.svg(
                    AppStrings.sendAPackage,
                    onTap: () {
                      Navigator.pop(context);
                      _showCourierModal(context);
                    },
                  ),
                  _DrawerItem(AppStrings.myTripHistory, null, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.tripHistory);
                  }),
                  ValueListenableBuilder<Map<String, int>>(
                    valueListenable: ChatNotificationService.instance.unreadCounts,
                    builder: (_, counts, __) {
                      final total = counts.values.fold(0, (s, n) => s + n);
                      return _DrawerItem(
                        'Messages',
                        null,
                        () {
                          Navigator.pop(context);
                          context.push(AppRoutes.chatHistory);
                        },
                        badge: total > 0 ? (total > 99 ? '99+' : '$total') : null,
                      );
                    },
                  ),
                  _DrawerItem(AppStrings.settings, null, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.settings);
                  }),
                  _DrawerItem(AppStrings.help, null, () {
                    Navigator.pop(context);
                    context.push(AppRoutes.help);
                  }),
                  const SizedBox(height: 8),
                  LiveChatButton(
                    style: AppTextStyles.bodyMedium,
                  ),
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
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourierModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HomeBottomSheet(initialCourierMode: true),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(
    this.label,
    this.icon,
    this.onTap, {
    this.badge,
  }) : iconWidget = null;

  const _DrawerItem.svg(
    this.label, {
    required this.onTap,
    this.badge,
  })  : icon = null,
        iconWidget = null;

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
