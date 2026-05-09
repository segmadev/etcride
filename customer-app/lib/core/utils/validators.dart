abstract final class Validators {
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required.';
    if (value.trim().length < 2) return 'Name is too short.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required.';
    if (value.replaceAll(RegExp(r'\D'), '').length < 7) return 'Enter a valid phone number.';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.trim().isEmpty) return 'Password is required';
    if (v.trim().length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? packageDescription(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please describe the package.';
    if (value.trim().length < 5) return 'Description is too short.';
    return null;
  }
}
