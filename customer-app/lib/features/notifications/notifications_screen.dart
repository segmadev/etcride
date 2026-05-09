import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../booking/search_destination_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<List<dynamic>>('/notifications');
      if (mounted) {
        setState(() {
          _notifications =
              (data ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(apiClientProvider).put<void>('/notifications/read-all');
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = 1;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if ((n['is_read'] as int?) == 1) return;
    try {
      await ref
          .read(apiClientProvider)
          .put<void>('/notifications/${n['id']}/read');
      setState(() => n['is_read'] = 1);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.notifications, style: AppTextStyles.h4),
        actions: [
          if (_notifications.any((n) => (n['is_read'] as int?) == 0))
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? _EmptyNotif(
                  onAction: () => showSearchDestinationDrawer(context))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = (n['is_read'] as int?) == 1;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        tileColor: isRead
                            ? null
                            : AppColors.notifBg.withValues(alpha: 0.5),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isRead
                                ? AppColors.surface
                                : AppColors.notifBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_rounded,
                              color: isRead
                                  ? AppColors.textHint
                                  : AppColors.notifAccent,
                              size: 22),
                        ),
                        title: Text(
                          n['title']?.toString() ?? '',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          n['body']?.toString() ?? '',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _markRead(n),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif({required this.onAction});
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_off_rounded,
                  size: 56, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(AppStrings.noNotifYet, style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(AppStrings.noNotifSub,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AppButton(
                  label: AppStrings.startFirstRide, onPressed: onAction),
            ],
          ),
        ),
      );
}
