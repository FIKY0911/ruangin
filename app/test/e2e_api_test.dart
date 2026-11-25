// End-to-end check of the API repositories against a REAL running backend.
// Skipped unless RUANGIN_E2E_URL is set, e.g.:
//
//   cd backend && php artisan migrate:fresh --seed && php artisan serve
//   cd app && RUANGIN_E2E_URL=http://127.0.0.1:8000/api flutter test test/e2e_api_test.dart
//
// Uses the seeded demo accounts (password ruangin123) and mutates data, so
// reset the backend afterwards (php artisan ruangin:reset-demo --force).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ruangin/core/result.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/models/account.dart';
import 'package:ruangin/data/models/app_notification.dart';
import 'package:ruangin/data/models/empty_room_report.dart';
import 'package:ruangin/data/models/session.dart';
import 'package:ruangin/data/remote/api_client.dart';
import 'package:ruangin/data/repositories/api_repositories.dart';
import 'package:ruangin/domain/auth_service.dart';

final _url = Platform.environment['RUANGIN_E2E_URL'];

class _User {
  _User()
    : api = ApiClient(
        httpClient: http.Client(),
        baseUrl: _url!,
        tokens: TokenStore(InMemoryStore()),
      );

  final ApiClient api;
  late final auth = AuthService(repo: ApiAuthRepository(api));
  late final lecturers = ApiLecturerRepository(api);
  late final sessions = ApiSessionRepository(api);
  late final follows = ApiFollowRepository(api);
  late final notifications = ApiNotificationRepository(api);
  late final reports = ApiReportRepository(api);
  late final demo = ApiDemoRepository(api);
  late final testRuns = ApiTestRunRepository(api);

  static Future<(_User, Account)> login(String email) async {
    final u = _User();
    final a = (await u.auth.login(email, 'ruangin123')).valueOrNull;
    expect(a, isNotNull, reason: 'login $email');
    return (u, a!);
  }
}

T _ok<T>(Result<T> r) => switch (r) {
  Success(:final value) => value,
  Failure(:final failure) => fail('unexpected failure: ${failure.message}'),
};

void main() {
  test(
    'full flow against the real backend',
    () async {
      // --- Auth -------------------------------------------------------------
      final (student, nadia) = await _User.login('nadia@demo.ruangin.id');
      expect(nadia.role, UserRole.mahasiswa);
      final (officer, hendra) = await _User.login('hendra@demo.ruangin.id');
      expect(hendra.role, UserRole.petugas);
      expect(hendra.scopeProdi, isNotEmpty);
      final (lecturer, rina) = await _User.login('rina@demo.ruangin.id');
      expect(rina.lecturerId, isNotNull);

      final wrong = await _User().auth.login(
        'nadia@demo.ruangin.id',
        'salahsalah',
      );
      expect(
        ((wrong as Failure).failure as AuthFailure).code,
        AuthErrorCode.wrongPassword,
      );
      final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@kampus.ac.id';
      final input = RegisterInput(
        email: email,
        password: 'rahasia123',
        confirmPassword: 'rahasia123',
      );
      expect(_ok(await _User().auth.register(input)).role, UserRole.mahasiswa);
      final dup = await _User().auth.register(input);
      expect(
        ((dup as Failure).failure as AuthFailure).code,
        AuthErrorCode.emailTaken,
      );

      // --- P01/P02 ----------------------------------------------------------
      final found = _ok(await student.lecturers.search('RINA'));
      final rinaLecturer = found.firstWhere((l) => l.id == rina.lecturerId);
      expect(
        _ok(await student.lecturers.byId(rinaLecturer.id)).name,
        rinaLecturer.name,
      );
      final timeline = _ok(
        await student.sessions.timeline(rinaLecturer.id, DateTime.now()),
      );
      expect(timeline, isNotEmpty);
      expect(
        timeline.map((s) => s.prodi).toSet().length,
        greaterThan(1),
        reason: 'timeline merges prodi',
      );
      expect(timeline.every((s) => !s.start.isUtc), isTrue);

      // --- Editors see only their sessions ---------------------------------
      final rinaEditable = _ok(
        await lecturer.sessions.onDate(DateTime.now(), editableOnly: true),
      );
      expect(
        rinaEditable.every((s) => s.lecturerId == rina.lecturerId),
        isTrue,
      );
      final hendraEditable = _ok(
        await officer.sessions.onDate(DateTime.now(), editableOnly: true),
      );
      expect(
        hendraEditable.every((s) => hendra.scopeProdi.contains(s.prodi)),
        isTrue,
      );

      // A session in the officer's scope, not cancelled, not taught by Rina.
      final target = hendraEditable.firstWhere(
        (s) => !s.isCancelled && s.lecturerId != rina.lecturerId,
      );

      // --- P04 follow + P05 edit with version + 409 ------------------------
      _ok(await student.follows.follow(target.id));
      _ok(await student.follows.follow(target.id)); // idempotent
      expect(
        _ok(await student.follows.followed()).map((s) => s.id),
        contains(target.id),
      );

      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).subtract(const Duration(minutes: 5));
      final edited = _ok(
        await officer.sessions.changeTime(
          target,
          start,
          start.add(const Duration(minutes: 90)),
        ),
      );
      expect(edited.version, target.version + 1);
      expect(edited.start, start, reason: 'local time round-trips');
      expect(edited.history.last.description, isNotEmpty);

      final stale = await officer.sessions.changeRoom(
        target,
        'Ruang E2E',
      ); // old version
      expect(
        (stale as Failure).failure,
        isA<ApiFailure>().having((f) => f.isStaleVersion, 'stale', isTrue),
      );
      final moved = _ok(await officer.sessions.changeRoom(edited, 'Ruang E2E'));
      expect(moved.room, 'Ruang E2E');

      // Rina may not edit another lecturer's session.
      final forbidden = await lecturer.sessions.changeRoom(moved, 'x');
      expect(
        (forbidden as Failure).failure,
        isA<ApiFailure>().having((f) => f.statusCode, 'status', 403),
      );

      // --- Today card + message draft --------------------------------------
      final today = _ok(await student.sessions.today());
      expect(today.sessions.map((s) => s.id), contains(target.id));
      final draft = _ok(
        await student.sessions.messageDraft(
          target.id,
          purpose: 'konsultasi skripsi',
        ),
      );
      expect(draft.text, contains('konsultasi skripsi'));
      expect(draft.proposedPlace, 'Ruang E2E');

      // --- P09/P10 report -> confirm -> points + notifications -------------
      final report = _ok(await student.reports.submit(target.id));
      expect(report.status, ReportStatus.pending);
      final again = _ok(await student.reports.submit(target.id));
      expect(again.id, report.id);
      final detail = _ok(await student.sessions.byId(target.id));
      expect(detail.myReport?.id, report.id);
      expect(detail.status, isNot(SessionStatus.batal));

      final queue = _ok(await officer.reports.queue(ReportStatus.pending));
      final item = queue.firstWhere((r) => r.id == report.id);
      expect(item.session?.id, target.id);
      expect(item.reporterName, nadia.name);
      final confirmed = _ok(await officer.reports.confirm(report.id));
      expect(confirmed.status, ReportStatus.confirmed);
      expect(
        _ok(await student.sessions.byId(target.id)).status,
        SessionStatus.batal,
      );
      expect(
        _ok(await student.auth.refreshAccount()).points,
        nadia.points + 10,
      );

      final notes = _ok(await student.notifications.list());
      final kinds = notes.items.map((n) => n.kind).toSet();
      expect(
        kinds,
        containsAll([
          NotificationKind.sessionChanged,
          NotificationKind.reportResolved,
        ]),
      );
      _ok(await student.notifications.markSeen([notes.items.first.id]));
      _ok(await student.notifications.markRead(notes.items.first.id));
      _ok(await student.notifications.markAllRead());
      expect(
        _ok(await student.notifications.list(unreadOnly: true)).unreadCount,
        0,
      );

      final studentQueue = await student.reports.queue(null);
      expect(
        (studentQueue as Failure).failure,
        isA<ApiFailure>().having((f) => f.statusCode, 'status', 403),
      );

      // --- Demo panel + mode uji -------------------------------------------
      expect(
        _ok(await officer.demo.attendanceBatch()),
        greaterThanOrEqualTo(0),
      );
      expect(
        _ok(await officer.demo.runEarlyWarnings()),
        greaterThanOrEqualTo(0),
      );
      final notOfficer = await student.demo.runEarlyWarnings();
      expect(
        (notOfficer as Failure).failure,
        isA<ApiFailure>().having((f) => f.statusCode, 'status', 403),
      );
      final run = _ok(
        await student.testRuns.start(
          participantCode: 'P01',
          task: 'cari ruang',
          method: 'ruangin',
          targetSessionId: target.id,
        ),
      );
      final done = _ok(
        await student.testRuns.finish(
          run.id,
          answerRoom: 'ruang e2e',
          answerEndTime: '00.00',
        ),
      );
      expect(done.isFinished, isTrue);
      expect(
        _ok(await officer.testRuns.list()).summary.keys,
        containsAll(['biasa', 'ruangin']),
      );

      // --- Logout revokes the token ----------------------------------------
      await student.auth.logout();
      expect(await student.auth.restoreSession(), isNull);
    },
    skip: _url == null
        ? 'set RUANGIN_E2E_URL to run against a live backend'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
