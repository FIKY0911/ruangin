/// Pure form validation rules for register/login. Each returns an error
/// message, or null when the value is valid.
abstract final class AuthValidators {
  static const minPasswordLength = 8;
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Email wajib diisi.';
    if (!_email.hasMatch(v)) return 'Format email tidak valid.';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Password wajib diisi.';
    if (value.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter.';
    }
    return null;
  }

  /// Login only checks presence: length rules apply when registering.
  static String? loginPassword(String value) =>
      value.isEmpty ? 'Password wajib diisi.' : null;

  static String? confirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return 'Konfirmasi password wajib diisi.';
    if (confirm != password) return 'Konfirmasi password tidak sama.';
    return null;
  }
}
