import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/chat_notification_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import 'star_rating.dart';

class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.booking,
    this.statusLabel,
    this.statusIcon,
    this.trailing,
    this.showFare = true,
    this.onChat,
    this.chatUnread = 0,
  });

  final BookingModel booking;
  final String? statusLabel;
  final Widget? statusIcon;
  final Widget? trailing;
  final bool showFare;
  final VoidCallback? onChat;
  final int chatUnread;

  void _call() {
    final phone = booking.driverPhone;
    if (phone == null || phone.isEmpty) return;
    launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Driver row ──────────────────────────────────────────────────
          Row(
            children: [
              _Avatar(url: booking.driverAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.driverName ?? 'Your Driver', style: AppTextStyles.h4),
                    CompactRating(rating: booking.driverRating),
                    if (booking.vehicleTypeName != null)
                      Text(booking.vehicleTypeName!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    if (booking.vehiclePlate != null)
                      Text(booking.vehiclePlate!,
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary, letterSpacing: 1.5)),
                  ],
                ),
              ),
              if (onChat != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ValueListenableBuilder<Map<String, int>>(
                    valueListenable: ChatNotificationService.instance.unreadCounts,
                    builder: (_, counts, __) {
                      final n = counts[booking.id] ?? chatUnread;
                      return _ChatIconButton(onTap: onChat!, unread: n);
                    },
                  ),
                ),
              if (booking.driverPhone?.isNotEmpty == true)
                GestureDetector(
                  onTap: _call,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: AppColors.successLight, shape: BoxShape.circle),
                    child: const Icon(Icons.call_rounded,
                        color: AppColors.success, size: 20),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // ── Status row ──────────────────────────────────────────────────
          Row(
            children: [
              if (statusIcon != null) ...[statusIcon!, const SizedBox(width: 6)],
              if (statusLabel != null)
                Expanded(
                  child: Text(statusLabel!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
              if (showFare)
                Text(AppFormatters.naira(booking.estimatedFare),
                    style: AppTextStyles.h4),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),

          // ── Expanded trip details (visible when sheet is swiped up) ──────
          if (booking.pickupAddress.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 4),
            _AddressRow(
              icon: Icons.radio_button_checked_rounded,
              iconColor: AppColors.primary,
              label: booking.pickupAddress,
            ),
            const SizedBox(height: 8),
            _AddressRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.error,
              label: booking.destinationAddress,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.icon, required this.iconColor, required this.label});
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(url!),
        backgroundColor: AppColors.surface,
      );
    }
    return const CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.surface,
      child: Icon(Icons.person_rounded, size: 30, color: AppColors.textSecondary),
    );
  }
}

class _ChatIconButton extends StatelessWidget {
  const _ChatIconButton({required this.onTap, required this.unread});
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.primary, size: 20),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
