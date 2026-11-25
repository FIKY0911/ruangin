import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';

/// App-wide unread badge for the signed-in user. Refreshes on sign-in, after
/// local actions, when the app resumes, and every [pollInterval] (the backend
/// has no socket; push via FCM is not configured in this app yet).
class NotificationCenter extends ChangeNotifier with WidgetsBindingObserver {
  NotificationCenter(this._repo, this._auth, {Duration? pollInterval}) {
    _sub = _repo.changes.listen((_) => refresh());
    _auth.addListener(_onAuth);
    WidgetsBinding.instance.addObserver(this);
    if (pollInterval != null) {
      _timer = Timer.periodic(pollInterval, (_) => refresh());
    }
    refresh();
  }

  final NotificationRepository _repo;
  final AuthController _auth;
  late final StreamSubscription<void> _sub;
  Timer? _timer;
  int _unread = 0;
  String? _userId;
  bool _disposed = false;

  int get unread => _unread;

  void _onAuth() {
    if (_auth.account?.id == _userId) return;
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final user = _auth.account;
    _userId = user?.id;
    var count = 0;
    if (user != null) {
      final result = await _repo.list(unreadOnly: true);
      count = result.valueOrNull?.unreadCount ?? _unread;
    }
    if (_disposed || count == _unread) return;
    _unread = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub.cancel();
    _auth.removeListener(_onAuth);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
