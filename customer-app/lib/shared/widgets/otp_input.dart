import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/app_config.dart';

/// 6-box OTP input matching the green-bordered Figma design.
class OtpInput extends StatelessWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.focusNode,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    const defaultTheme = PinTheme(
      width: 48, height: 52,
      textStyle: TextStyle(
        fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        border: Border.fromBorderSide(BorderSide(color: Colors.transparent, width: 1.5)),
      ),
    );

    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.success, width: 1.5),
        color: AppColors.white,
      ),
    );

    final filledTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.success, width: 1.5),
        color: AppColors.white,
      ),
    );

    return Pinput(
      length: AppConfig.otpLength,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      defaultPinTheme: defaultTheme,
      focusedPinTheme: focusedTheme,
      submittedPinTheme: filledTheme,
      keyboardType: TextInputType.number,
      onCompleted: onCompleted,
      onChanged: onChanged,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
