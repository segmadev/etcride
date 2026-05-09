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
import '../../../shared/widgets/star_rating.dart';
import '../../../shared/widgets/loading_overlay.dart';

class TripCompletedScreen extends ConsumerStatefulWidget {
  const TripCompletedScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripCompletedScreen> createState() =>
      _TripCompletedScreenState();
}

class _TripCompletedScreenState extends ConsumerState<TripCompletedScreen> {
  BookingModel? _booking;
  bool _loading   = true;
  bool _submitting = false;
  int  _rating    = 0;
  bool _rated     = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;

      // If still payment_pending, send to payment screen
      if (b.status == BookingStatus.paymentPending) {
        context.go(AppRoutes.payment, extra: widget.bookingId);
        return;
      }

      setState(() { _booking = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(bookingRepositoryProvider)
          .rateDriver(widget.bookingId, rating: _rating);
      if (mounted) setState(() { _rated = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final fare = (b?.finalFare != null && b!.finalFare != 0)
        ? b.finalFare
        : b?.estimatedFare ?? 0;

    return LoadingOverlay.wrap(
      loading: _submitting,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // ── Success icon ──────────────────────────────────────
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: AppColors.successLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 52, color: AppColors.success),
                      ),
                      const SizedBox(height: 24),

                      Text(AppStrings.tripCompleted,
                          style: AppTextStyles.h2, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(AppStrings.thanksForRiding,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center),

                      const SizedBox(height: 32),

                      // ── Fare summary card ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text('Total Fare',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(AppFormatters.naira(fare),
                                style: AppTextStyles.h2
                                    .copyWith(color: AppColors.black)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: b?.paymentStatus == 'paid'
                                    ? AppColors.successLight
                                    : AppColors.warningLight,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                b?.paymentStatus == 'paid' ? 'Paid' : 'Cash / Pending',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: b?.paymentStatus == 'paid'
                                        ? AppColors.success
                                        : AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Driver rating ─────────────────────────────────────
                      if (b?.driverName != null && !_rated) ...[
                        Text(
                          'How was your trip with ${b!.driverName}?',
                          style: AppTextStyles.h4,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        StarRating(
                          rating: _rating.toDouble(),
                          size: 40,
                          onRate: (r) => setState(() => _rating = r),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Submit Rating',
                          onPressed: _submitting ? null : _submitRating,
                          enabled: !_submitting && _rating > 0,
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_rated) ...[
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 32),
                        const SizedBox(height: 8),
                        Text('Thanks for rating!',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                      ],

                      // ── Action buttons ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push(
                                  AppRoutes.tripReceipt,
                                  extra: widget.bookingId),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: AppColors.divider),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(AppStrings.viewReceipt,
                                  style: AppTextStyles.labelMedium),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'DONE',
                              onPressed: () => context.go(AppRoutes.home),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
