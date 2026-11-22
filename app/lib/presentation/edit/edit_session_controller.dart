import 'package:flutter/foundation.dart';

import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../data/models/account.dart';
import '../../data/models/session.dart';
import '../../domain/session_service.dart';

/// State + actions for editing a session (P05). Holds the draft values; the
/// widget only renders them and forwards input.
class EditSessionController extends ChangeNotifier {
  EditSessionController({
    required Session session,
    required this.actor,
    required this._service,
  })  : _session = session,
        _draftRoom = session.room,
        _draftStart = session.start,
        _draftEnd = session.end;

  final Account actor;
  final SessionService _service;
  Session _session;
  String _draftRoom;
  DateTime _draftStart;
  DateTime _draftEnd;
  bool _busy = false;

  Session get session => _session;
  String get draftRoom => _draftRoom;
  DateTime get draftStart => _draftStart;
  DateTime get draftEnd => _draftEnd;
  bool get busy => _busy;

  bool get isEditable => !_session.isCancelled && !_busy;
  bool get canRecordAttendance => isEditable && _session.attendance == null;

  String get roomChangeSummary => '${_session.room} → ${_draftRoom.trim()}';
  String get timeChangeSummary =>
      '${formatTimeRange(_session.start, _session.end)} → '
      '${formatTimeRange(_draftStart, _draftEnd)}';
  String get cancelSummary =>
      'Sesi ${_session.courseName} ${formatTimeRange(_session.start, _session.end)} '
      'akan berstatus "Batal".';

  void setRoom(String value) => _draftRoom = value;

  void setStart(int hour, int minute) {
    _draftStart = _onSessionDay(hour, minute);
    notifyListeners();
  }

  void setEnd(int hour, int minute) {
    _draftEnd = _onSessionDay(hour, minute);
    notifyListeners();
  }

  DateTime _onSessionDay(int hour, int minute) => DateTime(
      _session.start.year, _session.start.month, _session.start.day, hour, minute);

  Future<String> saveRoom() =>
      _run(() => _service.changeRoom(actor, _session.id, _draftRoom));

  Future<String> saveTime() => _run(
      () => _service.changeTime(actor, _session.id, _draftStart, _draftEnd));

  Future<String> cancelSession() => _run(() => _service.cancel(actor, _session.id));

  Future<String> recordAttendance() =>
      _run(() => _service.recordAttendance(actor, _session.id));

  /// Runs an edit; returns a user-facing message.
  Future<String> _run(Future<Result<Session>> Function() action) async {
    _busy = true;
    notifyListeners();
    final result = await action();
    _busy = false;
    if (result case Success(:final value)) {
      _session = value;
      _draftRoom = value.room;
      _draftStart = value.start;
      _draftEnd = value.end;
    }
    notifyListeners();
    return switch (result) {
      Success() => 'Perubahan disimpan.',
      Failure(:final failure) => failure.message,
    };
  }
}
