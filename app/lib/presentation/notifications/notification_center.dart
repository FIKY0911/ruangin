import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';

/// App-wide unread badge for the signed-in user.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter(this._repo, this._auth) {
    _sub = _repo.changes.listen((_) => refresh());
    _auth.addListener(refresh);
    refresh();
  }

  final NotificationRepository _repo;
  final AuthController _auth;
  late final StreamSubscription<void> _sub;
  int _unread = 0;
  bool _disposed = false;

  int get unread => _unread;

  Future<void> refresh() async {
    final user = _auth.account;
    var count = 0;
    if (user != null) {
      final result = await _repo.forUser(user.id);
      count = result.valueOrNull?.where((n) => !n.isRead).length ?? _unread;
    }
    if (_disposed || count == _unread) return;
    _unread = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    _auth.removeListener(refresh);
    super.dispose();
  }
}
