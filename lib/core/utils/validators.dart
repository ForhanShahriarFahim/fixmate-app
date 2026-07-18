abstract final class Validators {
  static String? requiredText(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, label: 'Email');
    if (required != null) return required;
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return pattern.hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address.';
  }

  static String? password(String? value) {
    final required = requiredText(value, label: 'Password');
    if (required != null) return required;
    return value!.length >= 8 ? null : 'Use at least 8 characters.';
  }

  static String? bangladeshPhone(String? value) {
    final normalized = normalizeBangladeshPhone(value ?? '');
    return RegExp(r'^\+8801[3-9]\d{8}$').hasMatch(normalized)
        ? null
        : 'Enter a Bangladesh mobile number.';
  }

  static String normalizeBangladeshPhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('01')) digits = '+88$digits';
    if (digits.startsWith('8801')) digits = '+$digits';
    return digits;
  }

  static String normalizeKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
