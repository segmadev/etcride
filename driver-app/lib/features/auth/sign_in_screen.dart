import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

enum _ContactTab { phone, email }

class DriverSignInScreen extends ConsumerStatefulWidget {
  const DriverSignInScreen({super.key});

  @override
  ConsumerState<DriverSignInScreen> createState() => _DriverSignInScreenState();
}

class _DriverSignInScreenState extends ConsumerState<DriverSignInScreen> {
  _ContactTab _tab = _ContactTab.phone;

  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool    _loading            = false;
  bool    _showPassword       = false;
  String? _error;
  bool    _biometricAvailable = false;

  String get _contact => _tab == _ContactTab.phone
      ? _phoneCtrl.text.trim()
      : _emailCtrl.text.trim();

  String get _authMode => ref.read(driverAuthModeProvider);
  bool get _isPhone => _tab == _ContactTab.phone;
  String get _switchLabel =>
      _isPhone ? 'Use email instead' : 'Use phone number instead';
  String get _contactHint => _isPhone ? '08012345678' : 'Email';
  bool get _otpAvailable => _authMode == 'otp' || _authMode == 'both';
  bool get _passwordAvailable => _authMode == 'password' || _authMode == 'both';
  String get _contactInstruction => _isPhone
      ? 'Enter your phone number to continue'
      : 'Enter your email address to continue';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.instance.isAvailable;
    final enabled   = await BiometricService.instance.isEnabled;
    // Only show biometric option if there's a cached session
    final hasCachedSession = await ref.read(driverAuthRepositoryProvider).getCachedDriver() != null;
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
      final driver = await ref.read(driverAuthRepositoryProvider).getCachedDriver();
      if (driver == null) {
        if (mounted) setState(() => _error = 'No cached session. Please sign in with your password.');
        return;
      }
      ref.read(currentDriverProvider.notifier).state = driver;
      if (!mounted) return;
      _navigateAfterAuth(driver.kycStatus);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final contact = _contact;

    if (contact.isEmpty) {
      setState(() => _error = 'Please enter your ${_isPhone ? 'phone number' : 'email'}');
      return;
    }

    // OTP-only mode: treat SIGN IN as send-OTP
    if (!_passwordAvailable) {
      await _sendOtp(contact);
      return;
    }

    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final driver = await ref.read(driverAuthRepositoryProvider).login(
        login: contact,
        password: password,
      );
      ref.read(currentDriverProvider.notifier).state = driver;
      await ref.read(secureStorageProvider).setHasLoggedInBefore();
      if (!mounted) return;
      _navigateAfterAuth(driver.kycStatus);
    } on TwoFaRequiredException catch (e) {
      if (!mounted) return;
      context.push(AppRoutes.driverTwoFa, extra: {
        'token':   e.twoFaToken,
        'contact': e.twoFaContact,
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp(String contact) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(driverAuthRepositoryProvider).sendOtp(contact: contact);
      if (!mounted) return;
      context.push(AppRoutes.driverOtp, extra: contact);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateAfterAuth(String? kycStatus) {
    switch (kycStatus) {
      case 'verified':
        context.go(AppRoutes.home);
      case 'pending':
        context.go(AppRoutes.kycPending);
      default: // not_submitted or rejected
        context.go(AppRoutes.kyc);
    }
  }

  void _toggleMethod() {
    setState(() {
      _tab = _isPhone ? _ContactTab.email : _ContactTab.phone;
      _error = null;
    });
  }

  Future<void> _showForgotPassword() async {
    await showAppBottomDrawer<void>(
      context: context,
      heightFactor: 0.78,
      child: _ForgotPasswordSheet(initialEmail: _tab == _ContactTab.email ? _emailCtrl.text.trim() : ''),
    );
  }

  void _onBackPressed() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBrandRow(onBackPressed: _onBackPressed),
                    const SizedBox(height: 36),
                    const _ProgressBars(count: 3, active: 0),
                    const SizedBox(height: 76),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 308),
                      child: const Text(
                        'Start Driving',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        _contactInstruction,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_isPhone)
                      _PhoneContactField(
                        controller: _phoneCtrl,
                        onSubmit: () => FocusScope.of(context).nextFocus(),
                      )
                    else
                      _OutlinedInput(
                        controller: _emailCtrl,
                        hint: _contactHint,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                    if (_passwordAvailable) ...[
                      const SizedBox(height: 16),
                      _PasswordField(
                        controller: _passwordCtrl,
                        hint: 'Password',
                        obscureText: !_showPassword,
                        onSubmitted: (_) => _onLogin(),
                        onToggleVisibility: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 38),
                    AppButton(
                      label: 'SIGN IN',
                      loading: _loading,
                      onPressed: _onLogin,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _biometricLogin,
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: const Text('Sign in with Biometrics'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                    if (_passwordAvailable) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: GestureDetector(
                          onTap: _showForgotPassword,
                          child: Text(
                            AppStrings.forgotPassword,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _toggleMethod,
                        child: Text(
                          _switchLabel,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // DRIVER REGISTRATION DISABLED — registration is via website/admin onboarding.
                    // To re-enable: restore the Center/Wrap block below and uncomment AppRoutes.register in router.dart.
                    // Center(
                    //   child: Wrap(
                    //     crossAxisAlignment: WrapCrossAlignment.center,
                    //     children: [
                    //       Text(
                    //         "Don't have an account? ",
                    //         style: AppTextStyles.bodyMedium.copyWith(
                    //           color: AppColors.textSecondary,
                    //           fontWeight: FontWeight.w500,
                    //         ),
                    //       ),
                    //       GestureDetector(
                    //         onTap: () => context.push(AppRoutes.register),
                    //         child: Text(
                    //           'Register',
                    //           style: AppTextStyles.bodyMedium.copyWith(
                    //             color: AppColors.textPrimary,
                    //             fontWeight: FontWeight.w800,
                    //             decoration: TextDecoration.underline,
                    //             decorationColor: AppColors.textPrimary,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 12),
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

// ── Forgot / Reset password bottom sheet ─────────────────────────────────────

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet({this.initialEmail = ''});
  final String initialEmail;

  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  final _codeCtrl    = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool    _sending = false;
  bool    _saving  = false;
  bool    _sent    = false;
  bool    _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset code sent. Check your email.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    if (!_sent) return;
    final email = _emailCtrl.text.trim();
    final code  = _codeCtrl.text.trim();
    final pass  = _passCtrl.text;
    final conf  = _confirmCtrl.text;
    if (code.isEmpty) { setState(() => _error = 'Enter the reset code.'); return; }
    if (pass.trim().length < 6) { setState(() => _error = 'Password must be at least 6 characters.'); return; }
    if (pass != conf) { setState(() => _error = 'Passwords do not match.'); return; }

    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).resetPassword(
        email: email, code: code, password: pass,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can sign in now.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _saving;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.resetPassword, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Enter your registered email address and we\'ll send you a 6-digit reset code.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _emailCtrl,
              label: 'Email address',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              enabled: !_sent,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: AppStrings.sendResetCode,
              onPressed: (!busy && !_sent) ? _sendCode : (_sent ? null : null),
              enabled: !busy && !_sent,
              loading: _sending,
            ),
            if (_sent) ...[
              const SizedBox(height: 18),
              AppTextField(
                controller: _codeCtrl,
                label: AppStrings.resetCode,
                hint: '123456',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
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
                onSubmitted: (_) => _save(),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: AppStrings.saveNewPassword,
                onPressed: !busy ? _save : null,
                enabled: !busy,
                loading: _saving,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TopBrandRow extends StatelessWidget {
  const _TopBrandRow({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBackPressed,
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
        const SizedBox(width: 12),
        SizedBox(
          width: 82,
          child: SvgPicture.asset(
            AppAssets.logoDark,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _PhoneContactField extends StatelessWidget {
  const _PhoneContactField({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              AppAssets.nigeriaFlagPng,
              width: 35,
              height: 35,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 10),
          Text(
            '+234',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Phone Number',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedInput extends StatelessWidget {
  const _OutlinedInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscureText,
    required this.onSubmitted,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          suffixIcon: GestureDetector(
            onTap: onToggleVisibility,
            child: Icon(
              obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectedContactCard extends StatelessWidget {
  const _SelectedContactCard({
    required this.tab,
    required this.contact,
    required this.onEdit,
  });

  final _ContactTab tab;
  final String contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            tab == _ContactTab.phone ? Icons.phone_outlined : Icons.email_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contact,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Text(
              'Change',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
              color: i == active ? _mustard : _mustard.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
}
