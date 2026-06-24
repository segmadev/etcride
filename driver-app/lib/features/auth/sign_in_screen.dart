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
import '../../shared/widgets/app_button.dart';

enum _ContactTab { phone, email }

class DriverSignInScreen extends ConsumerStatefulWidget {
  const DriverSignInScreen({super.key});

  @override
  ConsumerState<DriverSignInScreen> createState() => _DriverSignInScreenState();
}

class _DriverSignInScreenState extends ConsumerState<DriverSignInScreen> {
  _ContactTab _tab     = _ContactTab.phone;
  int         _step    = 0;   // 0 = contact entry, 1 = password entry

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
  bool get _isContactStep => _step == 0;
  bool get _isPhone => _tab == _ContactTab.phone;
  String get _switchLabel =>
      _isPhone ? 'Use email instead' : 'Use phone number instead';
  String get _contactHint => _isPhone ? '08012345678' : 'Email';
  bool get _otpAvailable => _authMode == 'otp' || _authMode == 'both';
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

  Future<void> _onContinue() async {
    final contact = _contact;
    if (contact.isEmpty) {
      setState(() => _error = 'Please enter your ${_tab == _ContactTab.phone ? 'phone number' : 'email'}');
      return;
    }
    setState(() => _error = null);

    final mode = _authMode;

    if (mode == 'otp' || mode == 'both') {
      await _sendOtp(contact);
    } else {
      setState(() => _step = 1);
    }
  }

  Future<void> _onLogin() async {
    final contact = _contact;
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

  void _onBackPressed() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _error = null;
      });
      return;
    }

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
                      child: Text(
                        _isContactStep ? 'Start Driving' : 'Enter Password',
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
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        _isContactStep
                            ? _contactInstruction
                            : 'Enter your password to continue',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_isContactStep) ...[
                      if (_isPhone)
                        _PhoneContactField(
                          controller: _phoneCtrl,
                          onSubmit: _onContinue,
                        )
                      else
                        _OutlinedInput(
                          controller: _emailCtrl,
                          hint: _contactHint,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => _onContinue(),
                        ),
                    ] else ...[
                      _SelectedContactCard(
                        tab: _tab,
                        contact: _contact,
                        onEdit: () => setState(() {
                          _step = 0;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _PasswordField(
                        controller: _passwordCtrl,
                        hint: 'Password',
                        obscureText: !_showPassword,
                        onSubmitted: (_) => _onLogin(),
                        onToggleVisibility: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      if (_otpAvailable) ...[
                        const SizedBox(height: 28),
                        Center(
                          child: GestureDetector(
                            onTap: () => _sendOtp(_contact),
                            child: Text(
                              'Use OTP instead',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      label: _isContactStep ? 'CONTINUE' : 'SIGN IN',
                      loading: _loading,
                      onPressed: _isContactStep ? _onContinue : _onLogin,
                    ),
                    if (_biometricAvailable && !_isContactStep) ...[
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
                    if (_isContactStep) ...[
                      const SizedBox(height: 28),
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
                    ],
                    const SizedBox(height: 40),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.register),
                            child: Text(
                              'Register',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
