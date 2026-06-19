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

  bool get _canSubmit => _otp.length == 6;
  String get _formattedResend => '00:${_resendCountdown.toString().padLeft(2, '0')}';

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
    final title = isPhone ? 'Verify Your Number' : 'Verify Your Email';
    final helper = isPhone
        ? 'Enter the 6-digit code sent to your phone number to continue'
        : 'Enter the 6-digit code sent to your email address to continue';
    final activeIndex = _ctrls.indexWhere((controller) => controller.text.isEmpty);
    final currentActiveIndex = activeIndex == -1 ? 5 : activeIndex;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Back',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const _ProgressBars(count: 3, active: 1),
                      ],
                    ),
                    const SizedBox(height: 54),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _VerificationIllustration(isPhone: isPhone),
                            const SizedBox(height: 22),
                            Text(
                              widget.contact,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              helper,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 314),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) {
                            return _OtpBox(
                              controller: _ctrls[i],
                              focusNode: _nodes[i],
                              isActive: i == currentActiveIndex,
                              onChanged: (v) => _onBoxChanged(v, i),
                            );
                          }),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    AppButton(
                      label: 'VERIFY & CONTINUE',
                      loading: _verifying,
                      enabled: _canSubmit,
                      onPressed: _verify,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _resendCountdown > 0
                          ? Text(
                              'Resend code in $_formattedResend',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resending ? null : _resend,
                              child: Text(
                                _resending ? 'Sending...' : AppStrings.resendNow,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VerificationIllustration extends StatelessWidget {
  const _VerificationIllustration({required this.isPhone});

  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 85,
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFFF9EBCF).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          isPhone ? Icons.sms_outlined : Icons.email_outlined,
          size: 36,
          color: AppColors.primary,
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
    required this.isActive,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  isActive;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;

    return SizedBox(
      width: 46,
      height: 46,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w800,
          color: hasValue ? AppColors.success : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isActive || hasValue ? AppColors.success : AppColors.divider,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.success, width: 1.5),
          ),
        ),
      ),
    );
  }
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
