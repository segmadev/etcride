import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../data/models/job_model.dart';
import '../../shared/providers/providers.dart';

final _driverChatThreadsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getChatThreads();
});

class DriverChatHistoryScreen extends ConsumerWidget {
  const DriverChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_driverChatThreadsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Messages', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load chats', style: AppTextStyles.bodyMedium)),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No messages yet', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_driverChatThreadsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: threads.length,
              itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({super.key, required this.thread});
  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingId  = thread['booking_id'] as String? ?? '';
    final otherName  = thread['other_name']  as String? ?? 'Customer';
    final lastMsg    = thread['last_message'] as String? ?? '';
    final senderRole = thread['last_sender_role'] as String? ?? '';
    final rawTime    = thread['last_message_at'] as String?;
    final time       = rawTime != null ? DateTime.tryParse(rawTime) : null;

    final preview   = senderRole == 'driver' ? 'You: $lastMsg' : lastMsg;
    final timeLabel = time != null ? _formatTime(time) : '';

    // We need a stub JobModel to pass to the chat screen route.
    // Pull from cached jobs if available; otherwise build a minimal stub.
    final jobs    = ref.watch(driverJobsProvider).valueOrNull ?? [];
    final history = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final all     = [...jobs, ...history];
    final job     = all.firstWhere(
      (j) => j.id == bookingId,
      orElse: () => JobModel.stub(bookingId),
    );

    final unreadCount = _parseUnreadCount(thread['unread_count']);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(AppRoutes.chat, extra: job),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : 'C',
                    style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherName,
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _parseUnreadCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatTime(DateTime t) {
    final now  = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${t.day}/${t.month}';
  }
}