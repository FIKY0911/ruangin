import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/account.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/session_permissions.dart';
import '../../domain/session_service.dart';

@immutable
class SessionDetail {
  const SessionDetail(this.session, this.lecturer, this.reports);

  final Session session;
  final Lecturer lecturer;
  final List<EmptyRoomReport> reports;
}

/// State + actions for the session detail screen (P03, P09). The widget only
/// renders these values and forwards taps.
class SessionDetailController extends AsyncController<SessionDetail> {
  SessionDetailController({
    required this.sessionId,
    required this.account,
    required this._sessions,
    required this._lecturers,
    required this._reports,
    required this._service,
    required Clock clock,
  }) : super(clock);

  final String sessionId;
  final Account? account;
  final SessionRepository _sessions;
  final LecturerRepository _lecturers;
  final ReportRepository _reports;
  final SessionService _service;
  bool _reporting = false;

  @override
  bool isEmpty(SessionDetail value) => false;

  bool get canEdit {
    final a = account, s = value?.session;
    return a != null && s != null && canEditSession(a, s);
  }

  bool get canReport {
    final a = account;
    return a != null && canReportEmptyRoom(a);
  }

  bool get hasReported =>
      value?.reports.any((r) => r.reporterId == account?.id) ?? false;

  bool get isReporting => _reporting;

  @override
  Future<Result<SessionDetail>> fetch() async {
    final s = await _sessions.byId(sessionId);
    if (s case Failure(:final failure)) return Failure(failure);
    final session = s.valueOrNull!;
    final l = await _lecturers.byId(session.lecturerId);
    if (l case Failure(:final failure)) return Failure(failure);
    final r = await _reports.forSession(sessionId);
    if (r case Failure(:final failure)) return Failure(failure);
    return Success(SessionDetail(session, l.valueOrNull!, r.valueOrNull!));
  }

  /// Returns a user-facing message describing the outcome.
  Future<String> reportEmptyRoom() async {
    final a = account;
    if (a == null) return 'Silakan masuk terlebih dahulu.';
    _reporting = true;
    notifyListeners();
    final result = await _service.reportEmptyRoom(a, sessionId);
    _reporting = false;
    await load();
    return switch (result) {
      Success() => 'Laporan terkirim (${EmptyRoomReport.confirmationLabel}).',
      Failure(:final failure) => failure.message,
    };
  }
}
