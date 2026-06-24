import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/terms_repository.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';

class TermsAcceptanceModal extends ConsumerStatefulWidget {
  final VoidCallback? onAccepted;
  final bool isRequired;

  const TermsAcceptanceModal({
    super.key,
    this.onAccepted,
    this.isRequired = true,
  });

  @override
  ConsumerState<TermsAcceptanceModal> createState() =>
      _TermsAcceptanceModalState();
}

class _TermsAcceptanceModalState extends ConsumerState<TermsAcceptanceModal> {
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;
  bool _loading = false;
  String? _error;
  TermsAndConditionsData? _data;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final data = await ref.read(termsRepositoryProvider).getTermsAndConditions();
      if (mounted) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load T&C: $e');
      }
    }
  }

  Future<void> _acceptTerms() async {
    if (!_agreedToTerms || !_agreedToPrivacy) {
      setState(() => _error = 'Please accept both Terms & Conditions and Privacy Policy');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(termsRepositoryProvider).acceptTerms();
      if (mounted) {
        widget.onAccepted?.call();
        if (widget.isRequired) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Terms & Conditions',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Please review and accept our terms before continuing',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Content sections
              if (_data != null) ...[
                // Terms section
                _buildSection('Terms & Conditions', _data!.termsAndConditions),
                const SizedBox(height: 16),
                _buildCheckbox(
                  'I agree to the Terms & Conditions',
                  _agreedToTerms,
                  (v) => setState(() => _agreedToTerms = v ?? false),
                ),
                const SizedBox(height: 20),

                // Privacy section
                _buildSection('Privacy Policy', _data!.privacyPolicy),
                const SizedBox(height: 16),
                _buildCheckbox(
                  'I agree to the Privacy Policy',
                  _agreedToPrivacy,
                  (v) => setState(() => _agreedToPrivacy = v ?? false),
                ),
              ] else
                SizedBox(
                  height: 100,
                  child: Center(
                    child: _error != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppColors.error, size: 32),
                              const SizedBox(height: 8),
                              Text(_error!,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.error),
                                  textAlign: TextAlign.center),
                            ],
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),

              if (_error != null && _data != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                gap: 12,
                children: [
                  if (!widget.isRequired)
                    Expanded(
                      child: AppButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        variant: 'secondary',
                        label: 'Maybe Later',
                      ),
                    ),
                  Expanded(
                    child: AppButton(
                      onPressed: _loading ? null : _acceptTerms,
                      isLoading: _loading,
                      label: 'Accept & Continue',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              child: Text(
                content,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: AppTextStyles.bodySmall),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

/// Show T&C modal dialog
Future<bool?> showTermsModal(BuildContext context, {
  VoidCallback? onAccepted,
  bool isRequired = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: !isRequired,
    builder: (ctx) => TermsAcceptanceModal(
      onAccepted: onAccepted,
      isRequired: isRequired,
    ),
  );
}
