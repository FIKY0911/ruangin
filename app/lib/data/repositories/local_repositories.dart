import 'dart:async';

import '../../core/clock.dart';
import '../../core/demo_settings.dart';
import '../../core/result.dart';
import '../fixtures/seed_data.dart';
import '../local/key_value_store.dart';
import '../models/account.dart';
import '../models/app_notification.dart';
import '../models/empty_room_report.dart';
import '../models/lecturer.dart';
import '../models/password_hash.dart';
import '../models/session.dart';
import 'repositories.dart';

/// Storage keys for local persistence.
abstract final class StoreKeys {
  static const currentAccount = 'auth.currentAccount';
  static const users = 'auth.users';
  static const sessionOverrides = 'sessions.overrides';
  static const follows = 'follows';
  static const notifications = 'notifications';
  static const reports = 'reports';
}

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._seed, this._store, this._demo);

  final SeedData _seed;
  final KeyValueStore _store;
  final DemoSettings _demo;

  List<AuthRecord> _registered() {
    final raw = _store.readJson(StoreKeys.users);
    if (raw is! List<dynamic>) return [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return AuthRecord(
        Account.fromJson(m['account'] as Map<String, dynamic>),
        PasswordHash.fromJson(m['password'] as Map<String, dynamic>),
      );
    }).toList();
  }

  Iterable<AuthRecord> _all() => [
        for (final a in _seed.accounts) AuthRecord(a, _seed.credentials[a.id]!),
        ..._registered(),
      ];

  @override
  Future<Result<AuthRecord?>> findByEmail(String email) => guard(() async {
        await _demo.beforeRead();
        return _all().where((r) => r.account.email == email).firstOrNull;
      });

  @override
  Future<Result<void>> create(AuthRecord record) => guard(() async {
        final list = [..._registered(), record];
        await _store.writeJson(StoreKeys.users, [
          for (final r in list)
            {'account': r.account.toJson(), 'password': r.password.toJson()},
        ]);
      }, message: 'Gagal menyimpan akun.');

  @override
  Future<Result<void>> saveSession(String accountId) => guard(
      () => _store.setString(StoreKeys.currentAccount, accountId),
      message: 'Gagal menyimpan sesi login.');

  @override
  Future<Result<Account?>> currentAccount() => guard(() async {
        final id = _store.getString(StoreKeys.currentAccount);
        if (id == null) return null;
        return _all().where((r) => r.account.id == id).firstOrNull?.account;
      });

  @override
  Future<void> clearSession() => _store.remove(StoreKeys.currentAccount);
}

class LocalLecturerRepository implements LecturerRepository {
  LocalLecturerRepository(this._seed, this._demo);

  final SeedData _seed;
  final DemoSettings _demo;

  @override
  Future<Result<List<Lecturer>>> search(String query) => guard(() async {
        await _demo.beforeRead();
        return filterLecturers(_seed.lecturers, query);
      });

  @override
  Future<Result<Lecturer>> byId(String id) => guard(() async {
        await _demo.beforeRead();
        final found = _seed.lecturers.where((l) => l.id == id).firstOrNull;
        if (found == null) throw const AppFailure('Dosen tidak ditemukan.');
        return found;
      });
}

/// Pure search rule (P01): partial name, case-insensitive, sorted by name.
List<Lecturer> filterLecturers(List<Lecturer> all, String query) {
  final q = query.trim().toLowerCase();
  final result = q.isEmpty
      ? List<Lecturer>.of(all)
      : all.where((l) => l.name.toLowerCase().contains(q)).toList();
  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return List.unmodifiable(result);
}

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository(this._seed, this._store, this._demo);

  final SeedData _seed;
  final KeyValueStore _store;
  final DemoSettings _demo;

  /// Seed sessions with locally persisted changes applied.
  Map<String, Session> _all() {
    final map = {for (final s in _seed.sessions) s.id: s};
    final overrides = _store.readJson(StoreKeys.sessionOverrides);
    if (overrides is Map<String, dynamic>) {
      for (final entry in overrides.entries) {
        map[entry.key] = Session.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return map;
  }

  @override
  Future<Result<List<Session>>> timeline(String lecturerId, DateTime date) =>
      guard(() async {
        await _demo.beforeRead();
        return buildTimeline(_all().values, lecturerId, date);
      });

  @override
  Future<Result<List<Session>>> onDate(DateTime date) => guard(() async {
        await _demo.beforeRead();
        final list = _all().values.where((s) => isSameDay(s.start, date)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        return List.unmodifiable(list);
      });

  @override
  Future<Result<Session>> byId(String id) => guard(() async {
        await _demo.beforeRead();
        final s = _all()[id];
        if (s == null) throw const AppFailure('Sesi tidak ditemukan.');
        return s;
      });

  @override
  Future<Result<List<Session>>> byIds(Set<String> ids) => guard(() async {
        await _demo.beforeRead();
        final all = _all();
        final list = ids.map((id) => all[id]).whereType<Session>().toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        return List.unmodifiable(list);
      });

  @override
  Future<Result<Session>> save(Session session) => guard(() async {
        final raw = _store.readJson(StoreKeys.sessionOverrides);
        final overrides = raw is Map<String, dynamic>
            ? Map<String, dynamic>.of(raw)
            : <String, dynamic>{};
        overrides[session.id] = session.toJson();
        await _store.writeJson(StoreKeys.sessionOverrides, overrides);
        return session;
      }, message: 'Gagal menyimpan perubahan sesi.');
}

/// Pure timeline rule (P02): all prodi merged, only [date], sorted by start.
List<Session> buildTimeline(
    Iterable<Session> sessions, String lecturerId, DateTime date) {
  final list = sessions
      .where((s) => s.lecturerId == lecturerId && isSameDay(s.start, date))
      .toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  return List.unmodifiable(list);
}

class LocalFollowRepository implements FollowRepository {
  LocalFollowRepository(this._store);

  final KeyValueStore _store;

  /// userId -> followed session ids.
  Map<String, Set<String>> _read() {
    final raw = _store.readJson(StoreKeys.follows);
    if (raw is! Map<String, dynamic>) return {};
    return raw.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>().toSet()));
  }

  Future<void> _write(Map<String, Set<String>> data) => _store.writeJson(
      StoreKeys.follows, data.map((k, v) => MapEntry(k, v.toList()..sort())));

  @override
  Future<Result<Set<String>>> followedSessionIds(String userId) =>
      guard(() async => Set.unmodifiable(_read()[userId] ?? const <String>{}));

  @override
  Future<Result<void>> follow(String userId, String sessionId) => guard(() async {
        final data = _read();
        (data[userId] ??= <String>{}).add(sessionId);
        await _write(data);
      }, message: 'Gagal mengikuti sesi.');

  @override
  Future<Result<void>> unfollow(String userId, String sessionId) =>
      guard(() async {
        final data = _read();
        final set = data[userId];
        if (set == null || !set.remove(sessionId)) return;
        await _write(data);
      }, message: 'Gagal berhenti mengikuti sesi.');

  @override
  Future<Result<Set<String>>> followersOf(String sessionId) => guard(() async =>
      Set.unmodifiable({
        for (final e in _read().entries)
          if (e.value.contains(sessionId)) e.key,
      }));
}

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._store, this._demo);

  final KeyValueStore _store;
  final DemoSettings _demo;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  List<AppNotification> _read() {
    final raw = _store.readJson(StoreKeys.notifications);
    if (raw is! List<dynamic>) return [];
    return raw
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<AppNotification> list) async {
    await _store.writeJson(
        StoreKeys.notifications, list.map((n) => n.toJson()).toList());
    _changes.add(null);
  }

  @override
  Future<Result<List<AppNotification>>> forUser(String userId) =>
      guard(() async {
        await _demo.beforeRead();
        final list = _read().where((n) => n.recipientId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return List.unmodifiable(list);
      });

  @override
  Future<Result<void>> addAll(List<AppNotification> notifications) =>
      guard(() async {
        if (notifications.isEmpty) return;
        await _write([..._read(), ...notifications]);
      });

  @override
  Future<Result<void>> markRead(String notificationId) => guard(() async {
        final list = _read();
        final i = list.indexWhere((n) => n.id == notificationId);
        if (i < 0 || list[i].isRead) return;
        list[i] = list[i].markRead();
        await _write(list);
      });

  void dispose() => _changes.close();
}

class LocalReportRepository implements ReportRepository {
  LocalReportRepository(this._store, this._demo);

  final KeyValueStore _store;
  final DemoSettings _demo;

  List<EmptyRoomReport> _read() {
    final raw = _store.readJson(StoreKeys.reports);
    if (raw is! List<dynamic>) return [];
    return raw
        .map((e) => EmptyRoomReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Result<List<EmptyRoomReport>>> forSession(String sessionId) =>
      guard(() async {
        await _demo.beforeRead();
        final list = _read().where((r) => r.sessionId == sessionId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return List.unmodifiable(list);
      });

  @override
  Future<Result<EmptyRoomReport>> add(EmptyRoomReport report) =>
      guard(() async {
        await _store.writeJson(StoreKeys.reports,
            [..._read(), report].map((r) => r.toJson()).toList());
        return report;
      }, message: 'Gagal mengirim laporan.');
}

/// Resets all locally persisted demo state (follows, edits, notifications…).
Future<void> resetDemoData(KeyValueStore store) async {
  for (final key in [
    StoreKeys.sessionOverrides,
    StoreKeys.follows,
    StoreKeys.notifications,
    StoreKeys.reports,
  ]) {
    await store.remove(key);
  }
}
