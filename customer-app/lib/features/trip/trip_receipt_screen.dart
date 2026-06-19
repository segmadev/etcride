import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';

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
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (mounted) setState(() { _booking = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _booking == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        const Text('Receipt not found'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.home),
                          child: const Text('Go home'),
                        ),
                      ],
                    ),
                  )
                : _buildBody(_booking!),
      ),
    );
  }

  Widget _buildBody(BookingModel b) {
    final fare = b.finalFare != 0 ? b.finalFare : b.estimatedFare;
    final createdDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
    final dateStr = createdDate != null ? DateFormat("MMM d").format(createdDate) : '—';
    final timeStr = createdDate != null ? DateFormat("h:mma").format(createdDate) : '';

    // Payment method display: use enum label, or fall back to paymentStatus
    final paymentMethodLabel = b.paymentMethod?.displayName ??
        (b.paymentStatus.isNotEmpty ? _formatPaymentStatus(b.paymentStatus) : '—');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _CircleBackButton(onTap: () {
                  if (context.canPop()) { context.pop(); }
                  else { context.go(AppRoutes.home); }
                }),
              ),
              Text('Fare Breakdown', style: AppTextStyles.h4),
            ],
          ),
        ),

        // ── Scrollable body ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Illustration
                Center(
                  child: SvgPicture.asset(
                    AppAssets.receiptIllustration,
                    width: 160,
                    height: 130,
                  ),
                ),
                const SizedBox(height: 12),

                // Date + time
                Text(
                  '$dateStr ~ $timeStr',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),

                // Heading
                Text('Thanks for riding with ETC', style: AppTextStyles.h2),
                const SizedBox(height: 20),

                const Divider(height: 1, thickness: 1, color: AppColors.divider),
                const SizedBox(height: 16),

                // Total row
                Row(
                  children: [
                    Text('Total', style: AppTextStyles.h3),
                    const Spacer(),
                    Text(AppFormatters.naira(fare), style: AppTextStyles.h3),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: AppColors.divider),
                const SizedBox(height: 14),

                // Disclaimer
                Text(
                  'Your fare will be the price presented before the trip or based on the rates below and other applicable subcharges and adjustments.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint, height: 1.6),
                ),
                const SizedBox(height: 20),

                // ── Itemised breakdown ───────────────────────────────────────
                _ReceiptLineItem('Booking #', b.bookingCode),
                const _DashedDivider(),

                _ReceiptLineItem('From', b.pickupAddress),
                const _DashedDivider(),

                _ReceiptLineItem('To', b.destinationAddress),
                const _DashedDivider(),

                if (b.distanceKm > 0) ...[
                  _ReceiptLineItem('Distance', AppFormatters.distance(b.distanceKm)),
                  const _DashedDivider(),
                ],

                if (b.durationMinutes > 0) ...[
                  _ReceiptLineItem('Duration', AppFormatters.duration(b.durationMinutes)),
                  const _DashedDivider(),
                ],

                _ReceiptLineItem('Trip Fare', AppFormatters.naira(fare)),
                const _DashedDivider(),

                if (b.waitingExtraCharge > 0) ...[
                  _ReceiptLineItem('Wait Fare', AppFormatters.naira(b.waitingExtraCharge)),
                  const _DashedDivider(),
                ],

                _ReceiptLineItem('Payment Method', paymentMethodLabel),
                const _DashedDivider(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatPaymentStatus(String s) {
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _ReceiptLineItem extends StatelessWidget {
  const _ReceiptLineItem(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashedPainter(),
      );
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashW = 6.0, gapW = 4.0;
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashW, 0), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
