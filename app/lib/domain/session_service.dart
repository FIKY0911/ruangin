import '../core/clock.dart';
import '../core/formatters.dart';
import '../core/result.dart';
import '../data/models/account.dart';
import '../data/models/app_notification.dart';
import '../data/models/empty_room_report.dart';
import '../data/models/session.dart';
import '../data/repositories/repositories.dart';
import 'session_permissions.dart';
import 'session_status.dart';

/// Use cases that change a session (P05) or report on it (P09), and fan the
/// change out as in-app notifications to followers (P06).
class SessionService {
  SessionService({
    required this._sessions,
    required this._follows,
    required this._notifications,
    required this._reports,
    required this._clock,
  });

  final SessionRepository _sessions;
  final FollowRepository _follows;
  final NotificationRepository _notifications;
  final ReportRepository _reports;
  final Clock _clock;
  int _seq = 0;

  String _newId(String prefix) =>
      '$prefix-${_clock.now().microsecondsSinceEpoch}-${_seq++}';

  Future<Result<Session>> changeTime(
      Account actor, String sessionId, DateTime start, DateTime end) {
    return _edit(actor, sessionId, (s) {
      if (s.isCancelled) throw const AppFailure('Sesi sudah dibatalkan.');
      if (!end.isAfter(start)) {
        throw const AppFailure('Jam selesai harus setelah jam mulai.');
      }
      if (start == s.start && end == s.end) {
        throw const AppFailure('Jam tidak berubah.');
      }
      return _Change(
        s.copyWith(start: start, end: end),
        'Jam diubah: ${formatTimeRange(s.start, s.end)} → ${formatTimeRange(start, end)}',
        'Jam berubah menjadi ${formatTimeRange(start, end)}',
      );
    });
  }

  Future<Result<Session>> changeRoom(
      Account actor, String sessionId, String room) {
    final newRoom = room.trim();
    return _edit(actor, sessionId, (s) {
      if (s.isCancelled) throw const AppFailure('Sesi sudah dibatalkan.');
      if (newRoom.isEmpty) throw const AppFailure('Ruang tidak boleh kosong.');
      if (newRoom == s.room) throw const AppFailure('Ruang tidak berubah.');
      return _Change(
        s.copyWith(room: newRoom),
        'Ruang dipindah: ${s.room} → $newRoom',
        'Pindah ruang: ${s.room} → $newRoom',
      );
    });
  }

  Future<Result<Session>> cancel(Account actor, String sessionId) {
    return _edit(actor, sessionId, (s) {
      if (s.isCancelled) throw const AppFailure('Sesi sudah dibatalkan.');
      return _Change(
        s.copyWith(isCancelled: true),
        'Sesi dibatalkan',
        'Sesi dibatalkan',
      );
    });
  }

  Future<Result<Session>> recordAttendance(Account actor, String sessionId) {
    return _edit(actor, sessionId, (s) {
      if (s.isCancelled) {
        throw const AppFailure('Sesi batal tidak bisa dicatat hadir.');
      }
      if (s.attendance != null) {
        throw const AppFailure('Kehadiran sesi sudah tercatat.');
      }
      final now = _clock.now();
      return _Change(
        s.copyWith(
          attendance: AttendanceRecord(
              recordedAt: now, source: 'Dicatat ${actor.role.label.toLowerCase()}'),
        ),
        'Kehadiran kelas dicatat (${formatTime(now)})',
        'Kelas tercatat berjalan · ${formatTime(now)}',
      );
    });
  }

  Future<Result<Session>> _edit(
    Account actor,
    String sessionId,
    _Change Function(Session current) apply,
  ) async {
    final loaded = await _sessions.byId(sessionId);
    final Session current;
    switch (loaded) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(:final value):
        current = value;
    }
    if (!canEditSession(actor, current)) {
      return const Failure(
          AppFailure('Anda tidak berhak mengubah sesi ini.'));
    }

    final _Change change;
    try {
      change = apply(current);
    } on AppFailure catch (f) {
      return Failure(f);
    }

    final now = _clock.now();
    final actorLabel = '${actor.role.label} · ${actor.name}';
    final updated = change.session.copyWith(
      updatedAt: now,
      source: actorLabel,
      history: List.unmodifiable([
        ...current.history,
        ChangeEntry(at: now, actor: actorLabel, description: change.historyText),
      ]),
    );

    final saved = await _sessions.save(updated);
    if (saved case Success(:final value)) {
      await _notifyFollowers(
        value,
        exclude: actor.id,
        kind: NotificationKind.sessionChanged,
        title: '${value.courseName}: ${change.notificationText}',
        body: '${formatDate(value.start)} · ${formatTimeRange(value.start, value.end)} · '
            '${value.room} · status ${value.statusLabel}',
      );
    }
    return saved;
  }

  /// P09: a student's report. Never changes the session status; followers are
  /// told it is "belum dikonfirmasi". One report per user per session.
  Future<Result<EmptyRoomReport>> reportEmptyRoom(
      Account reporter, String sessionId) async {
    if (!canReportEmptyRoom(reporter)) {
      return const Failure(
          AppFailure('Hanya mahasiswa yang dapat melapor ruang kosong.'));
    }
    final sessionResult = await _sessions.byId(sessionId);
    if (sessionResult case Failure(:final failure)) return Failure(failure);
    final session = sessionResult.valueOrNull!;

    final existing = await _reports.forSession(sessionId);
    if (existing case Failure(:final failure)) return Failure(failure);
    final mine = existing.valueOrNull!
        .where((r) => r.reporterId == reporter.id)
        .firstOrNull;
    if (mine != null) return Success(mine);

    final report = EmptyRoomReport(
      id: _newId('r'),
      sessionId: sessionId,
      reporterId: reporter.id,
      createdAt: _clock.now(),
    );
    final saved = await _reports.add(report);
    if (saved.isSuccess) {
      await _notifyFollowers(
        session,
        exclude: reporter.id,
        kind: NotificationKind.emptyRoomReport,
        title: '${session.courseName}: laporan ruang kosong '
            '(${EmptyRoomReport.confirmationLabel})',
        body: 'Seorang mahasiswa melaporkan ${session.room} kosong. '
            'Status sesi tidak berubah sampai dikonfirmasi dosen/petugas.',
      );
    }
    return saved;
  }

  Future<void> _notifyFollowers(
    Session session, {
    required String exclude,
    required NotificationKind kind,
    required String title,
    required String body,
  }) async {
    final followers = await _follows.followersOf(session.id);
    final ids = followers.valueOrNull ?? const <String>{};
    final now = _clock.now();
    await _notifications.addAll([
      for (final userId in ids)
        if (userId != exclude)
          AppNotification(
            id: _newId('n'),
            recipientId: userId,
            sessionId: session.id,
            kind: kind,
            title: title,
            body: body,
            createdAt: now,
          ),
    ]);
  }
}

class _Change {
  const _Change(this.session, this.historyText, this.notificationText);

  final Session session;
  final String historyText;
  final String notificationText;
}
