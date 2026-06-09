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

class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState
    extends ConsumerState<DriverRegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool    _loading      = false;
  bool    _showPass     = false;
  bool    _showConfirm  = false;
  bool    _agreedTerms  = false;
  String? _error;
  String? _selectedState;
  String? _selectedLga;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  List<String> _lgasFor(String state, List<dynamic> locations) {
    for (final item in locations) {
      if (item is Map && item['state']?.toString() == state) {
        final lgas = item['lgas'];
        if (lgas is List) return lgas.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  Future<void> _register(List<dynamic> locations) async {
    final name    = _nameCtrl.text.trim();
    final phone   = _phoneCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Name, phone, and password are required.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (!_agreedTerms) {
      setState(() => _error = 'Please agree to the Terms & Conditions.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).register(
        name:     name,
        phone:    phone,
        email:    email.isNotEmpty ? email : null,
        password: pass,
        state:    _selectedState,
        lga:      _selectedLga,
      );

      if (!mounted) return;
      // After registration, go to sign in with a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please sign in to continue.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go(AppRoutes.signIn);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(driverLocationsProvider);
    final locations = locationsAsync.valueOrNull ?? [];
    final states = locations
        .whereType<Map>()
        .map((e) => e['state']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final lgas = _selectedState != null
        ? _lgasFor(_selectedState!, locations)
        : <String>[];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Create your\ndriver account.',
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the details below to get started.',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 28),

              // Full name
              AppTextField(
                controller:   _nameCtrl,
                hint:         AppStrings.fullName,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 14),

              // Phone with Nigeria flag
              _PhoneField(controller: _phoneCtrl),
              const SizedBox(height: 14),

              // Email (optional)
              AppTextField(
                controller:   _emailCtrl,
                hint:     'Email address (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // Password
              AppTextField(
                controller:  _passCtrl,
                hint:    AppStrings.password,
                obscureText: !_showPass,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _showPass = !_showPass),
                  child: Icon(
                    _showPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Confirm password
              AppTextField(
                controller:  _confirmCtrl,
                hint:    AppStrings.confirmPassword,
                obscureText: !_showConfirm,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _showConfirm = !_showConfirm),
                  child: Icon(
                    _showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              // State & LGA (only when locations available)
              if (states.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DropdownField(
                  hint:     'Select State',
                  value:    _selectedState,
                  options:  states,
                  onChanged: (v) => setState(() {
                    _selectedState = v;
                    _selectedLga   = null;
                  }),
                ),
                if (_selectedState != null && lgas.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DropdownField(
                    hint:     'Select LGA',
                    value:    _selectedLga,
                    options:  lgas,
                    onChanged: (v) => setState(() => _selectedLga = v),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Terms checkbox
              GestureDetector(
                onTap: () => setState(() => _agreedTerms = !_agreedTerms),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: _agreedTerms ? Colors.black : Colors.transparent,
                        border: Border.all(
                          color: _agreedTerms
                              ? Colors.black
                              : AppColors.textSecondary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: _agreedTerms
                          ? const Icon(Icons.check,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary, height: 1.5),
                          children: const [
                            TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline),
                            ),
                            TextSpan(text: ' of ETCRide.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ],

              const SizedBox(height: 28),

              AppButton(
                label:    'CREATE ACCOUNT',
                loading:  _loading,
                onPressed: () => _register(locations),
              ),

              const SizedBox(height: 20),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Already have an account? ',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.signIn),
                      child: Text('Sign In',
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

// ── Reusable phone field ──────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

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
              controller:   controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '08012345678',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                border:          InputBorder.none,
                contentPadding:  const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
              ),
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dropdown wrapper ──────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String         hint;
  final String?        value;
  final List<String>   options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:       value,
          hint:        Text(hint,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          isExpanded:  true,
          icon:        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged:   onChanged,
          style:       AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
