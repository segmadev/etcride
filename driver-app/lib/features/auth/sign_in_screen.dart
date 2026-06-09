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
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

// ── Tab enum ──────────────────────────────────────────────────────────────────

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

  bool    _loading       = false;
  bool    _showPassword  = false;
  String? _error;

  String get _contact => _tab == _ContactTab.phone
      ? _phoneCtrl.text.trim()
      : _emailCtrl.text.trim();

  String get _authMode => ref.read(driverAuthModeProvider);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Step 0: contact entered → CONTINUE ────────────────────────────────────

  Future<void> _onContinue() async {
    final contact = _contact;
    if (contact.isEmpty) {
      setState(() => _error = 'Please enter your ${_tab == _ContactTab.phone ? 'phone number' : 'email'}');
      return;
    }
    setState(() => _error = null);

    final mode = _authMode;

    if (mode == 'otp') {
      // Send OTP immediately then go to OTP screen
      await _sendOtp(contact);
    } else {
      // password or both → go to password step
      setState(() => _step = 1);
    }
  }

  // ── Step 1: password entered → LOGIN ─────────────────────────────────────

  Future<void> _onLogin() async {
    final contact  = _contact;
    final password = _passwordCtrl.text;

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final driver = await ref.read(driverAuthRepositoryProvider).login(
        login:    contact,
        password: password,
      );
      ref.read(currentDriverProvider.notifier).state = driver;
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
    setState(() { _loading = true; _error = null; });
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

  // After sign-in, route based on kyc_status
  void _navigateAfterAuth(String kycStatus) {
    switch (kycStatus) {
      case 'verified':
        context.go(AppRoutes.home);
      case 'pending':
        context.go(AppRoutes.kycPending);
      default: // not_submitted or rejected
        context.go(AppRoutes.kyc);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(driverAuthModeProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bars
              _ProgressBars(count: 3, active: 0),
              const SizedBox(height: 32),

              // Big title
              Text(
                AppStrings.startJourney,
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _step == 0
                    ? 'Enter your ${_tab == _ContactTab.phone ? 'phone number' : 'email'} to get started.'
                    : 'Enter your password to continue.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // Phone / Email tabs (only on step 0)
              if (_step == 0) ...[
                _ContactTabs(
                  active: _tab,
                  onChanged: (t) => setState(() { _tab = t; _error = null; }),
                ),
                const SizedBox(height: 20),

                // Input field
                if (_tab == _ContactTab.phone)
                  _PhoneField(controller: _phoneCtrl, onSubmit: _onContinue)
                else
                  AppTextField(
                    controller: _emailCtrl,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _onContinue(),
                  ),
              ],

              // Password field (step 1)
              if (_step == 1) ...[
                // Show contact as read-only label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _tab == _ContactTab.phone
                            ? Icons.phone_outlined
                            : Icons.email_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_contact,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() { _step = 0; _error = null; }),
                        child: Text('Edit',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _passwordCtrl,
                  hint: AppStrings.password,
                  obscureText: !_showPassword,
                  onSubmitted: (_) => _onLogin(),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _showPassword = !_showPassword),
                    child: Icon(
                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                // "Use OTP instead" option when mode is 'both'
                if (mode == 'both') ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _sendOtp(_contact),
                    child: Center(
                      child: Text(
                        'Sign in with OTP instead',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ],

              const SizedBox(height: 32),

              // Primary button
              AppButton(
                label: _step == 0 ? AppStrings.continueBtn : 'SIGN IN',
                loading: _loading,
                onPressed: _step == 0 ? _onContinue : _onLogin,
              ),

              const SizedBox(height: 24),

              // Register link
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Don't have an account? ",
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.register),
                      child: Text('Register',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone field with Nigeria flag prefix ──────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Flag prefix
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(AppAssets.nigeriaFlag, width: 24, height: 24),
                const SizedBox(width: 6),
                Text('+234',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '08012345678',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact tab bar ───────────────────────────────────────────────────────────

class _ContactTabs extends StatelessWidget {
  const _ContactTabs({required this.active, required this.onChanged});
  final _ContactTab active;
  final ValueChanged<_ContactTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Tab(
            label: 'Phone Number',
            selected: active == _ContactTab.phone,
            onTap: () => onChanged(_ContactTab.phone),
          ),
          _Tab(
            label: 'Email',
            selected: active == _ContactTab.email,
            onTap: () => onChanged(_ContactTab.email),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String  label;
  final bool    selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: selected
                  ? [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

// ── Small progress bar row (same as onboarding) ───────────────────────────────

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
