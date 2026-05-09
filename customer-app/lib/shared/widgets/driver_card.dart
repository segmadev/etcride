import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
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
  });

  final BookingModel booking;
  final String? statusLabel;
  final Widget? statusIcon;
  final Widget? trailing;
  final bool showFare;

  void _call() {
    final phone = booking.driverPhone;
    if (phone == null || phone.isEmpty) return;
    launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 20)],
      ),
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
        ],
      ),
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
