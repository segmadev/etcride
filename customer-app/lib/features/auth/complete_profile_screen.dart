import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/utils/validators.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/loading_overlay.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, this.asSheet = false});

  final bool asSheet;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading      = false;
  bool _obscurePass  = true;
  bool _obscureConf  = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields the user already provided
    final user = ref.read(currentUserProvider);
    if (user != null) {
      if (user.name.isNotEmpty)  _nameCtrl.text  = user.name;
      if (user.email.isNotEmpty) _emailCtrl.text = user.email;
      if (user.phone.isNotEmpty) _phoneCtrl.text = user.phone;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
        name:     _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
      ref.read(currentUserProvider.notifier).state = user;
      if (!mounted) return;
      if (widget.asSheet) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Widget _sheetContent({
    ScrollController? scrollController,
    required bool emailLocked,
    required bool phoneLocked,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(AppStrings.completeProfile,
                  style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                AppStrings.completeProfileSub,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              AppTextField(
                controller: _nameCtrl,
                label: AppStrings.fullName,
                hint: 'Enter your full name',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                validator: Validators.name,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _emailCtrl,
                label: AppStrings.emailAddress,
                hint: 'your@email.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                enabled: !emailLocked,
                readOnly: emailLocked,
                suffixIcon: emailLocked
                    ? const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.textHint)
                    : null,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _phoneCtrl,
                label: AppStrings.phoneNumber,
                hint: '08012345678',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: Validators.phone,
                enabled: !phoneLocked,
                readOnly: phoneLocked,
                suffixIcon: phoneLocked
                    ? const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.textHint)
                    : null,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _passCtrl,
                label: AppStrings.password,
                hint: 'Min. 6 characters',
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _confirmCtrl,
                label: AppStrings.confirmPassword,
                hint: 'Re-enter password',
                obscureText: _obscureConf,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _passCtrl.text) return 'Passwords do not match';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConf
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConf = !_obscureConf),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 32),

              AppButton(label: AppStrings.saveProfile, onPressed: _save),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final emailLocked = user?.email.isNotEmpty ?? false;
    final phoneLocked = user?.phone.isNotEmpty ?? false;

    return LoadingOverlay.wrap(
      loading: _loading,
      child: widget.asSheet
          ? _sheetContent(emailLocked: emailLocked, phoneLocked: phoneLocked)
          : Scaffold(
              backgroundColor: AppColors.white,
              appBar: AppBar(
                backgroundColor: AppColors.white,
                elevation: 0,
                leading: const BackButton(color: AppColors.textPrimary),
              ),
              body: _sheetContent(
                emailLocked: emailLocked,
                phoneLocked: phoneLocked,
              ),
            ),
    );
  }
}

Future<void> showCompleteProfileDrawer(BuildContext context) async {
  await showAppBottomDrawer<void>(
    context: context,
    child: const CompleteProfileScreen(asSheet: true),
  );
}
