import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/repositories/repositories.dart';

/// P09 confirmation queue for lecturers/officers (`GET /reports`). Confirming
/// cancels the session and awards points; rejecting leaves it unchanged.
class ReportQueueController extends AsyncController<List<EmptyRoomReport>> {
  ReportQueueController(this._repo, super.clock, {this.sessionId});

  final ReportRepository _repo;

  /// When set, only reports on this session are shown.
  final String? sessionId;
  ReportStatus? _status = ReportStatus.pending;
  final Set<String> _busy = {};

  /// null = all statuses.
  ReportStatus? get status => _status;
  bool isBusy(String reportId) => _busy.contains(reportId);

  void setStatus(ReportStatus? status) {
    if (status == _status) return;
    _status = status;
    resetCache();
    load();
  }

  @override
  Future<Result<List<EmptyRoomReport>>> fetch() async {
    final r = await _repo.queue(_status);
    final id = sessionId;
    if (id == null) return r;
    return switch (r) {
      Success(:final value) => Success(
        List.unmodifiable(value.where((x) => x.sessionId == id)),
      ),
      Failure() => r,
    };
  }

  Future<String> confirm(EmptyRoomReport report) => _resolve(
    report,
    () => _repo.confirm(report.id),
    (r) =>
        'Laporan dikonfirmasi. Sesi ${r.session?.courseName ?? ''} '
        'berstatus Batal dan pelapor mendapat poin.',
  );

  Future<String> reject(EmptyRoomReport report) => _resolve(
    report,
    () => _repo.reject(report.id),
    (_) => 'Laporan ditolak. Jadwal tidak berubah.',
  );

  Future<String> _resolve(
    EmptyRoomReport report,
    Future<Result<EmptyRoomReport>> Function() action,
    String Function(EmptyRoomReport) success,
  ) async {
    _busy.add(report.id);
    notifyListeners();
    final r = await action();
    _busy.remove(report.id);
    await load();
    return switch (r) {
      Success(:final value) => success(value),
      Failure(:final failure) => failure.message,
    };
  }
}
