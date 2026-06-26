import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../data/models/trip_message_model.dart';
import '../../core/services/chat_notification_service.dart';
import '../../shared/providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Chat Screen — polls GET/POST /driver/jobs/:id/messages every few seconds
//  while open. Customer-app polls the matching /bookings/:id/messages.
// ─────────────────────────────────────────────────────────────────────────────

const _kAmber = Color(0xFFE2A322);

class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, required this.job});
  final JobModel job;

  @override
  ConsumerState<DriverChatScreen> createState() =>
      _DriverChatScreenState();
}

class _DriverChatScreenState
    extends ConsumerState<DriverChatScreen> {
  static const _kPollInterval = Duration(seconds: 4);

  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _messages    = <TripMessageModel>[];
  final _chatPlayer  = AudioPlayer();
  bool  _sending     = false;
  bool  _loading     = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    ChatNotificationService.activeChatBookingId = widget.job.id;
    _load();
  }

  @override
  void dispose() {
    ChatNotificationService.activeChatBookingId = null;
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    _chatPlayer.dispose();
    super.dispose();
  }

  Future<void> _playChatSound() async {
    try {
      await _chatPlayer.play(AssetSource('sounds/chat_notify.wav'));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      ref.read(driverRepositoryProvider).markChatRead(widget.job.id).ignore();
      final msgs = await ref.read(driverRepositoryProvider).getMessages(widget.job.id);
      if (!mounted) return;
      setState(() {
        _messages.addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
      _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final since = _messages.isNotEmpty ? _messages.last.createdAt : null;
      final fetched = await ref
          .read(driverRepositoryProvider)
          .getMessages(widget.job.id, since: since);
      if (!mounted || fetched.isEmpty) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMsgs = fetched.where((m) => !existingIds.contains(m.id)).toList();
      if (newMsgs.isEmpty) return;
      setState(() => _messages.addAll(newMsgs));
      _scrollToBottom();
      if (newMsgs.any((m) => !m.isMine)) _playChatSound();
    } catch (_) {}
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);

    try {
      final msg = await ref.read(driverRepositoryProvider).sendMessage(widget.job.id, body);
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAmber))
                : _messages.isEmpty
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
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottom + 12),
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
                      maxLines: null,
                      minLines: 1,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        isCollapsed: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
  final TripMessageModel message;
  final String?          driverName;

  @override
  Widget build(BuildContext context) {
    final isDriver = message.isMine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isDriver
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isDriver) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: const Icon(Icons.person_rounded,
                  size: 14, color: _kAmber),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isDriver
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  decoration: BoxDecoration(
                    color: isDriver ? _kAmber : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isDriver ? 18 : 4),
                      bottomRight: Radius.circular(isDriver ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDriver
                          ? Colors.white
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtTime(message.createdAt),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
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
