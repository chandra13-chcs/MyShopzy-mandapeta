abstract final class AuthValidators {
  static String? requiredName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter your full name.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password.';
    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Use at least 8 characters with a letter and a number.';
    }
    return null;
  }
}
