import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';

/// P04: followed sessions of the signed-in user (`/me/follows`).
class FollowController extends ChangeNotifier {
  FollowController(this._repo, this._auth) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final FollowRepository _repo;
  final AuthController _auth;
  Set<String> _followed = const {};
  String? _userId;
  bool _disposed = false;

  Set<String> get followed => _followed;
  bool isFollowing(String sessionId) => _followed.contains(sessionId);

  void _onAuth() {
    final id = _auth.account?.id;
    if (id == _userId) return;
    _userId = id;
    reload();
  }

  /// Reloads from the server; returns the followed sessions (null on failure).
  Future<List<Session>?> reload() async {
    if (_auth.account == null) {
      _set(const {});
      return const [];
    }
    final result = await _repo.followed();
    final sessions = result.valueOrNull;
    if (sessions != null) _set({for (final s in sessions) s.id});
    return sessions;
  }

  /// Seeds the state from a session the server marked as followed.
  void observe(Session s) {
    if (s.isFollowed == isFollowing(s.id)) return;
    _set(s.isFollowed ? {..._followed, s.id} : ({..._followed}..remove(s.id)));
  }

  void _set(Set<String> next) {
    if (_disposed) return;
    _followed = Set.unmodifiable(next);
    notifyListeners();
  }

  Future<Result<void>> setFollowing(String sessionId, bool follow) async {
    if (_auth.account == null) {
      return const Failure(AppFailure('Silakan masuk terlebih dahulu.'));
    }
    final result = follow
        ? await _repo.follow(sessionId)
        : await _repo.unfollow(sessionId);
    if (result.isSuccess) {
      _set(
        follow
            ? {..._followed, sessionId}
            : ({..._followed}..remove(sessionId)),
      );
    }
    return result;
  }

  /// Toggles follow state; returns a user-facing message.
  Future<String> toggle(String sessionId) async {
    final wasFollowing = isFollowing(sessionId);
    final result = await setFollowing(sessionId, !wasFollowing);
    return switch (result) {
      Success() =>
        wasFollowing
            ? 'Berhenti mengikuti sesi.'
            : 'Mengikuti sesi. Anda akan dapat kabar jika sesi berubah.',
      Failure(:final failure) => failure.message,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
