import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl.text = user?.name ?? '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(name: _nameCtrl.text.trim());
      ref.read(currentUserProvider.notifier).state = user;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return LoadingOverlay.wrap(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(AppStrings.profile, style: AppTextStyles.h4),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    (user?.name.isNotEmpty == true)
                        ? user!.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: AppTextStyles.h2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 32),

                AppTextField(
                  controller: _nameCtrl,
                  label: AppStrings.fullName,
                  hint: 'Your name',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  validator: Validators.name,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: AppStrings.emailAddress,
                  hint: user?.email ?? '',
                  enabled: false,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.textHint),
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: AppStrings.phoneNumber,
                  hint: user?.phone ?? '',
                  enabled: false,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.textHint),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(AppStrings.phoneLocked,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ),

                const SizedBox(height: 32),
                AppButton(label: AppStrings.updateProfile, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
