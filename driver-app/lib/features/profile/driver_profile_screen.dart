import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/driver_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_button.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  String? _error;

  // Pending email verification
  String? _verifiedEmail;
  String? _emailToken;

  @override
  void initState() {
    super.initState();
    final driver = ref.read(currentDriverProvider);
    _nameController = TextEditingController(text: driver?.name ?? '');
    _emailController = TextEditingController(text: driver?.email ?? '');
    _phoneController = TextEditingController(text: driver?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name  = _nameController.text.trim();
    final email = _emailController.text.trim();
    final driver = ref.read(currentDriverProvider);
    final emailChanged = email != (driver?.email ?? '');

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }

    // If email changed and not yet verified, trigger OTP flow
    if (emailChanged && email.isNotEmpty) {
      if (_verifiedEmail != email) {
        final result = await _requestEmailVerification(email);
        if (result == null || !mounted) return;
        setState(() { _verifiedEmail = email; _emailToken = result; });
      }
    }

    setState(() { _saving = true; _error = null; });

    try {
      final updatedDriver = await ref
          .read(driverAuthRepositoryProvider)
          .updateProfile(
            name: name,
            email: email,
            emailToken: (emailChanged && email.isNotEmpty) ? _emailToken : null,
          );
      if (!mounted) return;
      ref.read(currentDriverProvider.notifier).state = updatedDriver;
      await ref
          .read(driverAuthRepositoryProvider)
          .updateCachedDriver(updatedDriver);
      setState(() { _verifiedEmail = null; _emailToken = null; });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      const msg = 'Could not update profile. Please try again.';
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(msg),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _requestEmailVerification(String email) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmailOtpSheet(
        email: email,
        onVerified: (token) => Navigator.of(context).pop(token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppBackButton(onTap: () => context.pop()),
                    Expanded(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 84),
                  ],
                ),
                const SizedBox(height: 54),
                Center(child: _ProfileAvatar(driver: driver)),
                const SizedBox(height: 44),
                _ProfileInputField(
                  label: 'Full Name',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 22),
                _ProfileInputField(
                  label: 'Email Address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 22),
                _ProfileInputField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  enabled: false,
                  readOnly: true,
                  suffix: Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cannot change phone number till after 30 days.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 46),
                AppButton(
                  label: 'UPDATE PROFILE',
                  height: 55,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.driver});

  final DriverModel? driver;

  @override
  Widget build(BuildContext context) {
    final photoUrl = driver?.photo?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border: Border.all(color: const Color(0xFFB8B8C7), width: 1),
          ),
          child: ClipOval(
            child: hasPhoto
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const _ProfileAvatarFallback(),
                    errorWidget: (_, _, _) => const _ProfileAvatarFallback(),
                  )
                : const _ProfileAvatarFallback(),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE4A91D),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.editIcon,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarFallback extends StatelessWidget {
  const _ProfileAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F4F4),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 56,
        color: Colors.black.withValues(alpha: 0.22),
      ),
    );
  }
}

class _ProfileInputField extends StatelessWidget {
  const _ProfileInputField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.readOnly = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool readOnly;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.h3.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          readOnly: readOnly,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 17,
            ),
            filled: true,
            fillColor: enabled
                ? const Color(0xFFF4F4F4)
                : const Color(0xFFD9D9D9),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: suffix,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Email OTP verification bottom sheet (driver) ───────────────────────────

class _EmailOtpSheet extends ConsumerStatefulWidget {
  const _EmailOtpSheet({required this.email, required this.onVerified});
  final String email;
  final void Function(String token) onVerified;

  @override
  ConsumerState<_EmailOtpSheet> createState() => _EmailOtpSheetState();
}

class _EmailOtpSheetState extends ConsumerState<_EmailOtpSheet> {
  final _otpCtrl   = TextEditingController();
  bool  _sending   = false;
  bool  _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).sendContactOtp(
        contact: widget.email,
        type: 'email',
      );
      if (mounted) setState(() => _sending = false);
    } catch (e) {
      if (mounted) setState(() {
        _error = (e is ApiException) ? e.message : 'Failed to send OTP.';
        _sending = false;
      });
    }
  }

  Future<void> _verify() async {
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter the OTP sent to your email.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final token = await ref.read(driverAuthRepositoryProvider).verifyContactOtp(
        contact: widget.email,
        type: 'email',
        otp: _otpCtrl.text.trim(),
      );
      widget.onVerified(token);
    } catch (e) {
      if (mounted) setState(() {
        _error = (e is ApiException) ? e.message : 'Invalid code. Please try again.';
        _verifying = false;
      });
    }
  }

  @override
  void dispose() { _otpCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Verify Email',
              style: AppTextStyles.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _sending
                ? 'Sending verification code to ${widget.email}…'
                : 'Enter the 6-digit code sent to ${widget.email}',
            style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          if (_sending) ...[
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            _ProfileInputField(
              label: 'Verification Code',
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _sendOtp,
              child: Text(
                'Resend code',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Verify Email',
              height: 52,
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
