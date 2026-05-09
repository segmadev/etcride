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

class TripReceiptScreen extends ConsumerStatefulWidget {
  const TripReceiptScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripReceiptScreen> createState() => _TripReceiptScreenState();
}

class _TripReceiptScreenState extends ConsumerState<TripReceiptScreen> {
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

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final fare =
        (b?.finalFare != null && b!.finalFare != 0) ? b.finalFare : b?.estimatedFare ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.fareBreakdown, style: AppTextStyles.h4),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : b == null
              ? const Center(child: Text('Receipt not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ── Receipt card ──────────────────────────────────────
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x10000000), blurRadius: 12)
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: AppColors.black,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.receipt_long_rounded,
                                      color: AppColors.primary, size: 36),
                                  const SizedBox(height: 8),
                                  Text(AppFormatters.naira(fare),
                                      style: AppTextStyles.h2
                                          .copyWith(color: AppColors.white)),
                                  const SizedBox(height: 4),
                                  Text(AppStrings.thanksForRiding,
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textHint)),
                                ],
                              ),
                            ),

                            // Body
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _ReceiptRow('Booking #', b.bookingCode),
                                  _ReceiptRow('Date',
                                      AppFormatters.fullDate(b.createdAt)),
                                  _ReceiptRow('From', b.pickupAddress),
                                  _ReceiptRow('To', b.destinationAddress),
                                  _ReceiptRow('Distance',
                                      AppFormatters.distance(b.distanceKm)),
                                  _ReceiptRow(
                                      'Vehicle', b.vehicleTypeName ?? '—'),
                                  const Divider(height: 32),
                                  _ReceiptRow('Estimated Fare',
                                      AppFormatters.naira(b.estimatedFare)),
                                  _ReceiptRow('Payment',
                                      b.paymentStatus.toUpperCase()),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Text('Total', style: AppTextStyles.h4),
                                      const Spacer(),
                                      Text(AppFormatters.naira(fare),
                                          style: AppTextStyles.h4.copyWith(
                                              color: AppColors.primary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      AppButton(
                        label: 'BACK TO HOME',
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  style: AppTextStyles.bodySmall, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}
