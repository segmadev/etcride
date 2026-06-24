import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/app_exception.dart';
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
  bool    _loading = false;
  String? _error;

  // Pending verified contact changes
  String? _pendingEmail;
  String? _pendingEmailToken;
  String? _pendingPhone;
  String? _pendingPhoneToken;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl.text = user?.name ?? '';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            name:       _nameCtrl.text.trim(),
            email:      _pendingEmail,
            phone:      _pendingPhone,
            emailToken: _pendingEmailToken,
            phoneToken: _pendingPhoneToken,
          );
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = user;
      setState(() {
        _pendingEmail = null; _pendingEmailToken = null;
        _pendingPhone = null; _pendingPhoneToken = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = (e is AppException) ? e.message : 'Could not update profile. Please try again.';
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeContact(String type) async {
    final result = await showModalBottomSheet<_ContactChangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactChangeSheet(type: type),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (type == 'email') {
        _pendingEmail = result.contact;
        _pendingEmailToken = result.token;
      } else {
        _pendingPhone = result.contact;
        _pendingPhoneToken = result.token;
      }
    });
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

                // Email row
                _ContactRow(
                  label: AppStrings.emailAddress,
                  current: user?.email ?? '',
                  pending: _pendingEmail,
                  onChange: () => _changeContact('email'),
                ),
                const SizedBox(height: 16),

                // Phone row
                _ContactRow(
                  label: AppStrings.phoneNumber,
                  current: user?.phone ?? '',
                  pending: _pendingPhone,
                  onChange: () => _changeContact('phone'),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(AppStrings.phoneLocked,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ),

                // My Reports button
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/reports-history'),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('My Reports'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),

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

// ── Contact row with current value + Change button ─────────────────────────

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.current,
    required this.onChange,
    this.pending,
  });

  final String label;
  final String current;
  final String? pending;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final display = pending ?? current;
    final verified = pending != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  display.isNotEmpty ? display : '—',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: display.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ),
              if (verified)
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onChange,
                child: Text(
                  verified ? 'Change again' : 'Change',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Result returned from the contact-change bottom sheet ───────────────────

class _ContactChangeResult {
  const _ContactChangeResult({required this.contact, required this.token});
  final String contact;
  final String token;
}

// ── Bottom sheet: new contact value → send OTP → verify ───────────────────

class _ContactChangeSheet extends ConsumerStatefulWidget {
  const _ContactChangeSheet({required this.type});
  final String type; // 'phone' or 'email'

  @override
  ConsumerState<_ContactChangeSheet> createState() => _ContactChangeSheetState();
}

class _ContactChangeSheetState extends ConsumerState<_ContactChangeSheet> {
  final _contactCtrl = TextEditingController();
  final _otpCtrl     = TextEditingController();

  bool    _sending  = false;
  bool    _verifying = false;
  bool    _otpSent  = false;
  String? _error;

  bool get _isEmail => widget.type == 'email';

  String? _validateContact(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (_isEmail) {
      if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
        return 'Enter a valid email address';
      }
    } else {
      if (!RegExp(r'^(\+?234|0)[789]\d{9}$').hasMatch(v.trim().replaceAll(RegExp(r'[\s\-()]'), ''))) {
        return 'Enter a valid Nigerian phone number (07x / 08x / 09x)';
      }
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final error = _validateContact(_contactCtrl.text);
    if (error != null) { setState(() => _error = error); return; }
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).sendContactOtp(
        contact: _contactCtrl.text.trim(),
        type: widget.type,
      );
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = (e is AppException) ? e.message : 'Failed to send OTP.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter the OTP sent to you.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final token = await ref.read(authRepositoryProvider).verifyContactOtp(
        contact: _contactCtrl.text.trim(),
        type: widget.type,
        otp: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _ContactChangeResult(contact: _contactCtrl.text.trim(), token: token),
      );
    } catch (e) {
      if (mounted) setState(() => _error = (e is AppException) ? e.message : 'Invalid code. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _isEmail ? 'Email Address' : 'Phone Number';
    final hint  = _isEmail ? 'new@email.com' : '08012345678';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Change $label', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            _otpSent
                ? 'Enter the 6-digit code sent to ${_contactCtrl.text.trim()}'
                : 'Enter your new ${_isEmail ? 'email address' : 'phone number'} and we\'ll send a verification code.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          if (!_otpSent) ...[
            AppTextField(
              controller: _contactCtrl,
              label: label,
              hint: hint,
              keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: !_sending,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Send OTP',
              loading: _sending,
              onPressed: _sendOtp,
            ),
          ] else ...[
            AppTextField(
              controller: _otpCtrl,
              label: 'Verification Code',
              hint: '______',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _sending ? null : _sendOtp,
              child: Text(
                'Resend code',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Verify & Save',
              loading: _verifying,
              onPressed: _verify,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
