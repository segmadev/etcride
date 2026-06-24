/// Passed via GoRouter state.extra when navigating to OtpScreen.
class OtpExtra {
  const OtpExtra({
    required this.contact,
    required this.contactType,
    this.isRegistration = false,
  });
  final String contact;         // email address or phone number
  final String contactType;     // 'email' | 'phone'
  final bool   isRegistration;  // true = new user; route to set_password after OTP
}
