import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../data/models/user_model.dart';
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
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  void _autoFillFromUser(UserModel user) {
    if (_nameCtrl.text.trim().isEmpty && user.name.trim().isNotEmpty) {
      _nameCtrl.text = user.name.trim();
    }
    if (_emailCtrl.text.trim().isEmpty && user.email.trim().isNotEmpty) {
      _emailCtrl.text = user.email.trim();
    }
    if (_phoneCtrl.text.trim().isEmpty && user.phone.trim().isNotEmpty) {
      _phoneCtrl.text = user.phone.trim();
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill fields the user already provided
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _autoFillFromUser(user);
    }
  }

  Widget _nigeriaFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 22,
        height: 22,
        child: FutureBuilder<String>(
          future: rootBundle.loadString(AppAssets.nigeriaFlag),
          builder: (context, snap) {
            final svg = snap.data;
            if (svg == null) return const SizedBox.shrink();
            final match =
                RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
            if (match == null) return const SizedBox.shrink();
            final bytes = base64Decode(match.group(1)!);
            return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
        name:  _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = user;
      if (widget.asSheet) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = (e is AppException) ? e.message : 'Could not save profile. Please try again.';
      setState(() => _error = msg);
      // SnackBar as secondary signal for non-sheet mode (sheet hides it anyway)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
                prefixIcon: SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _nigeriaFlag(),
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 48),
                suffixIcon: phoneLocked
                    ? const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.textHint)
                    : null,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

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
    ref.listen<UserModel?>(currentUserProvider, (prev, next) {
      if (next == null) return;
      _autoFillFromUser(next);
    });

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
