import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_gateway_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/payment_method_selector.dart';

/// Screen for selecting a payment method during the booking flow.
/// Pushed via [AppRoutes.paymentMethods] with [extra] = current method string.
/// Pops with the selected method string via [context.pop(v)].
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key, required this.selected});

  final String selected;

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  late PaymentMethod _selected;
  List<PaymentGatewayModel> _gateways = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = PaymentMethod.fromString(widget.selected);
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    try {
      final gateways = await ref.read(bookingRepositoryProvider).getPaymentGateways();
      if (mounted) {
        setState(() {
          _gateways = gateways;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _select(PaymentMethod method) {
    setState(() => _selected = method);
    context.pop(method.apiValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: SizedBox(
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.pop(),
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
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    Text(AppStrings.addPaymentMethods, style: AppTextStyles.h2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                      child: PaymentMethodSelector(
                        selected: _selected,
                        onChanged: _select,
                        gateways: _gateways,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
