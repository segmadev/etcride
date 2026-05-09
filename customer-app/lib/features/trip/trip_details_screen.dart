import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/location_route_row.dart';
import '../booking/search_destination_screen.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  BookingModel? _booking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b =
          await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (mounted) setState(() { _booking = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(BookingStatus s) => switch (s) {
        BookingStatus.completed || BookingStatus.paid => AppColors.success,
        BookingStatus.cancelled                       => AppColors.error,
        _                                             => AppColors.primary,
      };

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending      => 'Pending',
        BookingStatus.assigned     => 'Driver Assigned',
        BookingStatus.accepted     => 'Accepted',
        BookingStatus.inProgress   => 'In Progress',
        BookingStatus.completed    => 'Completed',
        BookingStatus.cancelled    => 'Cancelled',
        BookingStatus.paid         => 'Paid',
        _                          => 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    final b = _booking;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('Trip Details', style: AppTextStyles.h4),
        actions: [
          if (b != null)
            TextButton(
              onPressed: () =>
                  context.push(AppRoutes.tripReceipt, extra: widget.bookingId),
              child: Text(AppStrings.viewReceipt,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : b == null
              ? const Center(child: Text('Trip not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Status + date ─────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(b.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(_statusLabel(b.status),
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: _statusColor(b.status))),
                          ),
                          const Spacer(),
                          Text(AppFormatters.fullDate(b.createdAt),
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Route card ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: LocationRouteRow(
                          pickup: b.pickupAddress,
                          destination: b.destinationAddress,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Info rows ─────────────────────────────────────────
                      _InfoRow('Booking Code',    b.bookingCode),
                      _InfoRow('Vehicle',         b.vehicleTypeName ?? '—'),
                      _InfoRow('Distance',        AppFormatters.distance(b.distanceKm)),
                      _InfoRow('Estimated Fare',  AppFormatters.naira(b.estimatedFare)),
                      if (b.finalFare != 0)
                        _InfoRow('Final Fare',    AppFormatters.naira(b.finalFare)),
                      _InfoRow('Payment',         b.paymentStatus.toUpperCase()),

                      // ── Driver ────────────────────────────────────────────
                      if (b.driverName != null &&
                          b.driverName!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Driver',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surface,
                                child: Icon(Icons.person_rounded,
                                    size: 24,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.driverName!,
                                      style: AppTextStyles.bodyLarge),
                                  if (b.vehiclePlate != null)
                                    Text(b.vehiclePlate!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            letterSpacing: 1.2)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      if (b.status == BookingStatus.completed ||
                          b.status == BookingStatus.paid)
                        AppButton(
                          label: AppStrings.rebook,
                          onPressed: () => showSearchDestinationDrawer(context),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: AppTextStyles.bodyMedium),
          ],
        ),
      );
}
