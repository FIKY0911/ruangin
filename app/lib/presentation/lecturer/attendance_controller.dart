import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';

/// Where a session stands in the attendance summary.
enum AttendanceMark { tercatat, belumTerkonfirmasi, batal, belumBerlangsung }

/// One week (Senin–Minggu) of a lecturer's sessions, summarised for
/// Profil_Dosen.png and riwayat_dosen.png.
///
/// The API has no semester attendance endpoint, so this is built from the
/// per-day timeline (`GET /lecturers/{id}/timeline?date=`). A session without
/// an attendance record counts as "Belum terkonfirmasi", never as absent
/// (PRD rule); cancelled and upcoming sessions are left out of the rate.
class WeekAttendance {
  WeekAttendance({
    required this.monday,
    required this.sessions,
    required this.now,
  });

  final DateTime monday;

  /// Sorted by start.
  final List<Session> sessions;
  final DateTime now;

  DateTime get sunday => DateTime(monday.year, monday.month, monday.day + 6);

  AttendanceMark markOf(Session s) {
    if (s.isCancelled) return AttendanceMark.batal;
    if (s.attendance != null) return AttendanceMark.tercatat;
    if (s.end.isAfter(now)) return AttendanceMark.belumBerlangsung;
    return AttendanceMark.belumTerkonfirmasi;
  }

  int count(AttendanceMark m) => sessions.where((s) => markOf(s) == m).length;

  int get recorded => count(AttendanceMark.tercatat);
  int get unconfirmed => count(AttendanceMark.belumTerkonfirmasi);

  /// Sessions that count: recorded + finished without a record.
  int get counted => recorded + unconfirmed;

  /// 0..1, or null when no session has finished yet.
  double? get rate => counted == 0 ? null : recorded / counted;
}

class WeekAttendanceController extends AsyncController<WeekAttendance> {
  WeekAttendanceController(this._repo, this.lecturerId, super.clock);

  final SessionRepository _repo;
  final String lecturerId;

  @override
  bool isEmpty(WeekAttendance value) => false;

  @override
  Future<Result<WeekAttendance>> fetch() async {
    final now = clock.now();
    final today = dateOnly(now);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final results = await Future.wait([
      for (var i = 0; i < 7; i++)
        _repo.timeline(
          lecturerId,
          DateTime(monday.year, monday.month, monday.day + i),
        ),
    ]);
    final sessions = <Session>[];
    for (final r in results) {
      switch (r) {
        case Success(:final value):
          sessions.addAll(value);
        case Failure(:final failure):
          return Failure(failure);
      }
    }
    sessions.sort((a, b) => a.start.compareTo(b.start));
    return Success(
      WeekAttendance(monday: monday, sessions: sessions, now: now),
    );
  }
}
