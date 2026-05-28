import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/trip_quick_nav.dart';

class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  BookingModel? _booking;
  final List<_ChatMsg> _msgs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _timeLabel(BuildContext context) {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m$p';
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final ts = _timeLabel(context);
    setState(() {
      _msgs.add(_ChatMsg(text: text, time: ts, mine: true));
      _ctrl.clear();
    });
    _focus.requestFocus();

    final alreadyReplied = _msgs.any((m) => !m.mine);
    if (!alreadyReplied) {
      Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _msgs.add(_ChatMsg(text: 'Hi, i am on my way', time: ts, mine: false));
        });
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final name = b?.driverName ?? 'John A. Doe';
    final rating = (b?.driverRating ?? 4.0).clamp(0.0, 5.0);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        MapOverlayButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.pop(),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) {
                                  final filled = i < rating.round().clamp(0, 5);
                                  return Icon(
                                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 42),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _msgs.isEmpty
                        ? _EmptyChat(name: name, rating: rating)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            itemCount: _msgs.length,
                            itemBuilder: (context, i) => _ChatBubble(msg: _msgs[i]),
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      16 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: _ChatInput(
                      controller: _ctrl,
                      focusNode: _focus,
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
  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: msg.mine ? AppColors.primary : const Color(0xFFE9E9E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        msg.text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: msg.mine ? AppColors.white : AppColors.textPrimary,
        ),
      ),
    );

    if (msg.mine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(msg.time, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            const SizedBox(width: 10),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Flexible(child: bubble),
          const SizedBox(width: 10),
          Text(msg.time, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.black, width: 1),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: AppColors.textPrimary,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type your message',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: Colors.transparent,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSend,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Center(
              child: Icon(Icons.send_rounded, size: 20, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  const _ChatMsg({required this.text, required this.time, required this.mine});
  final String text;
  final String time;
  final bool mine;
}
