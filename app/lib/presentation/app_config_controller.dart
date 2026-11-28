import 'package:flutter/foundation.dart';

import '../data/models/app_config.dart';
import '../data/repositories/repositories.dart';
import 'auth/auth_controller.dart';

/// Server labels (`GET /app-config`), loaded once per signed-in account.
/// Until it loads (or when it fails) nothing is claimed: no "Simulasi"
/// label and no retention note.
class AppConfigController extends ChangeNotifier {
  AppConfigController(this._repo, this._auth) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AppConfigRepository _repo;
  final AuthController _auth;
  AppConfig _config = AppConfig.unknown;
  String? _userId;
  bool _disposed = false;

  AppConfig get config => _config;
  bool get simulatedData => _config.simulatedData;

  void _onAuth() {
    final id = _auth.account?.id;
    if (id == _userId) return;
    _userId = id;
    if (id == null) {
      _set(AppConfig.unknown);
    } else {
      reload();
    }
  }

  Future<void> reload() async {
    final userId = _userId;
    final value = (await _repo.load()).valueOrNull;
    if (value != null && userId == _userId) _set(value);
  }

  void _set(AppConfig next) {
    if (_disposed) return;
    _config = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
