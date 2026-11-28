import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/repositories.dart';

export '../../data/models/attendance.dart' show AttendanceMark;

/// Profil_Dosen.png "Kehadiran semester ini" and riwayat_dosen.png, from
/// `GET /lecturers/{id}/attendance` (active semester, per course). The server
/// applies the PRD rule: a finished session without a record is "Belum
/// terkonfirmasi", never absent; cancelled and upcoming ones are not counted.
class SemesterAttendanceController extends AsyncController<LecturerAttendance> {
  SemesterAttendanceController(this._repo, this.lecturerId, super.clock);

  final LecturerRepository _repo;
  final String lecturerId;

  @override
  bool isEmpty(LecturerAttendance value) => false;

  @override
  Future<Result<LecturerAttendance>> fetch() => _repo.attendance(lecturerId);
}
