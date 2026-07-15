import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/app_config.dart'; // otpLength
import '../../core/config/router.dart';
import '../../core/utils/formatters.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/otp_input.dart';
import '../../shared/widgets/loading_overlay.dart';

class TwoFaScreen extends ConsumerStatefulWidget {
  const TwoFaScreen({
    super.key,
    required this.twoFaToken,
    required this.twoFaContact,
  });
  final String twoFaToken;
  final String twoFaContact;

  @override
  ConsumerState<TwoFaScreen> createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends ConsumerState<TwoFaScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  int _countdown = 180; // 3 min for email 2FA
  Timer? _timer;

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

  Future<void> _verify(String otp) async {
    if (otp.length < AppConfig.otpLength) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref.read(authRepositoryProvider).verify2fa(
        twoFaToken: widget.twoFaToken,
        otp: otp,
      );
      ref.read(currentUserProvider.notifier).state = user;
      await ref.read(secureStorageProvider).setHasLoggedInBefore();
      if (!mounted) return;
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

                Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
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

                Center(
                  child: _countdown > 0
                      ? Text(
                          'Code expires in ${AppFormatters.countdown(_countdown)}',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        )
                      : Text(
                          'Code expired. Please go back and try again.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                        ),
                ),

                const Spacer(),

                AppButton(
                  label: 'Verify',
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
