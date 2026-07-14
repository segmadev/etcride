import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import './payment_webview_screen.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_gateway_model.dart';
import '../../shared/providers/preferences.dart';
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
  List<PaymentGatewayModel> _gateways = const [];
  bool _loading        = true;
  bool _loadingGateways = false;
  bool _paying         = false;
  bool _waitingGateway = false;   // true while we're polling after launching browser
  Timer? _pollTimer;
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(bookingRepositoryProvider);

      // Start both requests in parallel before awaiting either
      final bookingFuture  = repo.getBooking(widget.bookingId);
      final gatewaysFuture = repo.getPaymentGateways();

      final b        = await bookingFuture;
      final gateways = await gatewaysFuture;

      // If already paid/completed, skip the payment screen.
      // Delivery: payment is pre-pickup — paid means back to tracking, not trip-completed yet.
      // Ride: payment is post-trip — paid means trip-completed.
      if (mounted && (b.paymentStatus == 'paid' || b.status.isCompleted)) {
        final isDeliveryPrePickup = b.bookingType == BookingType.delivery &&
            b.status != BookingStatus.completed;
        context.go(
          isDeliveryPrePickup ? AppRoutes.driverAssigned : AppRoutes.tripCompleted,
          extra: widget.bookingId,
        );
        return;
      }

      // Load last used gateway preference
      final lastGateway = await PaymentPreferences.getLastUsedGateway();
      final method = b.paymentMethod ?? PaymentMethod.fromString(lastGateway);

      if (mounted) {
        setState(() {
          _booking  = b;
          _gateways = gateways;
          _method   = method;
          _loading  = false;
        });
        // If a payment was already launched (gateway opened) but the app was
        // backgrounded and resumed, restart polling so we catch the webhook result.
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      // Still try to load gateways even if booking fetch fails
      _loadGatewaysOnly();
    }
  }

  Future<void> _loadGatewaysOnly() async {
    if (_loadingGateways) return;
    _loadingGateways = true;
    try {
      final gateways = await ref.read(bookingRepositoryProvider).getPaymentGateways();
      if (mounted) setState(() => _gateways = gateways);
    } catch (_) {}
    _loadingGateways = false;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
        if (mounted) context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
        return;
      }

      // Save selected gateway for next time
      await PaymentPreferences.saveLastUsedGateway(_method.apiValue);

      // Call backend to generate payment link (pass selected provider)
      final result = await ref.read(bookingRepositoryProvider)
          .initiatePayment(widget.bookingId, provider: _method.apiValue);

      final link = result['payment_link'] as String?;
      if (link == null || link.isEmpty) {
        final err = result['link_error'] as String? ?? 'Payment link unavailable. Try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.error),
          );
          setState(() => _paying = false);
        }
        return;
      }

      // Open payment gateway in an in-app WebView so the user never leaves the app.
      if (!mounted) return;
      await Navigator.of(context).push<PaymentWebViewResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaymentWebViewScreen(
            url: link,
            bookingId: widget.bookingId,
          ),
        ),
      );

      // WebView closed (payment completed, cancelled, or user manually dismissed).
      // Show the "Waiting for confirmation" banner and start polling — the backend
      // webhook updates payment status regardless of how the WebView was closed.
      if (mounted) setState(() { _paying = false; _waitingGateway = true; });
      _startPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() { _paying = false; _waitingGateway = false; });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkPaymentStatus());
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final status = await ref.read(bookingRepositoryProvider)
          .getPaymentStatus(widget.bookingId);
      final payStatus = status['payment_status'] as String? ?? '';
      if (payStatus == 'paid') {
        _pollTimer?.cancel();
        if (mounted) {
          final b = _booking;
          // Delivery pre-pickup payment: trip not done yet — go back to tracking
          if (b != null && b.bookingType == BookingType.delivery &&
              b.status != BookingStatus.completed) {
            context.go(AppRoutes.driverAssigned, extra: widget.bookingId);
          } else {
            context.go(AppRoutes.tripCompleted, extra: widget.bookingId);
          }
        }
      } else if (payStatus == 'failed') {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() { _paying = false; _waitingGateway = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment failed. Please try again.'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (_) {}
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
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              _pollTimer?.cancel();
              if (context.canPop()) context.pop();
              else context.go(AppRoutes.home);
            },
          ),
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
                          color: AppColors.success,
                          address: b.pickupAddress,
                        ),
                        const SizedBox(height: 4),
                        _RouteRow(
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
                        gateways: _gateways,
                      ),

                      const SizedBox(height: 36),

                      if (_waitingGateway) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Waiting for payment confirmation…\nComplete the payment in your browser.',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            _pollTimer?.cancel();
                            setState(() { _paying = false; _waitingGateway = false; });
                          },
                          child: Text('Cancel', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                        ),
                      ] else
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
    PaymentMethod.flutterwave  => 'Pay with Flutterwave',
    PaymentMethod.korapay      => 'Pay with Korapay',
    PaymentMethod.bankTransfer => 'Pay via Bank Transfer',
    _                          => 'Pay Now',
  };
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.color, required this.address});
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SvgPicture.asset(
            AppAssets.mapPin,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
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
