import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _category = 'Trip issue';
  bool _submitted  = false;

  static const _categories = [
    'Trip issue',
    'Driver behaviour',
    'Billing / payment',
    'App problem',
    'Safety concern',
    'Other',
  ];

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitted = true);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _SuccessView(onDone: () => Navigator.pop(context));
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.reportAnIssue, style: AppTextStyles.h4),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issue Category',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.black
                            : AppColors.inputFill,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              AppTextField(
                controller: _descCtrl,
                label: 'Describe the issue',
                hint: 'Tell us what happened in detail...',
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Please provide more detail (at least 10 characters)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),
              AppButton(label: 'SUBMIT REPORT', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 72, color: AppColors.success),
                const SizedBox(height: 20),
                Text('Report Submitted!', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  'Thank you for your feedback. Our team will review and respond within 24 hours.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppButton(label: 'DONE', onPressed: onDone),
              ],
            ),
          ),
        ),
      );
}
