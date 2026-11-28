import 'package:flutter/widgets.dart';

import '../data/models/app_config.dart';
import '../data/repositories/repositories.dart';
import 'auth/auth_controller.dart';

/// Server labels (`GET /app-config`), loaded per signed-in account.
///
/// Fail-safe for PRD §10 ("tandai data sintetis"): until the server answers,
/// or when the request fails, the "Simulasi" label stays visible
/// ([AppConfig.unknown]). The config is fetched again on pull-to-refresh
/// (Beranda) and whenever the app comes back to the foreground.
class AppConfigController extends ChangeNotifier with WidgetsBindingObserver {
  AppConfigController(this._repo, this._auth) {
    _auth.addListener(_onAuth);
    WidgetsBinding.instance.addObserver(this);
    _onAuth();
  }

  final AppConfigRepository _repo;
  final AuthController _auth;
  AppConfig _config = AppConfig.unknown;
  String? _userId;
  bool _loaded = false;
  bool _disposed = false;

  AppConfig get config => _config;
  bool get simulatedData => _config.simulatedData;

  /// True once the server's answer for the current account arrived.
  bool get isLoaded => _loaded;

  void _onAuth() {
    final id = _auth.account?.id;
    if (id == _userId) return;
    _userId = id;
    _loaded = false;
    _set(AppConfig.unknown);
    if (id != null) reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) reload();
  }

  /// Fetches the config again; a failure keeps the current (fail-safe) value.
  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    final value = (await _repo.load()).valueOrNull;
    if (value != null && userId == _userId && !_disposed) {
      _loaded = true;
      _set(value);
    }
  }

  void _set(AppConfig next) {
    if (_disposed) return;
    _config = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
