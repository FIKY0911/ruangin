import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';

/// P04: followed sessions of the signed-in user (persisted by the repository).
class FollowController extends ChangeNotifier {
  FollowController(this._repo, this._auth) {
    _auth.addListener(reload);
    reload();
  }

  final FollowRepository _repo;
  final AuthController _auth;
  Set<String> _followed = const {};
  bool _disposed = false;

  Set<String> get followed => _followed;
  bool isFollowing(String sessionId) => _followed.contains(sessionId);

  Future<void> reload() async {
    final user = _auth.account;
    final next = user == null
        ? const <String>{}
        : (await _repo.followedSessionIds(user.id)).valueOrNull ?? _followed;
    if (_disposed) return;
    _followed = next;
    notifyListeners();
  }

  Future<Result<void>> setFollowing(String sessionId, bool follow) async {
    final user = _auth.account;
    if (user == null) {
      return const Failure(AppFailure('Silakan masuk terlebih dahulu.'));
    }
    final result = follow
        ? await _repo.follow(user.id, sessionId)
        : await _repo.unfollow(user.id, sessionId);
    await reload();
    return result;
  }

  /// Toggles follow state; returns a user-facing message.
  Future<String> toggle(String sessionId) async {
    final wasFollowing = isFollowing(sessionId);
    final result = await setFollowing(sessionId, !wasFollowing);
    return switch (result) {
      Success() => wasFollowing
          ? 'Berhenti mengikuti sesi.'
          : 'Mengikuti sesi. Anda akan dapat kabar jika sesi berubah.',
      Failure(:final failure) => failure.message,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(reload);
    super.dispose();
  }
}
