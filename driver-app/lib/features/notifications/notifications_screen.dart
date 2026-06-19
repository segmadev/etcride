import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_back_button.dart';

class DriverNotificationsScreen extends ConsumerWidget {
  const DriverNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(driverNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(),
              const SizedBox(height: 20),
              Text('Notifications', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(driverNotificationsProvider);
                    await ref.read(driverNotificationsProvider.future);
                  },
                  child: notifsAsync.when(
                    data: (notifs) {
                      if (notifs.isEmpty) {
                        return ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No notifications yet.',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        itemCount: notifs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _NotificationCard(
                          notif: notifs[i],
                          onTap: () async {
                            final id = notifs[i]['id']?.toString();
                            if (id == null) return;
                            await ref.read(driverRepositoryProvider).markNotificationRead(id);
                            ref.invalidate(driverNotificationsProvider);
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: Text(
                        'Could not load notifications.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notif, required this.onTap});
  final Map<String, dynamic> notif;
  final VoidCallback onTap;

  bool get _isUnread {
    final v = notif['is_read'];
    return !(v == 1 || v == '1' || v == true);
  }

  @override
  Widget build(BuildContext context) {
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final unread = _isUnread;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? AppColors.notifBg : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread ? AppColors.notifAccent : Colors.transparent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
