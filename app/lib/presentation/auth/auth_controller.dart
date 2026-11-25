import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../data/models/account.dart';
import '../../domain/auth_service.dart';

/// App-wide session state: who is signed in (token persisted by the API
/// repository; account validated with `/auth/me` on start).
class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;
  Account? _account;
  bool _restoring = true;
  String? _signedOutReason;

  Account? get account => _account;
  bool get isRestoring => _restoring;
  bool get isSignedIn => _account != null;

  /// Set when the server ended the session (401); shown once on Welcome.
  String? takeSignedOutReason() {
    final r = _signedOutReason;
    _signedOutReason = null;
    return r;
  }

  Future<void> restore() async {
    _account = await _service.restoreSession();
    _restoring = false;
    notifyListeners();
  }

  /// Called by the login flow after credentials were verified.
  void onSignedIn(Account account) {
    _account = account;
    notifyListeners();
  }

  /// Re-reads points/role from the server.
  Future<void> refreshAccount() async {
    if (_account == null) return;
    final r = await _service.refreshAccount();
    if (r case Success(:final value)
        when value != _account && _account != null) {
      _account = value;
      notifyListeners();
    }
  }

  /// The API answered 401 `unauthenticated` (token revoked, demo reset…).
  void onSessionExpired() {
    if (_account == null) return;
    _account = null;
    _signedOutReason = 'Sesi login berakhir. Silakan masuk lagi.';
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    _account = null;
    notifyListeners();
  }
}
