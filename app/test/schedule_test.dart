import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/core/result.dart';
import 'package:ruangin/core/view_state.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/models/app_notification.dart';
import 'package:ruangin/data/models/attendance.dart';
import 'package:ruangin/data/models/empty_room_report.dart';
import 'package:ruangin/data/models/search_results.dart';
import 'package:ruangin/data/models/session.dart';
import 'package:ruangin/data/remote/api_client.dart';
import 'package:ruangin/data/repositories/api_repositories.dart';
import 'package:ruangin/domain/auth_service.dart';
import 'package:ruangin/presentation/auth/auth_controller.dart';
import 'package:ruangin/presentation/edit/edit_session_controller.dart';
import 'package:ruangin/presentation/lecturer/timeline_controller.dart';
import 'package:ruangin/presentation/reports/report_queue_controller.dart';
import 'package:ruangin/presentation/search/search_controller.dart';
import 'package:ruangin/presentation/session/follow_controller.dart';

import 'fake_backend.dart';

/// One signed-in user talking to the fake backend through the real
/// ApiClient + Api*Repository classes.
class Env {
  Env._(this.backend, this.store, this.api);

  static Future<Env> signedIn(String userId, {FakeBackend? backend}) async {
    final b = backend ?? FakeBackend();
    final store = InMemoryStore();
    await b.signInAs(userId, store);
    return Env._(b, store, b.api(store));
  }

  final FakeBackend backend;
  final InMemoryStore store;
  final ApiClient api;
  final clock = FixedClock(testNow);

  late final lecturers = ApiLecturerRepository(api);
  late final search = ApiSearchRepository(api);
  late final sessions = ApiSessionRepository(api);
  late final follows = ApiFollowRepository(api);
  late final notifications = ApiNotificationRepository(api);
  late final reports = ApiReportRepository(api);

  Future<AuthController> auth() async {
    final c = AuthController(AuthService(repo: ApiAuthRepository(api)));
    await c.restore();
    return c;
  }
}

void main() {
  group('P01 search', () {
    test('partial, case-insensitive; empty query lists all', () async {
      final env = await Env.signedIn('u-nadia');
      final c = SearchResultsController(
        env.search,
        env.clock,
        debounce: Duration.zero,
      );
      await c.load();
      expect((c.state as ViewData<SearchResults>).data.lecturers, hasLength(2));
      expect(env.backend.requests.last.url.path, '/api/lecturers');

      c.onQueryChanged('  BUDI ');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final data = (c.state as ViewData<SearchResults>).data;
      expect(data.lecturers.single.name, 'Dr. Budi Santoso');
      expect(data.sessions, isEmpty);
      expect(env.backend.requests.last.url.path, '/api/search');
      expect(env.backend.requests.last.url.queryParameters['q'], 'BUDI');

      c.onQueryChanged('zaydan');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.state, isA<ViewEmpty>());
    });

    test('finds sessions by course or room in the coming week', () async {
      final env = await Env.signedIn('u-nadia');
      final r = (await env.search.search('mobile')).valueOrNull!;
      expect(r.lecturers, isEmpty);
      expect(r.sessions.map((s) => s.id), ['s-pm-today', 's-pm-tomorrow']);
      expect(r.sessions.first.lecturer!.name, 'Dr. Rina Kusuma, M.Kom.');
      expect(r.sessions.first.place, 'Gedung D · Ruang 402');

      final byRoom = (await env.search.search('lab')).valueOrNull!;
      expect(byRoom.sessions.single.id, 's-basis-today');
    });

    test(
      'server down: error state, then stale data after a good load',
      () async {
        final env = await Env.signedIn('u-nadia');
        final c = SearchResultsController(env.search, env.clock);
        env.backend.offline = true;
        await c.load();
        expect(c.state, isA<ViewError>());
        env.backend.offline = false;
        await c.load();
        env.backend.offline = true;
        await c.load();
        expect((c.state as ViewData).isStale, isTrue);
      },
    );
  });

  group('follow lecturer', () {
    test(
      'follow/unfollow, isFollowed, and notifications for all sessions',
      () async {
        final backend = FakeBackend();
        final nadia = await Env.signedIn('u-nadia', backend: backend);
        expect(
          (await nadia.lecturers.byId('l-budi')).valueOrNull!.isFollowed,
          isFalse,
        );
        expect((await nadia.lecturers.follow('l-budi')).isSuccess, isTrue);
        expect((await nadia.lecturers.follow('l-budi')).isSuccess, isTrue);
        expect(
          (await nadia.lecturers.byId('l-budi')).valueOrNull!.isFollowed,
          isTrue,
        );

        // Petugas (scope Teknik Informatika) moves Budi's session.
        final hendra = await Env.signedIn('u-hendra', backend: backend);
        final s = (await hendra.sessions.byId('s-basis-today')).valueOrNull!;
        expect(
          (await hendra.sessions.changeRoom(s, 'Ruang 306')).isSuccess,
          isTrue,
        );
        final page = (await nadia.notifications.list()).valueOrNull!;
        expect(page.items.single.sessionId, 's-basis-today');
        expect(page.retentionDays, 30);

        // "Hari ini" includes the followed lecturer's session.
        final today = (await nadia.sessions.today()).valueOrNull!;
        expect(today.sessions.map((s) => s.id), ['s-basis-today']);
        expect(today.sessions.single.place, 'Gedung C · Ruang 306');

        expect((await nadia.lecturers.unfollow('l-budi')).isSuccess, isTrue);
        expect(
          (await nadia.lecturers.byId('l-budi')).valueOrNull!.isFollowed,
          isFalse,
        );
        final missing = await nadia.lecturers.follow('l-tidak-ada');
        expect((missing as Failure).failure.message, 'Data tidak ditemukan.');
      },
    );
  });

  group('semester attendance', () {
    test('parses summary, courses and marks', () async {
      final env = await Env.signedIn('u-nadia');
      final a = (await env.lecturers.attendance('l-rina')).valueOrNull!;
      expect(a.semester.name, 'Semester Ganjil 2026/2027');
      expect(a.semester.startsOn, DateTime(2026, 9, 14));
      expect(a.semester.endsOn, DateTime(2026, 12, 20));
      // testNow 08:15: 07.30–10.00 is running, the others are later.
      expect(a.summary.total, 3);
      expect(a.summary.belumBerlangsung, 3);
      expect(a.summary.counted, 0);
      expect(a.summary.rate, isNull);
      expect(a.courses.map((c) => c.courseName), [
        'Analisis Sistem',
        'Pemrograman Mobile',
      ]);
      final mobile = a.courses[1];
      expect(mobile.meetings.map((m) => m.number), [1, 2]);
      expect(mobile.meetings.first.building, 'Gedung D');
      expect(mobile.meetings.first.mark, AttendanceMark.belumBerlangsung);
    });

    test('mark parsing never invents a value', () {
      expect(AttendanceMark.parse('tercatat'), AttendanceMark.tercatat);
      expect(AttendanceMark.parse('batal'), AttendanceMark.batal);
      expect(
        AttendanceMark.parse('tidakHadir'),
        AttendanceMark.belumTerkonfirmasi,
      );
    });
  });

  group('app config', () {
    test('reads simulatedData and retention', () async {
      final backend = FakeBackend()..retentionDays = null;
      final env = await Env.signedIn('u-nadia', backend: backend);
      final c = (await ApiAppConfigRepository(env.api).load()).valueOrNull!;
      expect(c.simulatedData, isTrue);
      expect(c.notificationRetentionDays, isNull);
    });
  });

  group('P02 timeline', () {
    test('sends the selected date and lists sessions across prodi', () async {
      final env = await Env.signedIn('u-nadia');
      final c = TimelineController(env.sessions, 'l-rina', env.clock);
      await c.load();
      final list = (c.state as ViewData<List<Session>>).data;
      expect(list.map((s) => s.id), ['s-pm-today', 's-si-today']);
      expect(list.map((s) => s.prodi).toSet(), hasLength(2));
      expect(
        env.backend.requests.last.url.queryParameters['date'],
        '2026-11-23',
      );

      c.selectDate(DateTime(2026, 11, 24));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        env.backend.requests.last.url.queryParameters['date'],
        '2026-11-24',
      );
    });
  });

  group('P04 follow', () {
    test(
      'follow/unfollow are idempotent and reflected in /me/follows',
      () async {
        final env = await Env.signedIn('u-nadia');
        final auth = await env.auth();
        final c = FollowController(env.follows, auth);
        await c.reload();
        expect(c.followed, isEmpty);

        await c.setFollowing('s-pm-today', true);
        await c.setFollowing('s-pm-today', true);
        expect(c.followed, {'s-pm-today'});
        expect(
          (await env.follows.followed()).valueOrNull!.single.id,
          's-pm-today',
        );
        expect(
          env.backend.calls('PUT', '/sessions/s-pm-today/follow'),
          hasLength(2),
        );

        expect(await c.toggle('s-pm-today'), 'Berhenti mengikuti sesi.');
        expect(c.followed, isEmpty);
        expect(
          env.backend.calls('DELETE', '/sessions/s-pm-today/follow'),
          hasLength(1),
        );
      },
    );

    test('today card lists followed sessions with the next one', () async {
      final env = await Env.signedIn('u-nadia');
      await env.follows.follow('s-pm-today');
      await env.follows.follow('s-si-today');
      await env.follows.follow('s-pm-tomorrow');
      final today = (await env.sessions.today()).valueOrNull!;
      expect(today.sessions.map((s) => s.id), ['s-pm-today', 's-si-today']);
      expect(today.nextSessionId, 's-pm-today');
      expect(today.points, 10);
    });
  });

  group('P05 edit', () {
    test('sends version; follower is notified; history grows', () async {
      final backend = FakeBackend();
      final student = await Env.signedIn('u-nadia', backend: backend);
      await student.follows.follow('s-pm-today');
      final env = await Env.signedIn('u-rina', backend: backend);

      final s = (await env.sessions.byId('s-pm-today')).valueOrNull!;
      expect(s.canEdit, isTrue);
      final c = EditSessionController(
        session: s,
        actor: (await env.auth()).account!,
        repo: env.sessions,
      );
      c.setRoom('Ruang 306');
      final out = await c.saveRoom();
      expect(out.ok, isTrue);
      expect(c.session.room, 'Ruang 306');
      expect(c.session.version, s.version + 1);
      expect(
        backend.calls('POST', '/sessions/s-pm-today/room').single.body,
        contains('"version":1'),
      );
      expect(c.session.history.single.description, contains('Ruang 306'));

      final page = (await student.notifications.list()).valueOrNull!;
      expect(page.unreadCount, 1);
      expect(page.items.single.kind, NotificationKind.sessionChanged);
    });

    test(
      '409 staleVersion is surfaced and reload fetches the new version',
      () async {
        final env = await Env.signedIn('u-hendra');
        final s = (await env.sessions.byId('s-basis-today')).valueOrNull!;
        final c = EditSessionController(
          session: s,
          actor: (await env.auth()).account!,
          repo: env.sessions,
        );
        env.backend.sessions['s-basis-today']!['version'] = 5; // someone else

        c.setRoom('Lab 3');
        final out = await c.saveRoom();
        expect(out.stale, isTrue);
        expect(out.message, contains('Muat ulang'));
        await c.reload();
        expect(c.session.version, 5);
        expect(
          (await c.saveRoom()).message,
          'Ruang tidak berubah.',
          reason: 'drafts reset to the latest data',
        );
        c.setRoom('Lab 3');
        expect((await c.saveRoom()).ok, isTrue);
      },
    );

    test(
      'local validation avoids round trips; forbidden shows server text',
      () async {
        final env = await Env.signedIn('u-rina');
        final s = (await env.sessions.byId('s-basis-today')).valueOrNull!;
        expect(s.canEdit, isFalse);
        final c = EditSessionController(
          session: s,
          actor: (await env.auth()).account!,
          repo: env.sessions,
        );
        final before = env.backend.requests.length;
        c.setEnd(7, 0);
        expect(
          (await c.saveTime()).message,
          'Jam selesai harus setelah jam mulai.',
        );
        expect(env.backend.requests.length, before, reason: 'no request sent');
        expect(
          (await c.cancelSession()).message,
          'Anda tidak berhak mengubah sesi ini.',
        );
      },
    );
  });

  group('P09/P10 reports', () {
    test(
      'student reports once; officer confirms; points + notifications',
      () async {
        final backend = FakeBackend();
        final student = await Env.signedIn('u-nadia', backend: backend);
        final first = (await student.reports.submit('s-basis-today'))
            .valueOrNull!;
        final again = (await student.reports.submit('s-basis-today'))
            .valueOrNull!;
        expect(again.id, first.id, reason: '1 report per user per session');
        final detail = (await student.sessions.byId('s-basis-today'))
            .valueOrNull!;
        expect(detail.myReport!.status, ReportStatus.pending);
        expect(
          detail.status,
          SessionStatus.belumTerkonfirmasi,
          reason: 'a report never changes the status',
        );

        final officer = await Env.signedIn('u-hendra', backend: backend);
        final queue = ReportQueueController(officer.reports, officer.clock);
        await queue.load();
        final pending = (queue.state as ViewData<List<EmptyRoomReport>>).data;
        expect(pending.single.reporterName, 'Nadia Putri');
        expect(pending.single.session!.courseName, 'Basis Data');

        final msg = await queue.confirm(pending.single);
        expect(msg, contains('Batal'));
        expect(
          queue.state,
          isA<ViewEmpty>(),
          reason: 'pending queue now empty',
        );
        queue.setStatus(ReportStatus.confirmed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect((queue.state as ViewData).data, hasLength(1));

        final after = (await student.sessions.byId('s-basis-today'))
            .valueOrNull!;
        expect(after.status, SessionStatus.batal);
        expect(after.myReport!.pointsAwarded, 10);
        final note =
            (await student.notifications.list()).valueOrNull!.items.first;
        expect(note.kind, NotificationKind.reportResolved);
        expect((await student.auth()).account!.points, 20);
      },
    );

    test('queue is filtered by session and forbidden for students', () async {
      final backend = FakeBackend();
      final student = await Env.signedIn('u-nadia', backend: backend);
      await student.reports.submit('s-basis-today');
      await student.reports.submit('s-pm-today');
      final r = await student.reports.queue(ReportStatus.pending);
      expect((r as Failure).failure.message, contains('tidak berhak'));

      final officer = await Env.signedIn('u-hendra', backend: backend);
      final q = ReportQueueController(
        officer.reports,
        officer.clock,
        sessionId: 's-pm-today',
      );
      await q.load();
      final data = (q.state as ViewData<List<EmptyRoomReport>>).data;
      expect(data.single.sessionId, 's-pm-today');
      expect(await q.reject(data.single), contains('ditolak'));
    });
  });

  group('P06 notifications', () {
    test('read, read-all and seen hit the API and emit changes', () async {
      final env = await Env.signedIn('u-nadia');
      env.backend
        ..notify('u-nadia', 's-pm-today', 'earlyWarning', 'Peringatan dini')
        ..notify('u-nadia', 's-pm-today', 'sessionChanged', 'Pindah ruang');
      var changes = 0;
      env.notifications.changes.listen((_) => changes++);

      final page = (await env.notifications.list()).valueOrNull!;
      expect(page.items.first.title, 'Pindah ruang', reason: 'newest first');
      expect(page.items.last.kind, NotificationKind.earlyWarning);
      await env.notifications.markRead(page.items.first.id);
      expect(
        (await env.notifications.list(unreadOnly: true))
            .valueOrNull!
            .unreadCount,
        1,
      );
      expect((await env.notifications.markAllRead()).valueOrNull, 1);
      await env.notifications.markSeen([page.items.first.id]);
      expect(env.backend.seen, {page.items.first.id});
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
    });
  });

  test('P12 message draft and 422 on cancelled sessions', () async {
    final env = await Env.signedIn('u-nadia');
    final d = (await env.sessions.messageDraft(
      's-pm-today',
      purpose: 'meminta arahan lomba',
    )).valueOrNull!;
    expect(d.text, contains('meminta arahan lomba'));
    expect(d.proposedPlace, 'Ruang 402');
    expect(
      env.backend.requests.last.url.queryParameters['purpose'],
      'meminta arahan lomba',
    );

    env.backend.sessions['s-pm-today']!['isCancelled'] = true;
    final r = await env.sessions.messageDraft('s-pm-today');
    expect((r as Failure).failure.message, contains('dibatalkan'));
  });
}
