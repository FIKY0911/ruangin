import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';

class LecturerController extends AsyncController<Lecturer> {
  LecturerController(this._repo, this.lecturerId, super.clock);

  final LecturerRepository _repo;
  final String lecturerId;

  @override
  Future<Result<Lecturer>> fetch() => _repo.byId(lecturerId);
}

/// P02: timeline of one lecturer for a selected date (all prodi, by time).
class TimelineController extends AsyncController<List<Session>> {
  TimelineController(this._repo, this.lecturerId, super.clock)
      : _date = dateOnly(clock.now());

  final SessionRepository _repo;
  final String lecturerId;
  DateTime _date;

  DateTime get date => _date;

  @override
  Future<Result<List<Session>>> fetch() => _repo.timeline(lecturerId, _date);

  void selectDate(DateTime date) {
    final d = dateOnly(date);
    if (d == _date) return;
    _date = d;
    resetCache();
    load();
  }
}
