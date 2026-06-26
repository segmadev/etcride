import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/trip_message_model.dart';
import '../../core/services/chat_notification_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/trip_quick_nav.dart';

class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  static const _kPollInterval = Duration(seconds: 4);

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();

  BookingModel? _booking;
  final List<TripMessageModel> _msgs = [];
  final _chatPlayer = AudioPlayer();
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    ChatNotificationService.activeChatBookingId = widget.bookingId;
    _load();
  }

  @override
  void dispose() {
    ChatNotificationService.activeChatBookingId = null;
    _pollTimer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    _chatPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      ref.read(bookingRepositoryProvider).markChatRead(widget.bookingId).ignore();
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      final msgs = await ref.read(bookingRepositoryProvider).getMessages(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _msgs.addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
      _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final since = _msgs.isNotEmpty ? _msgs.last.createdAt : null;
      final fetched = await ref
          .read(bookingRepositoryProvider)
          .getMessages(widget.bookingId, since: since);
      if (!mounted || fetched.isEmpty) return;
      final existingIds = _msgs.map((m) => m.id).toSet();
      final newMsgs = fetched.where((m) => !existingIds.contains(m.id)).toList();
      if (newMsgs.isEmpty) return;
      setState(() => _msgs.addAll(newMsgs));
      _scrollToBottom();
      if (newMsgs.any((m) => !m.isMine)) {
        try { await _chatPlayer.play(AssetSource('sounds/chat_notify.wav')); } catch (_) {}
      }
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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try {
      final msg = await ref.read(bookingRepositoryProvider).sendMessage(widget.bookingId, text);
      if (!mounted) return;
      setState(() => _msgs.add(msg));
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
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final name = b?.driverName ?? 'Driver';
    final rating = (b?.driverRating ?? 0.0).clamp(0.0, 5.0);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leadingWidth: 50,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Center(
            child: MapOverlayButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.pop(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: AppTextStyles.h4),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < rating.round().clamp(0, 5);
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 12,
                  color: AppColors.primary,
                );
              }),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  Expanded(
                    child: _msgs.isEmpty
                        ? _EmptyChat(name: name, rating: rating)
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            itemCount: _msgs.length,
                            itemBuilder: (context, i) => _ChatBubble(msg: _msgs[i]),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.divider, width: 1),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: _ChatInput(
                      controller: _ctrl,
                      focusNode: _focus,
                      sending: _sending,
                      onSend: _send,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.name, required this.rating});
  final String name;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.person_rounded, size: 38, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < rating.round().clamp(0, 5);
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: AppColors.primary,
                );
              }),
            ),
            const SizedBox(height: 14),
            Text(
              'Messages are only available during this trip',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.msg});
  final TripMessageModel msg;

  String get _timeLabel {
    final t = msg.createdAt.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final mine = msg.isMine;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 4),
          bottomRight: Radius.circular(mine ? 4 : 20),
        ),
      ),
      child: Text(
        msg.body,
        style: AppTextStyles.bodyMedium.copyWith(
          color: mine ? AppColors.white : AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );

    if (mine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_timeLabel, style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11)),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: bubble),
          const SizedBox(width: 8),
          Text(_timeLabel, style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: AppColors.primary,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: sending ? null : onSend,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: sending ? AppColors.disabled : AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: sending
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.send_rounded, size: 20, color: AppColors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
