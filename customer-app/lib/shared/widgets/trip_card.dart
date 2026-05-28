import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import 'location_route_row.dart';

/// Trip history card matching the Figma design.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onRebook,
  });

  final BookingModel booking;
  final VoidCallback? onTap;
  final VoidCallback? onRebook;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle thumbnail
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: SizedBox(
                width: 38,
                height: 38,
                child: _EmbeddedPngFromSvgAsset(
                  assetPath: booking.bookingType == BookingType.delivery
                      ? AppAssets.courierIcon
                      : AppAssets.carIcon,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Route + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationRouteRow(
                  pickup: booking.pickupAddress,
                  destination: booking.destinationAddress,
                  compact: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      booking.createdAt != null
                          ? AppFormatters.tripDate(DateTime.parse(booking.createdAt!))
                          : '',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(width: 6),
                    Text('•', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 6),
                    Text(
                      AppFormatters.nairaCompact(booking.finalFare > 0 ? booking.finalFare : booking.estimatedFare),
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Text('~', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 4),
                    _StatusChip(status: booking.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Fare + rebook
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.nairaCompact(booking.finalFare > 0 ? booking.finalFare : booking.estimatedFare),
                style: AppTextStyles.priceMedium,
              ),
              const SizedBox(height: 8),
              _RebookButton(onTap: onRebook),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({required this.assetPath});

  final String assetPath;

  static final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> _load() {
    return _cache.putIfAbsent(assetPath, () async {
      final svg = await rootBundle.loadString(assetPath);
      final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
      if (match == null) throw const FormatException('No embedded PNG found.');
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Image.memory(
          snap.data!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case BookingStatus.completed:
      case BookingStatus.paid:
        color = AppColors.success; label = 'Successful';
      case BookingStatus.cancelled:
        color = AppColors.error; label = 'Cancelled';
      default:
        color = AppColors.warning; label = status.name;
    }
    return Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: color));
  }
}

class _RebookButton extends StatelessWidget {
  const _RebookButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_rounded, color: AppColors.white, size: 14),
          const SizedBox(width: 4),
          const Text(
            'Rebook',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
