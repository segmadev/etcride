import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/biometric_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMethod { phone, email }

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _contactCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  _LoginMethod _method = _LoginMethod.phone;
  List<String> _emailSuggestions = const [];
  bool _biometricAvailable = false;
  bool _loginSuccess = false;
  late final AnimationController _introCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  )..forward();
  late final AnimationController _driveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    _contactCtrl.clear();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.instance.isAvailable;
    final enabled   = await BiometricService.instance.isEnabled;
    // Only show biometric option if there's a cached session
    final hasCachedSession = await ref.read(authRepositoryProvider).getCachedUser() != null;
    if (mounted) setState(() => _biometricAvailable = available && enabled && hasCachedSession);
  }

  Future<void> _biometricLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await BiometricService.instance.authenticate();
      if (!ok) {
        if (mounted) setState(() => _error = 'Biometric authentication failed.');
        return;
      }
      // Use the cached user + token — same path as auto-login on app start.
      final user = await ref.read(authRepositoryProvider).getCachedUser();
      if (user == null) {
        if (mounted) setState(() => _error = 'No cached session. Please log in with your password.');
        return;
      }
      ref.read(currentUserProvider.notifier).state = user;
      if (!mounted) return;
      await _triggerDriveAnimation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmit => _contactCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty && !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = _contactCtrl.text.trim();
      final login = _method == _LoginMethod.phone ? _normalizeNgPhone(raw) : raw.replaceAll(' ', '');
      final user = await ref.read(authRepositoryProvider).login(
        login: login,
        password: _passCtrl.text,
      );
      ref.read(currentUserProvider.notifier).state = user;
      await ref.read(secureStorageProvider).setHasLoggedInBefore();
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await _triggerDriveAnimation();
    } on TwoFaRequiredException catch (e) {
      if (!mounted) return;
      context.push(AppRoutes.twoFa, extra: {
        'token':   e.twoFaToken,
        'contact': e.twoFaContact,
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerDriveAnimation() async {
    setState(() => _loginSuccess = true);
    await _driveCtrl.forward();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  void _onContactChanged(String v) {
    setState(() {
      _error = null;
      _emailSuggestions = _method == _LoginMethod.email ? _buildEmailSuggestions(v.trim()) : const [];
    });
  }

  List<String> _buildEmailSuggestions(String raw) {
    final v = raw.replaceAll(' ', '');
    final at = v.indexOf('@');
    if (at < 1) return const [];
    final local = v.substring(0, at);
    if (local.isEmpty) return const [];
    final domainPart = v.substring(at + 1).toLowerCase();
    final domains = const ['gmail.com', 'outlook.com', 'yahoo.com', 'icloud.com', 'mail.com'];
    final filtered = domains.where((d) => d.startsWith(domainPart)).take(5).toList();
    if (filtered.isEmpty) return const [];
    if (domainPart.contains('.')) return const [];
    return filtered.map((d) => '$local@$d').toList();
  }

  void _applyEmailSuggestion(String v) {
    _contactCtrl.text = v;
    _contactCtrl.selection = TextSelection.collapsed(offset: v.length);
    setState(() => _emailSuggestions = const []);
  }

  String _normalizeNgPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('234')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+234$digits';
  }

  Widget _nigeriaFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 22,
        height: 22,
        child: _EmbeddedPngFromSvgAsset(
          assetPath: AppAssets.nigeriaFlag,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _methodTabs() {
    final isPhone = _method == _LoginMethod.phone;
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.textPrimary : AppColors.inputFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          tab('Phone', isPhone, () {
            if (_method == _LoginMethod.phone) return;
            setState(() {
              _method = _LoginMethod.phone;
              _emailSuggestions = const [];
              _contactCtrl.clear();
              _error = null;
            });
          }),
          const SizedBox(width: 6),
          tab('Email', !isPhone, () {
            if (_method == _LoginMethod.email) return;
            setState(() {
              _method = _LoginMethod.email;
              _emailSuggestions = const [];
              _contactCtrl.clear();
              _error = null;
            });
          }),
        ],
      ),
    );
  }

  Future<void> _showResetPassword() async {
    await showAppBottomDrawer<void>(
      context: context,
      heightFactor: 0.78,
      child: const _ResetPasswordSheet(),
    );
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _driveCtrl.dispose();
    _contactCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final carBoxHeight = screenSize.height * 0.50;
    final carBoxWidth = screenSize.width;
    final carTopOverflow = MediaQuery.paddingOf(context).top + (carBoxHeight * 0.08);
    final contentTopPadding =
        (carBoxHeight - carTopOverflow + 24).clamp(0.0, screenSize.height).toDouble();

    // Animate car based on keyboard visibility
    final keyboardOffset = keyboardHeight > 0 ? -keyboardHeight * 0.4 : 0.0;

    return LoadingOverlay.wrap(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_introCtrl, _driveCtrl]),
                builder: (context, child) {
                  final progress = _introCtrl.value;
                  final driveOffset = (1 - progress) * (-carBoxHeight * 0.8);
                  final driveAway = _driveCtrl.value * screenSize.height * 1.5;
                  final top = -carTopOverflow + (_loginSuccess ? driveAway : driveOffset + keyboardOffset);
                  return Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: child!,
                  );
                },
                child: IgnorePointer(
                  child: SizedBox(
                    height: carBoxHeight,
                    child: Center(
                      child: SizedBox(
                        width: carBoxWidth,
                        height: carBoxHeight,
                        child: _IntroCar(
                          controller: _introCtrl,
                          height: carBoxHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _loginSuccess ? 0 : 1,
                  duration: const Duration(milliseconds: 500),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, contentTopPadding, 24, 0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.62, 0.76, curve: Curves.easeOut),
                        from: const Offset(0, 10),
                        child: Text(
                          AppStrings.loginTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.70, 0.82, curve: Curves.easeOut),
                        from: const Offset(0, 10),
                        child: Text(
                          AppStrings.startJourneySub,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 36),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.74, 0.88, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: _methodTabs(),
                      ),
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.78, 0.90, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: AppTextField(
                          controller: _contactCtrl,
                          label: _method == _LoginMethod.phone ? AppStrings.phoneNumber : AppStrings.emailAddress,
                          hint: _method == _LoginMethod.phone ? '8123456789' : 'you@example.com',
                          keyboardType: _method == _LoginMethod.phone ? TextInputType.phone : TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          inputFormatters: _method == _LoginMethod.phone
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                          prefixIcon: _method == _LoginMethod.phone
                              ? SizedBox(
                                  width: 92,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12, right: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _nigeriaFlag(),
                                        const SizedBox(width: 8),
                                        Text('+234', style: AppTextStyles.bodyMedium),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                          prefixIconConstraints: _method == _LoginMethod.phone
                              ? const BoxConstraints(minWidth: 92, minHeight: 48)
                              : null,
                          onChanged: _onContactChanged,
                        ),
                      ),
                      if (_method == _LoginMethod.email && _emailSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: const [
                              BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final s in _emailSuggestions)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _applyEmailSuggestion(s),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.textHint),
                                        const SizedBox(width: 10),
                                        Expanded(child: _EmailSuggestionText(email: s)),
                                      ],
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.80, 0.94, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: AppTextField(
                          controller: _passCtrl,
                          label: AppStrings.password,
                          hint: '••••••••',
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) => setState(() => _error = null),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => context.go(AppRoutes.phone),
                            child: Text(
                              AppStrings.createAccount,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _showResetPassword,
                            child: Text(
                              AppStrings.forgotPassword,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.84, 1.00, curve: Curves.easeOut),
                        from: const Offset(0, 14),
                        child: AppButton(
                          label: AppStrings.loginBtn,
                          onPressed: _canSubmit ? _submit : null,
                          enabled: _canSubmit,
                        ),
                      ),
                      if (_biometricAvailable) ...[
                        const SizedBox(height: 16),
                        _FadeSlide(
                          controller: _introCtrl,
                          interval: const Interval(0.88, 1.00, curve: Curves.easeOut),
                          from: const Offset(0, 10),
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _biometricLogin,
                            icon: const Icon(Icons.fingerprint_rounded, size: 22),
                            label: const Text('Sign in with Biometrics'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              ),
              // Next screen sliding up as car drives away
              AnimatedBuilder(
                animation: _driveCtrl,
                builder: (context, child) {
                  final slideProgress = _driveCtrl.value;
                  final slideOffset = (1 - slideProgress) * screenSize.height;
                  return Positioned(
                    top: slideOffset,
                    left: 0,
                    right: 0,
                    bottom: -slideOffset,
                    child: Container(
                      color: AppColors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 64,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Welcome!',
                              style: AppTextStyles.h2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You are logged in',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailSuggestionText extends StatelessWidget {
  const _EmailSuggestionText({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final at = email.indexOf('@');
    if (at < 0) {
      return Text(email, style: AppTextStyles.bodyMedium);
    }
    final local = email.substring(0, at + 1);
    final domain = email.substring(at + 1);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        children: [
          TextSpan(text: local),
          TextSpan(
            text: domain,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Forgot / Reset Password — 3-step bottom sheet ────────────────────────────

enum _ResetStep { email, code, password }

class _ResetPasswordSheet extends ConsumerStatefulWidget {
  const _ResetPasswordSheet();

  @override
  ConsumerState<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<_ResetPasswordSheet> {
  _ResetStep _step = _ResetStep.email;

  final _emailCtrl   = TextEditingController();
  final _codeCtrl    = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool    _loading  = false;
  bool    _obscure  = true;
  String? _error;

  // Resend timer — 3 minutes (email OTP rule)
  static const _resendSecs = 180;
  int     _secondsLeft = 0;
  Timer?  _timer;

  String  _sentEmail = '';

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSecs);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final visible = local.length > 2 ? local.substring(0, 2) : local[0];
    return '$visible${'*' * (local.length - visible.length)}$domain';
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      _sentEmail = email;
      _codeCtrl.clear();
      _startTimer();
      setState(() => _step = _ResetStep.code);
      if (isResend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent to your email.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    // We don't have a standalone verify-code endpoint — move straight to password step.
    // The code is validated when the password is submitted.
    setState(() { _step = _ResetStep.password; _error = null; });
  }

  Future<void> _savePassword() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;
    if (pass.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != conf) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        email: _sentEmail,
        code: code,
        password: pass,
      );
      if (!mounted) return;
      _timer?.cancel();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password updated successfully. You can now log in.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),

            // Step indicator
            _StepIndicator(current: _step),
            const SizedBox(height: 28),

            // Back arrow on steps 2 & 3
            if (_step != _ResetStep.email)
              GestureDetector(
                onTap: _loading ? null : () => setState(() {
                  _error = null;
                  _step = _step == _ResetStep.password ? _ResetStep.code : _ResetStep.email;
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Back', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (_step != _ResetStep.email) const SizedBox(height: 16),

            // ── Step content ──────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: switch (_step) {
                _ResetStep.email    => _buildEmailStep(),
                _ResetStep.code     => _buildCodeStep(),
                _ResetStep.password => _buildPasswordStep(),
              },
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot password?', style: AppTextStyles.h3),
        const SizedBox(height: 6),
        Text(
          'Enter your email address and we\'ll send you a 6-digit reset code.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _emailCtrl,
          label: AppStrings.emailAddress,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _sendCode(),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: AppStrings.sendResetCode,
          loading: _loading,
          onPressed: _loading ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Check your email', style: AppTextStyles.h3),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _maskEmail(_sentEmail),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '. Enter it below.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _codeCtrl,
          label: AppStrings.resetCode,
          hint: '123456',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _verifyCode(),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Continue',
          loading: _loading,
          onPressed: _loading ? null : _verifyCode,
        ),
        const SizedBox(height: 16),
        Center(
          child: _secondsLeft > 0
              ? Text(
                  'Resend code in $_timerLabel',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                )
              : GestureDetector(
                  onTap: _loading ? null : () => _sendCode(isResend: true),
                  child: Text(
                    'Resend code',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set new password', style: AppTextStyles.h3),
        const SizedBox(height: 6),
        Text(
          'Choose a strong password you haven\'t used before.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _passCtrl,
          label: AppStrings.newPassword,
          hint: '••••••••',
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _confirmCtrl,
          label: AppStrings.confirmNewPassword,
          hint: '••••••••',
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _savePassword(),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: AppStrings.saveNewPassword,
          loading: _loading,
          onPressed: _loading ? null : _savePassword,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final _ResetStep current;

  @override
  Widget build(BuildContext context) {
    final steps = _ResetStep.values;
    final currentIdx = steps.indexOf(current);
    return Row(
      children: List.generate(steps.length, (i) {
        final done   = i < currentIdx;
        final active = i == currentIdx;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || active ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.controller,
    required this.interval,
    required this.child,
    this.from = const Offset(0, 12),
  });

  final AnimationController controller;
  final Interval interval;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        return Opacity(
          opacity: t.value,
          child: Transform.translate(
            offset: Offset(from.dx * (1 - t.value), from.dy * (1 - t.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _IntroCar extends StatelessWidget {
  const _IntroCar({
    required this.controller,
    required this.height,
  });

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entry = CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.46, curve: Curves.easeOutCubic));
    final settle = CurvedAnimation(parent: controller, curve: const Interval(0.38, 0.62, curve: Curves.easeOutBack));

    final baseY = Tween<double>(begin: -height * 0.18, end: 0).animate(entry);
    final scale = Tween<double>(begin: 1.35, end: 1.5).animate(settle);
    final settleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 55),
    ]).animate(CurvedAnimation(parent: controller, curve: const Interval(0.44, 0.66)));

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final trailOpacity = (1 - entry.value).clamp(0.0, 1.0) * 0.18;

          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: Opacity(
                  opacity: trailOpacity,
                  child: Container(
                    width: 160,
                    height: height,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x22000000),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, baseY.value + settleY.value),
                child: Transform.scale(
                  scale: scale.value,
                  child: const SizedBox.expand(
                    child: _EmbeddedPngFromSvgAsset(
                      assetPath: AppAssets.carLogin,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final BoxFit fit;

  static final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> _load() {
    return _cache.putIfAbsent(assetPath, () async {
      final svg = await rootBundle.loadString(assetPath);
      final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
      if (match == null) throw const FormatException('No embedded PNG found.');
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
