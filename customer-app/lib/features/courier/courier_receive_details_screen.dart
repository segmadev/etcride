import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class CourierReceiveDetailsScreen extends ConsumerStatefulWidget {
  const CourierReceiveDetailsScreen({super.key});

  @override
  ConsumerState<CourierReceiveDetailsScreen> createState() =>
      _CourierReceiveDetailsScreenState();
}

class _CourierReceiveDetailsScreenState
    extends ConsumerState<CourierReceiveDetailsScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    if (draft.recipientName  != null) _nameCtrl.text  = draft.recipientName!;
    if (draft.recipientPhone != null) _phoneCtrl.text = draft.recipientPhone!;
    if (draft.packageDescription != null) _descCtrl.text = draft.packageDescription!;
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          recipientName:      _nameCtrl.text.trim(),
          recipientPhone:     _phoneCtrl.text.trim(),
          packageDescription: _descCtrl.text.trim(),
        ));
    context.push(AppRoutes.deliveryRules);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(AppStrings.receiveDetails, style: AppTextStyles.h4),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recipient Information',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _nameCtrl,
                  label: "Recipient's Full Name",
                  hint: 'Full name',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: Validators.name,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _phoneCtrl,
                  label: AppStrings.receiverPhone,
                  hint: '08012345678',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 24),

                Text('Package Details',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _descCtrl,
                  label: AppStrings.packageDesc,
                  hint: AppStrings.describeParcel,
                  textInputAction: TextInputAction.done,
                  validator: Validators.required,
                  onSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 32),

                AppButton(
                    label: AppStrings.continueBtn, onPressed: _continue),
              ],
            ),
          ),
        ),
      );
}
