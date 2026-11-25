import 'package:flutter/foundation.dart';

import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../data/models/account.dart';
import '../../data/models/session.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/repositories.dart';

/// Outcome of a save, so the screen can offer "Muat ulang" on a 409.
@immutable
class EditOutcome {
  const EditOutcome(this.message, {this.ok = false, this.stale = false});

  final String message;
  final bool ok;

  /// The server rejected the edit with 409 staleVersion.
  final bool stale;
}

/// State + actions for editing a session (P05). Holds the draft values; the
/// widget only renders them and forwards input. Each save sends the session's
/// `version`; the server answers 409 if someone else changed it first.
class EditSessionController extends ChangeNotifier {
  EditSessionController({
    required Session session,
    required this.actor,
    required this._repo,
  }) : _session = session,
       _draftRoom = session.room,
       _draftStart = session.start,
       _draftEnd = session.end;

  final Account actor;
  final SessionRepository _repo;
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
    _session.start.year,
    _session.start.month,
    _session.start.day,
    hour,
    minute,
  );

  Future<EditOutcome> saveRoom() {
    final room = _draftRoom.trim();
    if (room.isEmpty) return _local('Ruang tidak boleh kosong.');
    if (room == _session.room) return _local('Ruang tidak berubah.');
    return _run(() => _repo.changeRoom(_session, room));
  }

  Future<EditOutcome> saveTime() {
    if (!_draftEnd.isAfter(_draftStart)) {
      return _local('Jam selesai harus setelah jam mulai.');
    }
    if (_draftStart == _session.start && _draftEnd == _session.end) {
      return _local('Jam tidak berubah.');
    }
    return _run(() => _repo.changeTime(_session, _draftStart, _draftEnd));
  }

  Future<EditOutcome> cancelSession({String? reason}) =>
      _run(() => _repo.cancel(_session, reason: reason));

  Future<EditOutcome> recordAttendance() =>
      _run(() => _repo.recordAttendance(_session));

  /// After a 409: fetch the latest version and reset the drafts.
  Future<String> reload() async {
    _busy = true;
    notifyListeners();
    final r = await _repo.byId(_session.id);
    _busy = false;
    if (r case Success(:final value)) _apply(value);
    notifyListeners();
    return switch (r) {
      Success() => 'Data sesi terbaru dimuat. Periksa lalu ubah lagi.',
      Failure(:final failure) => failure.message,
    };
  }

  Future<EditOutcome> _local(String message) async => EditOutcome(message);

  void _apply(Session value) {
    _session = value;
    _draftRoom = value.room;
    _draftStart = value.start;
    _draftEnd = value.end;
  }

  Future<EditOutcome> _run(Future<Result<Session>> Function() action) async {
    _busy = true;
    notifyListeners();
    final result = await action();
    _busy = false;
    if (result case Success(:final value)) _apply(value);
    notifyListeners();
    return switch (result) {
      Success() => const EditOutcome(
        'Perubahan disimpan. Pengikut sesi menerima notifikasi.',
        ok: true,
      ),
      Failure(failure: final ApiFailure f) when f.isStaleVersion => EditOutcome(
        f.message,
        stale: true,
      ),
      Failure(:final failure) => EditOutcome(failure.message),
    };
  }
}
