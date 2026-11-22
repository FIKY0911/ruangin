import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../data/models/account.dart';
import '../../domain/auth_service.dart';
import 'auth_controller.dart';

/// Shared submit/error state for auth forms.
abstract class _FormController extends ChangeNotifier {
  bool _submitting = false;
  Map<AuthField, String> _fieldErrors = const {};
  String? _error;

  bool get isSubmitting => _submitting;
  String? get errorMessage => _error;
  String? errorFor(AuthField field) => _fieldErrors[field];

  void _clearError(AuthField field) {
    if (!_fieldErrors.containsKey(field) && _error == null) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    _error = null;
    notifyListeners();
  }

  void _start() {
    _submitting = true;
    _error = null;
    notifyListeners();
  }

  void _finish(Result<Account> result) {
    _submitting = false;
    switch (result) {
      case Success():
        _fieldErrors = const {};
        _error = null;
      case Failure(failure: final AuthFailure f):
        _fieldErrors = f.fieldErrors;
        _error = f.code == AuthErrorCode.invalidInput ? null : f.message;
      case Failure(:final failure):
        _fieldErrors = const {};
        _error = failure.message;
    }
    notifyListeners();
  }
}

class LoginController extends _FormController {
  LoginController(this._service, this._auth, {String initialEmail = ''})
      : _email = initialEmail;

  final AuthService _service;
  final AuthController _auth;
  String _email;
  String _password = '';

  String get email => _email;

  void setEmail(String v) {
    _email = v;
    _clearError(AuthField.email);
  }

  void setPassword(String v) {
    _password = v;
    _clearError(AuthField.password);
  }

  /// Returns true when signed in.
  Future<bool> submit() async {
    if (isSubmitting) return false;
    _start();
    final result = await _service.login(_email, _password);
    _finish(result);
    if (result case Success(:final value)) {
      _auth.onSignedIn(value);
      return true;
    }
    return false;
  }
}

class RegisterController extends _FormController {
  RegisterController(this._service);

  final AuthService _service;
  String _email = '';
  String _password = '';
  String _confirm = '';

  void setEmail(String v) {
    _email = v;
    _clearError(AuthField.email);
  }

  void setPassword(String v) {
    _password = v;
    _clearError(AuthField.password);
  }

  void setConfirmPassword(String v) {
    _confirm = v;
    _clearError(AuthField.confirmPassword);
  }

  /// Returns the created account (caller then routes to login), or null.
  Future<Account?> submit() async {
    if (isSubmitting) return null;
    _start();
    final result = await _service.register(RegisterInput(
      email: _email,
      password: _password,
      confirmPassword: _confirm,
    ));
    _finish(result);
    return result.valueOrNull;
  }
}
