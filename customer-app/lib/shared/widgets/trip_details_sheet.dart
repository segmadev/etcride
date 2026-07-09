import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';

/// Shows the full trip details / receipt bottom sheet.
void showTripDetailsSheet(BuildContext context, BookingModel booking) {
  final bottom = MediaQuery.of(context).padding.bottom;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TripDetailsSheet(booking: booking, bottomPadding: bottom),
  );
}

class TripDetailsSheet extends StatelessWidget {
  const TripDetailsSheet({super.key, required this.booking, required this.bottomPadding});
  final BookingModel booking;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fare = b.finalFare != 0 ? b.finalFare : b.estimatedFare;
    final isDelivery = b.bookingType == BookingType.delivery;
    final payment = b.payment;

    String statusLabel(BookingStatus s) => switch (s) {
      BookingStatus.accepted       => 'Driver accepted',
      BookingStatus.arrived        => 'Driver arrived',
      BookingStatus.paymentPending => 'Payment confirmed',
      BookingStatus.pickedUp       => 'Package picked up',
      BookingStatus.inProgress     => 'In progress',
      BookingStatus.completed      => 'Completed',
      _                            => s.name,
    };

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Trip Details', style: AppTextStyles.h4),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fare card ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isDelivery ? 'Delivery Fare' : 'Trip Fare',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(AppFormatters.naira(fare), style: AppTextStyles.h1),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: b.paymentStatus == 'paid'
                                ? AppColors.successLight
                                : AppColors.warningLight,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            b.paymentStatus == 'paid' ? 'Paid' : 'Payment Pending',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: b.paymentStatus == 'paid'
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TripDetailSection(title: 'BOOKING INFO', rows: [
                    TripDetailRow('Booking #', b.bookingCode),
                    TripDetailRow('Type', isDelivery ? 'Delivery' : 'Ride'),
                    TripDetailRow('Status', statusLabel(b.status)),
                    if (b.createdAt != null) TripDetailRow('Created', _fmtDate(b.createdAt!)),
                  ]),

                  const SizedBox(height: 16),
                  TripDetailSection(title: 'ROUTE', rows: [
                    TripDetailRow('From', b.pickupAddress),
                    TripDetailRow('To', b.destinationAddress),
                    if (b.distanceKm > 0)
                      TripDetailRow('Distance', '${b.distanceKm.toStringAsFixed(1)} km'),
                    if (b.routeDurationSeconds > 0)
                      TripDetailRow('Est. Duration', _fmtDuration(b.routeDurationSeconds)),
                  ]),

                  if (isDelivery) ...[
                    const SizedBox(height: 16),
                    TripDetailSection(title: 'PACKAGE & CONTACTS', rows: [
                      if (b.packageDescription?.isNotEmpty == true)
                        TripDetailRow('Package', b.packageDescription!),
                      if (b.packageSize?.isNotEmpty == true)
                        TripDetailRow('Size', b.packageSize!),
                      if (b.senderPhone?.isNotEmpty == true)
                        TripDetailRow('Sender Phone', b.senderPhone!),
                      if (b.recipientName?.isNotEmpty == true)
                        TripDetailRow('Recipient', b.recipientName!),
                      if (b.recipientPhone?.isNotEmpty == true)
                        TripDetailRow('Recipient Phone', b.recipientPhone!),
                    ]),
                  ],

                  const SizedBox(height: 16),
                  TripDetailSection(title: 'DRIVER & VEHICLE', rows: [
                    if (b.driverName?.isNotEmpty == true)
                      TripDetailRow('Driver', b.driverName!),
                    if (b.driverPhone?.isNotEmpty == true)
                      TripDetailRow('Driver Phone', b.driverPhone!),
                    if (b.vehicleTypeName?.isNotEmpty == true)
                      TripDetailRow('Vehicle Type', b.vehicleTypeName!),
                    if (b.vehiclePlate?.isNotEmpty == true)
                      TripDetailRow('Plate', b.vehiclePlate!),
                    if (b.vehicleColor?.isNotEmpty == true)
                      TripDetailRow('Color', b.vehicleColor!),
                  ]),

                  const SizedBox(height: 16),
                  TripDetailSection(title: 'PAYMENT RECEIPT', rows: [
                    TripDetailRow('Method', b.paymentMethod?.displayName ?? '-'),
                    TripDetailRow('Payment Status', b.paymentStatus == 'paid' ? 'Paid' : 'Pending'),
                    if (payment != null) ...[
                      if (payment['reference']?.toString().isNotEmpty == true)
                        TripDetailRow('Reference', payment['reference'].toString()),
                      if (payment['provider']?.toString().isNotEmpty == true)
                        TripDetailRow('Provider', payment['provider'].toString()),
                      if (payment['paid_at']?.toString().isNotEmpty == true)
                        TripDetailRow('Paid At', _fmtDate(payment['paid_at'].toString())),
                    ],
                    TripDetailRow('Fare', AppFormatters.naira(fare)),
                    if (b.waitingExtraCharge > 0)
                      TripDetailRow('Waiting Fee', AppFormatters.naira(b.waitingExtraCharge)),
                    TripDetailRow('Total', AppFormatters.naira(fare + b.waitingExtraCharge)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ap';
    } catch (_) { return raw; }
  }

  static String _fmtDuration(int seconds) {
    final mins = (seconds / 60).ceil();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class TripDetailSection extends StatelessWidget {
  const TripDetailSection({super.key, required this.title, required this.rows});
  final String title;
  final List<TripDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ]),
        ),
      ],
    );
  }
}

class TripDetailRow extends StatelessWidget {
  const TripDetailRow(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
}
