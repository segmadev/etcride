import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/app_config.dart';
import '../../core/config/router.dart';
import '../../core/utils/formatters.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/otp_input.dart';
import '../../shared/widgets/loading_overlay.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.contact,
    required this.contactType,   // 'email' | 'phone'
    this.isRegistration = false,
  });
  final String contact;
  final String contactType;
  final bool   isRegistration;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  int _countdown = AppConfig.otpResendSecs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = AppConfig.otpResendSecs);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) { t.cancel(); return; }
      setState(() => _countdown--);
    });
  }

  Future<void> _verify(String otp) async {
    if (otp.length < AppConfig.otpLength) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref.read(authRepositoryProvider).verifyOtp(
        contact: widget.contact,
        otp: otp,
      );
      ref.read(currentUserProvider.notifier).state = user;
      await ref.read(secureStorageProvider).setHasLoggedInBefore();
      if (!mounted) return;
      // Route to set-password if the user has never set one (works for both
      // new registrations and legacy accounts that pre-date the password step).
      if (!user.hasPassword) {
        context.go(AppRoutes.setPassword);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
      _controller.clear();
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.contact);
      _startTimer();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _controller.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay.wrap(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const AppBackButton(),
                const SizedBox(height: 32),

                // ── Icon ─────────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      widget.contactType == 'phone'
                          ? Icons.phone_android_rounded
                          : Icons.email_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                Center(
                  child: Text(widget.contact,
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    widget.contactType == 'phone'
                        ? AppStrings.otpSentPhone
                        : AppStrings.otpSentEmail,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 36),

                // ── OTP boxes ────────────────────────────────────────────────
                OtpInput(
                  controller: _controller,
                  onCompleted: _verify,
                  onChanged: (_) => setState(() => _error = null),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(_error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Resend ───────────────────────────────────────────────────
                Center(
                  child: _countdown > 0
                      ? Text(
                          '${AppStrings.resendCode} ${AppFormatters.countdown(_countdown)}',
                          style:
                              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        )
                      : TextButton(
                          onPressed: _resend,
                          child: Text(AppStrings.resendNow,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                        ),
                ),

                const Spacer(),

                AppButton(
                  label: AppStrings.verifyOtp,
                  onPressed: () => _verify(_controller.text),
                  enabled: _controller.text.length == AppConfig.otpLength && !_loading,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
