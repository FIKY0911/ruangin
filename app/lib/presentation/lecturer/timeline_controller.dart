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
  bool _following = false;

  /// A follow/unfollow request is in flight.
  bool get isTogglingFollow => _following;

  @override
  Future<Result<Lecturer>> fetch() => _repo.byId(lecturerId);

  /// "Ikuti" / "Diikuti" on Profil_Dosen.png. Returns a user-facing message.
  Future<String> toggleFollow() async {
    final current = value;
    if (current == null || _following) return '';
    _following = true;
    notifyListeners();
    final follow = !current.isFollowed;
    final result = follow
        ? await _repo.follow(current.id)
        : await _repo.unfollow(current.id);
    _following = false;
    if (isDisposed) return '';
    switch (result) {
      case Success():
        // Show the new state right away, then confirm with the server.
        replaceValue(current.copyWith(isFollowed: follow));
        await load();
        return follow
            ? 'Mengikuti ${current.name}. Anda akan dapat kabar untuk semua '
                  'sesinya.'
            : 'Berhenti mengikuti ${current.name}.';
      case Failure(:final failure):
        notifyListeners();
        return failure.message;
    }
  }
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
