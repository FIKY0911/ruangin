import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/result.dart';
import '../data/models/account.dart';
import '../data/models/password_hash.dart';
import '../data/repositories/repositories.dart';
import 'auth_validators.dart';
import 'greeting.dart';
import 'password_hasher.dart';

enum AuthField { email, password, confirmPassword }

enum AuthErrorCode {
  invalidInput,
  emailTaken,
  accountNotFound,
  wrongPassword,
  storage,
}

/// Failure with an error code and optional per-field messages for forms.
class AuthFailure extends AppFailure {
  const AuthFailure(
    super.message, {
    required this.code,
    this.fieldErrors = const {},
    super.cause,
  });

  final AuthErrorCode code;
  final Map<AuthField, String> fieldErrors;
}

@immutable
class RegisterInput {
  const RegisterInput({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  final String email;
  final String password;
  final String confirmPassword;
}

/// Register / login / logout / persistent session use cases (pure Dart).
class AuthService {
  AuthService({
    required this._repo,
    required this._hasher,
    required this._clock,
  });

  final AuthRepository _repo;
  final PasswordHasher _hasher;
  final Clock _clock;

  /// Per-instance counter so two accounts created in the same microsecond
  /// (or under a fixed test clock) never get the same id.
  int _seq = 0;

  static Map<AuthField, String> validateRegister(RegisterInput input) => {
        AuthField.email: ?AuthValidators.email(input.email),
        AuthField.password: ?AuthValidators.password(input.password),
        AuthField.confirmPassword: ?AuthValidators.confirmPassword(
            input.password, input.confirmPassword),
      };

  static Map<AuthField, String> validateLogin(String email, String password) => {
        AuthField.email: ?AuthValidators.email(email),
        AuthField.password: ?AuthValidators.loginPassword(password),
      };

  /// Creates a local account (role defaults to mahasiswa). Does not sign in.
  Future<Result<Account>> register(RegisterInput input) async {
    final errors = validateRegister(input);
    if (errors.isNotEmpty) {
      return Failure(AuthFailure('Periksa kembali isian formulir.',
          code: AuthErrorCode.invalidInput, fieldErrors: errors));
    }
    final email = AuthValidators.normalizeEmail(input.email);
    final existing = await _repo.findByEmail(email);
    switch (existing) {
      case Failure(:final failure):
        return Failure(_storage(failure));
      case Success(value: _?):
        return const Failure(AuthFailure('Email sudah terdaftar.',
            code: AuthErrorCode.emailTaken,
            fieldErrors: {AuthField.email: 'Email sudah terdaftar.'}));
      case Success():
        break;
    }
    final account = Account(
      id: 'u-${_clock.now().microsecondsSinceEpoch}-${_seq++}',
      name: greetingNameFromEmail(email),
      email: email,
      role: UserRole.mahasiswa,
      subtitle: 'Mahasiswa',
    );
    final created =
        await _repo.create(AuthRecord(account, _hasher.hash(input.password)));
    return switch (created) {
      Success() => Success(account),
      Failure(:final failure) => Failure(_storage(failure)),
    };
  }

  /// Verifies credentials and persists the session.
  Future<Result<Account>> login(String email, String password) async {
    final errors = validateLogin(email, password);
    if (errors.isNotEmpty) {
      return Failure(AuthFailure('Periksa kembali isian formulir.',
          code: AuthErrorCode.invalidInput, fieldErrors: errors));
    }
    final found = await _repo.findByEmail(AuthValidators.normalizeEmail(email));
    final AuthRecord record;
    switch (found) {
      case Failure(:final failure):
        return Failure(_storage(failure));
      case Success(value: null):
        return const Failure(AuthFailure(
            'Akun tidak ditemukan. Periksa email atau daftar akun baru.',
            code: AuthErrorCode.accountNotFound,
            fieldErrors: {AuthField.email: 'Akun tidak ditemukan.'}));
      case Success(value: final r?):
        record = r;
    }
    if (!_hasher.verify(password, record.password)) {
      return const Failure(AuthFailure('Password salah.',
          code: AuthErrorCode.wrongPassword,
          fieldErrors: {AuthField.password: 'Password salah.'}));
    }
    final saved = await _repo.saveSession(record.account.id);
    return switch (saved) {
      Success() => Success(record.account),
      Failure(:final failure) => Failure(_storage(failure)),
    };
  }

  /// Returns the persisted signed-in account, if any.
  Future<Account?> restoreSession() async =>
      (await _repo.currentAccount()).valueOrNull;

  Future<void> logout() => _repo.clearSession();

  AuthFailure _storage(AppFailure f) =>
      AuthFailure(f.message, code: AuthErrorCode.storage, cause: f.cause);
}
