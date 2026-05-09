import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/payment_method_selector.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  BookingModel? _booking;
  bool _loading = true;
  bool _paying  = false;
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (mounted) {
        setState(() {
          _booking = b;
          _method  = b.paymentMethod ?? PaymentMethod.cash;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMethod(PaymentMethod m) async {
    setState(() => _method = m);
    try {
      await ref.read(bookingRepositoryProvider)
          .updatePaymentMethod(widget.bookingId, m.apiValue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      if (_method == PaymentMethod.cash) {
        // Cash: no gateway, just navigate to completion
        if (mounted) context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
        return;
      }

      // For Flutterwave / bank transfer: initiate payment via backend
      // TODO: wire up payment gateway SDK here
      // For now, navigate to trip completed and let backend settle status via webhook
      if (mounted) context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b    = _booking;
    final fare = (b?.finalFare != null && b!.finalFare != 0)
        ? b.finalFare
        : b?.estimatedFare ?? 0;

    return LoadingOverlay.wrap(
      loading: _paying,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Payment', style: AppTextStyles.h4),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Fare summary ────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text('Trip Fare',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(AppFormatters.naira(fare), style: AppTextStyles.h1),
                            if (b?.distanceKm != null && b!.distanceKm > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${b.distanceKm.toStringAsFixed(1)} km',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Route summary ───────────────────────────────────
                      if (b != null) ...[
                        _RouteRow(
                          icon: Icons.radio_button_on,
                          color: AppColors.success,
                          address: b.pickupAddress,
                        ),
                        const SizedBox(height: 4),
                        _RouteRow(
                          icon: Icons.location_on_rounded,
                          color: AppColors.error,
                          address: b.destinationAddress,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── Payment method ──────────────────────────────────
                      PaymentMethodSelector(
                        selected: _method,
                        onChanged: _changeMethod,
                        enabled: !_paying,
                      ),

                      const SizedBox(height: 36),

                      AppButton(
                        label: _payLabel,
                        onPressed: _paying ? null : _pay,
                        enabled: !_paying,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String get _payLabel => switch (_method) {
    PaymentMethod.cash         => 'Confirm Cash Payment',
    PaymentMethod.bankTransfer => 'Pay via Bank Transfer',
    PaymentMethod.flutterwave  => 'Pay with Card',
  };
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.color, required this.address});
  final IconData icon;
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(address,
                style: AppTextStyles.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
