import '../../core/result.dart';
import '../models/account.dart';
import '../models/app_notification.dart';
import '../models/empty_room_report.dart';
import '../models/lecturer.dart';
import '../models/password_hash.dart';
import '../models/session.dart';

/// Repository ports. The UI depends only on these interfaces; M1 ships local
/// (synthetic fixture + shared_preferences) implementations, and a backend
/// implementation can be swapped in later without touching presentation code.

abstract interface class AuthRepository {
  /// Looks up seeded demo accounts and locally registered accounts.
  /// [email] must already be normalised.
  Future<Result<AuthRecord?>> findByEmail(String email);

  /// Persists a newly registered account with its password hash.
  Future<Result<void>> create(AuthRecord record);

  /// Persisted session (survives app restarts).
  Future<Result<void>> saveSession(String accountId);
  Future<Result<Account?>> currentAccount();
  Future<void> clearSession();
}

abstract interface class LecturerRepository {
  /// Case-insensitive substring search on the lecturer name.
  /// An empty query returns all lecturers.
  Future<Result<List<Lecturer>>> search(String query);
  Future<Result<Lecturer>> byId(String id);
}

abstract interface class SessionRepository {
  /// Sessions of [lecturerId] on [date], across all prodi, sorted by start.
  Future<Result<List<Session>>> timeline(String lecturerId, DateTime date);
  Future<Result<Session>> byId(String id);
  Future<Result<List<Session>>> byIds(Set<String> ids);

  /// All sessions on [date] (used for the "Kelola" list of editors).
  Future<Result<List<Session>>> onDate(DateTime date);

  /// Persists a changed session.
  Future<Result<Session>> save(Session session);
}

abstract interface class FollowRepository {
  Future<Result<Set<String>>> followedSessionIds(String userId);

  /// Idempotent: following twice keeps a single follow.
  Future<Result<void>> follow(String userId, String sessionId);

  /// Idempotent: unfollowing a session that is not followed is a no-op.
  Future<Result<void>> unfollow(String userId, String sessionId);
  Future<Result<Set<String>>> followersOf(String sessionId);
}

abstract interface class NotificationRepository {
  /// Emits whenever notifications change.
  Stream<void> get changes;
  Future<Result<List<AppNotification>>> forUser(String userId);
  Future<Result<void>> addAll(List<AppNotification> notifications);
  Future<Result<void>> markRead(String notificationId);
}

abstract interface class ReportRepository {
  Future<Result<List<EmptyRoomReport>>> forSession(String sessionId);
  Future<Result<EmptyRoomReport>> add(EmptyRoomReport report);
}
