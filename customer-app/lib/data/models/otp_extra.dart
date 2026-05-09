/// Passed via GoRouter state.extra when navigating to OtpScreen.
class OtpExtra {
  const OtpExtra({required this.contact, required this.contactType});
  final String contact;      // email address or phone number
  final String contactType;  // 'email' | 'phone'
}
