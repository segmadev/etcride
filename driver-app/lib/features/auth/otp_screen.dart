import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';

class DriverOtpScreen extends ConsumerStatefulWidget {
  const DriverOtpScreen({super.key, required this.contact});
  final String contact;

  @override
  ConsumerState<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends ConsumerState<DriverOtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool    _verifying = false;
  bool    _resending = false;
  String? _error;
  int     _resendCountdown = 60;
  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendCountdown <= 1) {
        _timer?.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onBoxChanged(String val, int index) {
    if (val.length > 1) {
      // Handle paste
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6 && i < digits.length; i++) {
        _ctrls[i].text = digits[i];
      }
      _nodes[5].requestFocus();
      setState(() {});
      if (digits.length >= 6) _verify();
      return;
    }
    if (val.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    if (val.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final driver = await ref.read(driverAuthRepositoryProvider).verifyOtp(
        contact: widget.contact,
        otp:     otp,
      );
      ref.read(currentDriverProvider.notifier).state = driver;
      if (!mounted) return;
      switch (driver.kycStatus) {
        case 'verified':
          context.go(AppRoutes.home);
        case 'pending':
          context.go(AppRoutes.kycPending);
        default:
          context.go(AppRoutes.kyc);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      for (final c in _ctrls) { c.clear(); }
      _nodes[0].requestFocus();
    } catch (_) {
      setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).sendOtp(contact: widget.contact);
      if (mounted) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code resent successfully.')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = !widget.contact.contains('@');

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + progress
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded, size: 24),
                  ),
                  const SizedBox(width: 16),
                  _ProgressBars(count: 3, active: 1),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                isPhone ? 'Verify your number' : 'Verify your email',
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                        text: isPhone
                            ? AppStrings.otpSentPhone
                            : AppStrings.otpSentEmail),
                    TextSpan(
                      text: ' ${widget.contact}',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // 6 boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return _OtpBox(
                    controller: _ctrls[i],
                    focusNode:  _nodes[i],
                    onChanged:  (v) => _onBoxChanged(v, i),
                  );
                }),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ],

              const SizedBox(height: 32),

              AppButton(
                label:    AppStrings.verifyOtp,
                loading:  _verifying,
                onPressed: _verify,
              ),

              const SizedBox(height: 24),

              // Resend timer
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        '${AppStrings.resendCode} ${_resendCountdown}s',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      )
                    : GestureDetector(
                        onTap: _resending ? null : _resend,
                        child: Text(
                          _resending ? 'Sending...' : AppStrings.resendNow,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single OTP digit box ──────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller:  controller,
          focusNode:   focusNode,
          maxLength:   6, // allow paste
          keyboardType: TextInputType.number,
          textAlign:    TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged:   onChanged,
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            filled:      true,
            fillColor:   AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
      );
}

// ── Progress bars ─────────────────────────────────────────────────────────────

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.count, required this.active});
  final int count;
  final int active;

  static const _mustard = Color(0xFFE2A322);

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          count,
          (i) => Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i <= active ? _mustard : _mustard.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
}
