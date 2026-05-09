import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import 'location_route_row.dart';

/// Returns the display label for a booking status.
String statusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pending        => 'Searching',
  BookingStatus.assigned       => 'Driver Assigned',
  BookingStatus.accepted       => 'Driver Accepted',
  BookingStatus.arrived        => 'Driver Arrived',
  BookingStatus.inProgress     => 'In Progress',
  BookingStatus.paymentPending => 'Payment Due',
  BookingStatus.paid           => 'Paid',
  BookingStatus.completed      => 'Completed',
  BookingStatus.cancelled      => 'Cancelled',
  BookingStatus.rejected       => 'Rejected',
};

/// Returns the route path to navigate to for resuming an active booking.
String activeBookingRoute(BookingStatus s) => switch (s) {
  BookingStatus.pending                         => '/requesting',
  BookingStatus.assigned ||
  BookingStatus.accepted ||
  BookingStatus.arrived                         => '/driver-assigned',
  BookingStatus.inProgress                      => '/trip-in-progress',
  BookingStatus.paymentPending                  => '/payment',
  _                                             => '/home',
};

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onAction,
  });

  final BookingModel booking;
  final VoidCallback? onTap;

  /// Primary CTA — depends on status. Null hides the button.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isActive  = booking.status.isActive;
    final fare      = booking.finalFare > 0 ? booking.finalFare : booking.estimatedFare;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vehicle icon ────────────────────────────────────────────────
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                booking.bookingType == BookingType.delivery
                    ? Icons.delivery_dining_rounded
                    : Icons.directions_car_rounded,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // ── Route + meta ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocationRouteRow(
                    pickup: booking.pickupAddress,
                    destination: booking.destinationAddress,
                    compact: true,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusChip(status: booking.status),
                      const Spacer(),
                      if (booking.createdAt != null)
                        Text(
                          AppFormatters.tripDate(DateTime.parse(booking.createdAt!)),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        AppFormatters.naira(fare),
                        style: AppTextStyles.labelMedium,
                      ),
                      if (booking.distanceKm > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${booking.distanceKm.toStringAsFixed(1)} km',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint),
                        ),
                      ],
                      const Spacer(),
                      if (onAction != null)
                        _ActionButton(
                          status: booking.status,
                          onTap: onAction!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      BookingStatus.completed ||
      BookingStatus.paid           => (AppColors.success.withValues(alpha: 0.12), AppColors.success),
      BookingStatus.cancelled ||
      BookingStatus.rejected       => (AppColors.error.withValues(alpha: 0.1), AppColors.error),
      BookingStatus.paymentPending => (AppColors.warning.withValues(alpha: 0.12), AppColors.warning),
      BookingStatus.inProgress ||
      BookingStatus.arrived        => (AppColors.primary.withValues(alpha: 0.12), AppColors.primary),
      _                            => (AppColors.surface, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.status, required this.onTap});
  final BookingStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon, Color bg, Color fg) = switch (status) {
      BookingStatus.pending ||
      BookingStatus.assigned ||
      BookingStatus.accepted ||
      BookingStatus.arrived        => ('Track', Icons.location_on_rounded, AppColors.primary, AppColors.white),
      BookingStatus.inProgress     => ('Resume', Icons.play_arrow_rounded, AppColors.primary, AppColors.white),
      BookingStatus.paymentPending => ('Pay Now', Icons.payments_rounded, AppColors.warning, AppColors.white),
      BookingStatus.cancelled ||
      BookingStatus.rejected       => ('Rebook', Icons.replay_rounded, AppColors.inputFill, AppColors.textPrimary),
      _                            => ('Rebook', Icons.replay_rounded, AppColors.black, AppColors.white),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
