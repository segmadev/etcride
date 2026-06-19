import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';

final _chatThreadsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getChatThreads();
});

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_chatThreadsProvider);

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
            onRefresh: () => ref.refresh(_chatThreadsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context) {
    final bookingId   = thread['booking_id'] as String? ?? '';
    final otherName   = thread['other_name']  as String? ?? 'Driver';
    final lastMsg     = thread['last_message'] as String? ?? '';
    final senderRole  = thread['last_sender_role'] as String? ?? '';
    final rawTime     = thread['last_message_at'] as String?;
    final time        = rawTime != null ? DateTime.tryParse(rawTime) : null;

    final preview = senderRole == 'customer' ? 'You: $lastMsg' : lastMsg;
    final timeLabel = time != null ? _formatTime(time) : '';

    return ListTile(
      onTap: () => context.push(AppRoutes.driverChat, extra: bookingId),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          otherName.isNotEmpty ? otherName[0].toUpperCase() : 'D',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(otherName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600),
      ),
      trailing: _TrailingCell(timeLabel: timeLabel, unread: (thread['unread_count'] as num?)?.toInt() ?? 0),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
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

class _TrailingCell extends StatelessWidget {
  const _TrailingCell({required this.timeLabel, required this.unread});
  final String timeLabel;
  final int unread;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(timeLabel, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
      if (unread > 0) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            unread > 99 ? '99+' : '$unread',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    ],
  );
}
