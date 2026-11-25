import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models/account.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/repositories.dart';
import 'auth_validators.dart';

enum AuthField { email, password, confirmPassword }

enum AuthErrorCode {
  invalidInput,
  emailTaken,
  accountNotFound,
  wrongPassword,

  /// Network/server problem (message comes from the API client).
  server,
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

/// Register / login / logout / persistent session use cases. Credentials are
/// checked by the server (`/auth/*`); the same validation rules run locally
/// first so obvious mistakes don't need a round trip.
class AuthService {
  AuthService({required this._repo});

  final AuthRepository _repo;

  static Map<AuthField, String> validateRegister(RegisterInput input) => {
    AuthField.email: ?AuthValidators.email(input.email),
    AuthField.password: ?AuthValidators.password(input.password),
    AuthField.confirmPassword: ?AuthValidators.confirmPassword(
      input.password,
      input.confirmPassword,
    ),
  };

  static Map<AuthField, String> validateLogin(String email, String password) =>
      {
        AuthField.email: ?AuthValidators.email(email),
        AuthField.password: ?AuthValidators.loginPassword(password),
      };

  /// Creates a mahasiswa account on the server. Does not sign in.
  Future<Result<Account>> register(RegisterInput input) async {
    final errors = validateRegister(input);
    if (errors.isNotEmpty) {
      return Failure(
        AuthFailure(
          'Periksa kembali isian formulir.',
          code: AuthErrorCode.invalidInput,
          fieldErrors: errors,
        ),
      );
    }
    final result = await _repo.register(
      email: AuthValidators.normalizeEmail(input.email),
      password: input.password,
      confirmPassword: input.confirmPassword,
    );
    return _mapFailure(result);
  }

  /// Verifies credentials on the server and persists the token.
  Future<Result<Account>> login(String email, String password) async {
    final errors = validateLogin(email, password);
    if (errors.isNotEmpty) {
      return Failure(
        AuthFailure(
          'Periksa kembali isian formulir.',
          code: AuthErrorCode.invalidInput,
          fieldErrors: errors,
        ),
      );
    }
    return _mapFailure(
      await _repo.login(AuthValidators.normalizeEmail(email), password),
    );
  }

  /// Returns the signed-in account (validated with `/auth/me`), if any.
  Future<Account?> restoreSession() async =>
      (await _repo.restore()).valueOrNull;

  /// Re-reads the account from the server (points, role).
  Future<Result<Account>> refreshAccount() => _repo.me();

  Future<void> logout() => _repo.logout();

  static Result<Account> _mapFailure(Result<Account> r) => switch (r) {
    Success() => r,
    Failure(failure: final ApiFailure f) => Failure(fromApi(f)),
    Failure(:final failure) => Failure(
      AuthFailure(
        failure.message,
        code: AuthErrorCode.server,
        cause: failure.cause,
      ),
    ),
  };

  /// Maps the server's `{message, code, errors}` to form errors.
  static AuthFailure fromApi(ApiFailure f) {
    final code = switch (f.code) {
      'invalidInput' => AuthErrorCode.invalidInput,
      'emailTaken' => AuthErrorCode.emailTaken,
      'accountNotFound' => AuthErrorCode.accountNotFound,
      'wrongPassword' => AuthErrorCode.wrongPassword,
      _ => AuthErrorCode.server,
    };
    final fields = <AuthField, String>{
      for (final field in AuthField.values) field: ?f.fieldErrors[field.name],
    };
    return AuthFailure(f.message, code: code, fieldErrors: fields, cause: f);
  }
}
