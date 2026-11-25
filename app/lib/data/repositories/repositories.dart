import '../../core/result.dart';
import '../models/account.dart';
import '../models/app_notification.dart';
import '../models/empty_room_report.dart';
import '../models/lecturer.dart';
import '../models/session.dart';

/// Repository ports. The UI depends only on these interfaces; the live
/// implementations in api_repositories.dart talk to the Laravel API
/// (../backend). Failures carry the server's message (see ApiFailure).

abstract interface class AuthRepository {
  /// `POST /auth/register`. Role is always mahasiswa; does not sign in.
  Future<Result<Account>> register({
    required String email,
    required String password,
    required String confirmPassword,
  });

  /// `POST /auth/login`; stores the bearer token.
  Future<Result<Account>> login(String email, String password);

  /// `GET /auth/me` when a token is stored. Falls back to the cached account
  /// when the server is unreachable; returns null when signed out.
  Future<Result<Account?>> restore();

  /// Re-reads the account (e.g. after points changed).
  Future<Result<Account>> me();

  /// `POST /auth/logout` (best effort) and forgets the token.
  Future<void> logout();
}

abstract interface class LecturerRepository {
  /// Case-insensitive substring search on the lecturer name, sorted by name.
  /// An empty query returns all lecturers.
  Future<Result<List<Lecturer>>> search(String query);
  Future<Result<Lecturer>> byId(String id);
}

abstract interface class SessionRepository {
  /// Sessions of [lecturerId] on [date], across all prodi, sorted by start.
  Future<Result<List<Session>>> timeline(String lecturerId, DateTime date);

  /// Detail incl. history, myReport and pendingReportCount.
  Future<Result<Session>> byId(String id);

  /// Sessions on [date]; [editableOnly] limits to what the user may edit.
  Future<Result<List<Session>>> onDate(DateTime date, {bool editableOnly});

  /// Followed sessions today for the Beranda card.
  Future<Result<TodaySummary>> today();

  // P05 edits. Each sends the session's `version`; a stale version fails
  // with ApiFailure.isStaleVersion (409).
  Future<Result<Session>> changeTime(
    Session session,
    DateTime start,
    DateTime end,
  );
  Future<Result<Session>> changeRoom(Session session, String room);
  Future<Result<Session>> cancel(Session session, {String? reason});
  Future<Result<Session>> recordAttendance(Session session);

  /// P12: polite message proposing to meet after the class, in its room.
  Future<Result<MessageDraft>> messageDraft(
    String sessionId, {
    String? purpose,
  });
}

abstract interface class FollowRepository {
  /// Followed sessions (sorted by start).
  Future<Result<List<Session>>> followed();

  /// Idempotent.
  Future<Result<void>> follow(String sessionId);

  /// Idempotent.
  Future<Result<void>> unfollow(String sessionId);
}

abstract interface class NotificationRepository {
  /// Emits whenever notifications may have changed (after a local action).
  Stream<void> get changes;

  /// Tell listeners to refresh (e.g. after an edit or report).
  void notifyChanged();

  Future<Result<NotificationPage>> list({bool unreadOnly});
  Future<Result<void>> markRead(String notificationId);
  Future<Result<int>> markAllRead();

  /// Mode uji: report notifications that were just shown on screen.
  Future<Result<void>> markSeen(List<String> ids);
}

abstract interface class ReportRepository {
  /// Student reports the room empty. Repeating returns the existing report.
  Future<Result<EmptyRoomReport>> submit(String sessionId);

  /// Queue for lecturers/officers; [status] null = all.
  Future<Result<List<EmptyRoomReport>>> queue(ReportStatus? status);
  Future<Result<EmptyRoomReport>> confirm(String reportId);
  Future<Result<EmptyRoomReport>> reject(String reportId);
}

/// Demo panel (petugas only, backend RUANGIN_DEMO_MODE=true).
abstract interface class DemoRepository {
  /// Returns how many sessions were recorded.
  Future<Result<int>> attendanceBatch();

  /// Returns how many warnings were sent.
  Future<Result<int>> runEarlyWarnings();

  /// Wipes and re-seeds the backend; every account is signed out.
  Future<Result<String>> reset();
}

/// Mode uji (usability test stopwatch, backend TestModeController).
abstract interface class TestRunRepository {
  Future<Result<TestRun>> start({
    required String participantCode,
    required String task,
    required String method,
    String? targetSessionId,
  });

  Future<Result<TestRun>> finish(
    String id, {
    String? answerRoom,
    String? answerEndTime,
    String? notes,
  });

  Future<Result<TestRunList>> list();
}

class TestRun {
  const TestRun(this.json);

  final Map<String, dynamic> json;

  String get id => '${json['id']}';
  String get participantCode => '${json['participantCode'] ?? ''}';
  String get task => '${json['task'] ?? ''}';
  String get method => '${json['method'] ?? ''}';
  num? get durationSeconds => json['durationSeconds'] as num?;
  bool? get isCorrect => json['isCorrect'] as bool?;
  bool get isFinished => json['finishedAt'] != null;
}

class TestRunList {
  const TestRunList(this.runs, this.summary);

  final List<TestRun> runs;

  /// Per method (`biasa`, `ruangin`): n, avg/median/max duration, correct rate.
  final Map<String, dynamic> summary;
}
