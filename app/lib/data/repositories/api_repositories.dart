import 'dart:async';

import '../../core/formatters.dart';
import '../../core/result.dart';
import '../models/account.dart';
import '../models/app_config.dart';
import '../models/app_notification.dart';
import '../models/attendance.dart';
import '../models/empty_room_report.dart';
import '../models/json.dart';
import '../models/lecturer.dart';
import '../models/search_results.dart';
import '../models/session.dart';
import '../remote/api_client.dart';
import 'repositories.dart';

/// Live repositories backed by the Laravel API (../backend/README.md).

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<Account>> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) => guard(() async {
    final body = await _api.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return Account.fromJson(dataObject(body));
  });

  @override
  Future<Result<Account>> login(String email, String password) =>
      guard(() async {
        final body = await _api.post(
          '/auth/login',
          body: {
            'email': email,
            'password': password,
            'deviceName': 'ruangin-app',
          },
        ) as Map<String, dynamic>;
        final json = body['account'] as Map<String, dynamic>;
        final account = Account.fromJson(json);
        await _api.tokens.saveToken(body['token'] as String);
        await _api.tokens.saveAccount(json);
        return account;
      });

  @override
  Future<Result<Account?>> restore() async {
    if (_api.tokens.token == null) return const Success(null);
    final result = await me();
    switch (result) {
      case Success(:final value):
        return Success(value);
      case Failure(failure: final ApiFailure f) when f.isNetwork:
        // Offline: open with the last known account; screens show errors.
        final cached = _api.tokens.cachedAccount;
        return Success(cached == null ? null : Account.fromJson(cached));
      case Failure(failure: final ApiFailure f) when f.statusCode == 401:
        await _api.tokens.clear();
        return const Success(null);
      case Failure(:final failure):
        return Failure(failure);
    }
  }

  @override
  Future<Result<Account>> me() => guard(() async {
    final json = dataObject(await _api.get('/auth/me'));
    await _api.tokens.saveAccount(json);
    return Account.fromJson(json);
  });

  @override
  Future<void> logout() async {
    if (_api.tokens.token != null) {
      try {
        await _api.post('/auth/logout');
      } on Object {
        // Best effort: the token is forgotten locally either way.
      }
    }
    await _api.tokens.clear();
  }
}

class ApiLecturerRepository implements LecturerRepository {
  ApiLecturerRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<Lecturer>>> search(String query) => guard(() async {
    final q = query.trim();
    final body = await _api.get(
      '/lecturers',
      query: {'q': q.isEmpty ? null : q},
    );
    return List.unmodifiable(dataList(body).map(Lecturer.fromJson));
  });

  @override
  Future<Result<Lecturer>> byId(String id) => guard(
    () async =>
        Lecturer.fromJson(dataObject(await _api.get('/lecturers/${_seg(id)}'))),
  );

  @override
  Future<Result<LecturerAttendance>> attendance(String lecturerId) => guard(
    () async => LecturerAttendance.fromJson(
      dataObject(await _api.get('/lecturers/${_seg(lecturerId)}/attendance')),
    ),
  );

  @override
  Future<Result<void>> follow(String lecturerId) => guard(
    () => _api.put('/lecturers/${_seg(lecturerId)}/follow'),
    message: 'Gagal mengikuti dosen.',
  );

  @override
  Future<Result<void>> unfollow(String lecturerId) => guard(
    () => _api.delete('/lecturers/${_seg(lecturerId)}/follow'),
    message: 'Gagal berhenti mengikuti dosen.',
  );
}

class ApiSearchRepository implements SearchRepository {
  ApiSearchRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<SearchResults>> search(String query) => guard(() async {
    final q = query.trim();
    if (q.isEmpty) {
      final body = await _api.get('/lecturers');
      return SearchResults(
        query: '',
        lecturers: List.unmodifiable(dataList(body).map(Lecturer.fromJson)),
      );
    }
    final body =
        await _api.get('/search', query: {'q': q}) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String key) =>
        (body[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return SearchResults(
      query: q,
      lecturers: List.unmodifiable(list('lecturers').map(Lecturer.fromJson)),
      sessions: List.unmodifiable(list('sessions').map(Session.fromJson)),
    );
  });
}

class ApiAppConfigRepository implements AppConfigRepository {
  ApiAppConfigRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<AppConfig>> load() => guard(
    () async => AppConfig.fromJson(dataObject(await _api.get('/app-config'))),
  );
}

class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository(this._api, {this.onChanged});

  final ApiClient _api;

  /// Called after a successful edit (followers got notifications).
  final void Function()? onChanged;

  List<Session> _sessions(dynamic body) =>
      List.unmodifiable(dataList(body).map(Session.fromJson));

  @override
  Future<Result<List<Session>>> timeline(String lecturerId, DateTime date) =>
      guard(
        () async => _sessions(
          await _api.get(
            '/lecturers/${_seg(lecturerId)}/timeline',
            query: {'date': isoDate(date)},
          ),
        ),
      );

  @override
  Future<Result<Session>> byId(String id) => guard(
    () async =>
        Session.fromJson(dataObject(await _api.get('/sessions/${_seg(id)}'))),
  );

  @override
  Future<Result<List<Session>>> onDate(
    DateTime date, {
    bool editableOnly = false,
  }) => guard(
    () async => _sessions(
      await _api.get(
        '/sessions',
        query: {'date': isoDate(date), 'editable': editableOnly ? '1' : null},
      ),
    ),
  );

  @override
  Future<Result<TodaySummary>> today() => guard(() async {
    final body = await _api.get('/me/today') as Map<String, dynamic>;
    return TodaySummary(
      sessions: _sessions(body),
      nextSessionId: body['nextSessionId'] as String?,
      unreadCount: (body['unreadCount'] as num?)?.toInt() ?? 0,
      points: (body['points'] as num?)?.toInt() ?? 0,
    );
  });

  Future<Result<Session>> _edit(
    Session s,
    String action,
    Map<String, Object?> fields,
  ) async {
    final result = await guard(() async {
      final body = await _api.post(
        '/sessions/${_seg(s.id)}/$action',
        body: {'version': s.version, ...fields},
      );
      return Session.fromJson(dataObject(body));
    }, message: 'Gagal menyimpan perubahan sesi.');
    if (result.isSuccess) onChanged?.call();
    return result;
  }

  @override
  Future<Result<Session>> changeTime(
    Session session,
    DateTime start,
    DateTime end,
  ) => _edit(session, 'time', {
    'start': toApiDate(start),
    'end': toApiDate(end),
  });

  @override
  Future<Result<Session>> changeRoom(Session session, String room) =>
      _edit(session, 'room', {'room': room.trim()});

  @override
  Future<Result<Session>> cancel(Session session, {String? reason}) => _edit(
    session,
    'cancel',
    {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
  );

  @override
  Future<Result<Session>> recordAttendance(Session session) =>
      _edit(session, 'attendance', const {});

  @override
  Future<Result<MessageDraft>> messageDraft(
    String sessionId, {
    String? purpose,
  }) => guard(() async {
    final p = purpose?.trim();
    final body = await _api.get(
      '/sessions/${_seg(sessionId)}/message-draft',
      query: {'purpose': p == null || p.isEmpty ? null : p},
    );
    return MessageDraft.fromJson(body as Map<String, dynamic>);
  });
}

class ApiFollowRepository implements FollowRepository {
  ApiFollowRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<Session>>> followed() => guard(
    () async => List.unmodifiable(
      dataList(await _api.get('/me/follows')).map(Session.fromJson),
    ),
  );

  @override
  Future<Result<void>> follow(String sessionId) => guard(
    () => _api.put('/sessions/${_seg(sessionId)}/follow'),
    message: 'Gagal mengikuti sesi.',
  );

  @override
  Future<Result<void>> unfollow(String sessionId) => guard(
    () => _api.delete('/sessions/${_seg(sessionId)}/follow'),
    message: 'Gagal berhenti mengikuti sesi.',
  );
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);

  final ApiClient _api;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<Result<NotificationPage>> list({bool unreadOnly = false}) =>
      guard(() async {
        final body = await _api.get(
          '/me/notifications',
          query: {'unread': unreadOnly ? '1' : null},
        ) as Map<String, dynamic>;
        return NotificationPage(
          List.unmodifiable(dataList(body).map(AppNotification.fromJson)),
          (body['unreadCount'] as num?)?.toInt() ?? 0,
          retentionDays: (body['retentionDays'] as num?)?.toInt(),
        );
      });

  @override
  Future<Result<void>> markRead(String notificationId) async {
    final r = await guard(
      () => _api.post('/notifications/${_seg(notificationId)}/read'),
    );
    if (r.isSuccess) notifyChanged();
    return r;
  }

  @override
  Future<Result<int>> markAllRead() async {
    final r = await guard(() async {
      final body = await _api.post('/me/notifications/read-all');
      return ((body as Map<String, dynamic>?)?['updated'] as num?)?.toInt() ??
          0;
    });
    if (r.isSuccess) notifyChanged();
    return r;
  }

  @override
  Future<Result<void>> markSeen(List<String> ids) async {
    if (ids.isEmpty) return const Success(null);
    return guard(() => _api.post('/me/notifications/seen', body: {'ids': ids}));
  }

  void dispose() => _changes.close();
}

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api, {this.onChanged});

  final ApiClient _api;
  final void Function()? onChanged;

  Future<Result<EmptyRoomReport>> _one(
    Future<dynamic> Function() call,
    String message,
  ) async {
    final r = await guard(
      () async => EmptyRoomReport.fromJson(dataObject(await call())),
      message: message,
    );
    if (r.isSuccess) onChanged?.call();
    return r;
  }

  @override
  Future<Result<EmptyRoomReport>> submit(String sessionId) => _one(
    () => _api.post('/sessions/${_seg(sessionId)}/reports'),
    'Gagal mengirim laporan.',
  );

  @override
  Future<Result<List<EmptyRoomReport>>> queue(ReportStatus? status) => guard(
    () async => List.unmodifiable(
      dataList(
        await _api.get('/reports', query: {'status': status?.name ?? 'all'}),
      ).map(EmptyRoomReport.fromJson),
    ),
  );

  @override
  Future<Result<EmptyRoomReport>> confirm(String reportId) => _one(
    () => _api.post('/reports/${_seg(reportId)}/confirm'),
    'Gagal mengonfirmasi laporan.',
  );

  @override
  Future<Result<EmptyRoomReport>> reject(String reportId) => _one(
    () => _api.post('/reports/${_seg(reportId)}/reject'),
    'Gagal menolak laporan.',
  );
}

class ApiDemoRepository implements DemoRepository {
  ApiDemoRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<int>> attendanceBatch() => guard(() async {
    final body =
        await _api.post('/demo/attendance-batch') as Map<String, dynamic>;
    return (body['recorded'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<Result<int>> runEarlyWarnings() => guard(() async {
    final body =
        await _api.post('/demo/early-warnings') as Map<String, dynamic>;
    return (body['sent'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<Result<String>> reset() => guard(() async {
    final body = await _api.post('/demo/reset') as Map<String, dynamic>?;
    return body?['message'] as String? ?? 'Data demo di-reset.';
  });
}

class ApiTestRunRepository implements TestRunRepository {
  ApiTestRunRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<TestRun>> start({
    required String participantCode,
    required String task,
    required String method,
    String? targetSessionId,
  }) => guard(
    () async => TestRun(
      dataObject(
        await _api.post(
          '/test-runs',
          body: {
            'participantCode': participantCode.trim(),
            'task': task.trim(),
            'method': method,
            if (targetSessionId != null && targetSessionId.trim().isNotEmpty)
              'targetSessionId': targetSessionId.trim(),
          },
        ),
      ),
    ),
  );

  @override
  Future<Result<TestRun>> finish(
    String id, {
    String? answerRoom,
    String? answerEndTime,
    String? notes,
  }) => guard(
    () async => TestRun(
      dataObject(
        await _api.post(
          '/test-runs/${_seg(id)}/finish',
          body: {
            if (_filled(answerRoom)) 'answerRoom': answerRoom!.trim(),
            if (_filled(answerEndTime)) 'answerEndTime': answerEndTime!.trim(),
            if (_filled(notes)) 'notes': notes!.trim(),
          },
        ),
      ),
    ),
  );

  @override
  Future<Result<TestRunList>> list() => guard(() async {
    final body = await _api.get('/test-runs') as Map<String, dynamic>;
    return TestRunList(
      List.unmodifiable(dataList(body).map(TestRun.new)),
      (body['summary'] as Map<String, dynamic>?) ?? const {},
    );
  });

  static bool _filled(String? v) => v != null && v.trim().isNotEmpty;
}

String _seg(String id) => Uri.encodeComponent(id);
