import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/account.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/session_permissions.dart';
import 'follow_controller.dart';

/// State + actions for the session detail screen (P03, P09, P12). The widget
/// only renders these values and forwards taps.
class SessionDetailController extends AsyncController<Session> {
  SessionDetailController({
    required this.sessionId,
    required this.account,
    required this._sessions,
    required this._reports,
    required this._follows,
    required Clock clock,
  }) : super(clock);

  final String sessionId;
  final Account? account;
  final SessionRepository _sessions;
  final ReportRepository _reports;
  final FollowController _follows;
  bool _reporting = false;

  @override
  bool isEmpty(Session value) => false;

  Session? get session => value;

  bool get canEdit => value?.canEdit ?? false;

  bool get canReport {
    final a = account;
    return a != null && canReportEmptyRoom(a);
  }

  EmptyRoomReport? get myReport => value?.myReport;

  int get pendingReports => value?.pendingReportCount ?? 0;

  bool get isReporting => _reporting;

  @override
  Future<Result<Session>> fetch() async {
    final r = await _sessions.byId(sessionId);
    if (r case Success(:final value)) _follows.observe(value);
    return r;
  }

  /// Returns a user-facing message describing the outcome.
  Future<String> reportEmptyRoom() async {
    _reporting = true;
    notifyListeners();
    final result = await _reports.submit(sessionId);
    _reporting = false;
    await load();
    return switch (result) {
      Success() =>
        'Laporan terkirim (${EmptyRoomReport.confirmationLabel}). '
            'Pengikut sesi diberi kabar.',
      Failure(:final failure) => failure.message,
    };
  }

  Future<Result<MessageDraft>> messageDraft(String purpose) =>
      _sessions.messageDraft(sessionId, purpose: purpose);
}
