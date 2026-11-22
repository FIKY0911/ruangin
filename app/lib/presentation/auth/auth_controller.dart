import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import '../../domain/auth_service.dart';

/// App-wide session state: who is signed in (persisted by [AuthService]).
class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;
  Account? _account;
  bool _restoring = true;

  Account? get account => _account;
  bool get isRestoring => _restoring;
  bool get isSignedIn => _account != null;

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

  Future<void> logout() async {
    await _service.logout();
    _account = null;
    notifyListeners();
  }
}
