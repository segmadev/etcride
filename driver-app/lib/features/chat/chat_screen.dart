import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../shared/providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Chat Screen
//
//  UI is fully designed and functional (local state).
//  TODO (backend): Implement a chat/messages table + WebSocket or polling
//       endpoint so driver and customer can exchange messages in-app.
//       Suggested table: `trip_messages (id, booking_id, sender_role,
//       sender_id, body, sent_at)`.
//       Add REST endpoints:
//         GET  /driver/jobs/:id/messages   → list messages
//         POST /driver/jobs/:id/messages   → send message
//       Then wire `_loadMessages()` and `_sendMessage()` in this screen.
// ─────────────────────────────────────────────────────────────────────────────

const _kAmber = Color(0xFFE2A322);

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.body,
    required this.fromDriver,
    required this.sentAt,
  });
  final String   id;
  final String   body;
  final bool     fromDriver;
  final DateTime sentAt;
}

class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, required this.job});
  final JobModel job;

  @override
  ConsumerState<DriverChatScreen> createState() =>
      _DriverChatScreenState();
}

class _DriverChatScreenState
    extends ConsumerState<DriverChatScreen> {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _messages    = <_ChatMessage>[];
  bool  _sending     = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── TODO: replace with real API call ──────────────────────────────────────
  Future<void> _sendMessage() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    _controller.clear();

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(
        id:         DateTime.now().millisecondsSinceEpoch.toString(),
        body:       body,
        fromDriver: true,
        sentAt:     DateTime.now(),
      ));
    });

    await Future.delayed(const Duration(milliseconds: 300));

    // TODO: await apiClient.post('/driver/jobs/${widget.job.id}/messages',
    //         body: {'message': body});

    if (mounted) setState(() => _sending = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);
    final job    = widget.job;
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: _kAmber,
            padding: EdgeInsets.fromLTRB(8, top + 8, 16, 14),
            child: Row(
              children: [
                // Back
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                ),
                // Passenger avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text(
                    (job.passengerName?.isNotEmpty == true
                        ? job.passengerName![0]
                        : 'P').toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kAmber,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.passengerName ?? 'Passenger',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        job.bookingRef.isNotEmpty
                            ? '#${job.bookingRef}'
                            : '#${job.id.substring(0, 8).toUpperCase()}',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                // Coming soon badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Beta',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
          ),

          // ── Trip info strip ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              border: Border(
                  bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 14, color: _kAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${job.pickupAddress} → ${job.destinationAddress}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Messages ──────────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _EmptyMessages(passengerName: job.passengerName)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      return _MessageBubble(
                        message:    msg,
                        driverName: driver?.name,
                      );
                    },
                  ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                  top: BorderSide(color: AppColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.disabled : _kAmber,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.passengerName});
  final String? passengerName;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 34, color: _kAmber),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a message to${passengerName != null ? ' ${passengerName!.split(' ').first}' : ' the passenger'}. '
                'They will receive it in the customer app.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(height: 1.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.driverName,
  });
  final _ChatMessage message;
  final String?      driverName;

  @override
  Widget build(BuildContext context) {
    final isDriver = message.fromDriver;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isDriver
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isDriver) ...[
            // Passenger avatar
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: const Icon(Icons.person_rounded,
                  size: 14, color: _kAmber),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              decoration: BoxDecoration(
                color: isDriver ? _kAmber : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isDriver ? 16 : 4),
                  bottomRight: Radius.circular(isDriver ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDriver
                          ? Colors.white
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtTime(message.sentAt),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: isDriver
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isDriver) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                driverName?.isNotEmpty == true
                    ? driverName![0].toUpperCase()
                    : 'D',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAmber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
