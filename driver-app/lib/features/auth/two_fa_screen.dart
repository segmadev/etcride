import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';

class DriverTwoFaScreen extends ConsumerStatefulWidget {
  const DriverTwoFaScreen({
    super.key,
    required this.twoFaToken,
    required this.twoFaContact,
  });
  final String twoFaToken;
  final String twoFaContact;

  @override
  ConsumerState<DriverTwoFaScreen> createState() => _DriverTwoFaScreenState();
}

class _DriverTwoFaScreenState extends ConsumerState<DriverTwoFaScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());
  bool    _loading   = false;
  String? _error;
  int     _countdown = 180;
  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) { t.cancel(); return; }
      setState(() => _countdown--);
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final driver = await ref.read(driverAuthRepositoryProvider).verify2fa(
        twoFaToken: widget.twoFaToken,
        otp: otp,
      );
      ref.read(currentDriverProvider.notifier).state = driver;
      await ref.read(secureStorageProvider).setHasLoggedInBefore();
      if (!mounted) return;
      _navigateAfterAuth(driver.kycStatus);
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    }
  }

  void _navigateAfterAuth(String? kycStatus) {
    switch (kycStatus) {
      case 'verified':
        context.go(AppRoutes.home);
      case 'pending':
        context.go(AppRoutes.kycPending);
      default:
        context.go(AppRoutes.kyc);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.signIn),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Back', style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.security_rounded, size: 36, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'Two-Factor Verification',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'A verification code was sent to\n${widget.twoFaContact}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 36),

              // 6-box OTP input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                    setState(() => _error = null);
                    if (_otp.length == 6) _verify();
                  },
                  onBackspace: () {
                    if (_controllers[i].text.isEmpty && i > 0) {
                      _controllers[i - 1].clear();
                      _focusNodes[i - 1].requestFocus();
                    }
                  },
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ),
              ],

              const SizedBox(height: 24),
              Center(
                child: _countdown > 0
                    ? Text(
                        'Code expires in ${AppFormatters.countdown(_countdown)}',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      )
                    : Text(
                        'Code expired. Please go back and sign in again.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
              ),

              const Spacer(),
              AppButton(
                label: 'Verify',
                loading: _loading,
                onPressed: _otp.length == 6 && !_loading ? _verify : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 52,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
