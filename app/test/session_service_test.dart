import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/models/app_notification.dart';
import 'package:ruangin/data/models/session.dart';

import 'helpers.dart';
import 'package:ruangin/domain/session_status.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());

  Future<Session> load(String id) async => (await env.sessions.byId(id)).valueOrNull!;

  group('status rule', () {
    test('no attendance record => Belum terkonfirmasi, never Batal', () async {
      final s = await load('s-basdat-today');
      expect(s.attendance, isNull);
      expect(s.status, SessionStatus.belumTerkonfirmasi);
      expect(s.statusLabel, 'Belum terkonfirmasi');
    });

    test('attendance => Tercatat · Sinkron absensi HH.MM', () async {
      expect((await load('s-mobile-today')).statusLabel, 'Tercatat · Sinkron absensi 07.34');
    });
  });

  group('changeRoom (P05)', () {
    test('officer moves 306 -> 402, adds history, keeps status, notifies followers', () async {
      await env.follows.follow('a-nadia', 's-mobile-today');
      await env.follows.follow('a-hendra', 's-mobile-today');
      final before = await load('s-mobile-today');

      final result = await env.service
          .changeRoom(env.account('a-hendra'), 's-mobile-today', 'Ruang 402');
      final after = result.valueOrNull!;

      expect(after.room, 'Ruang 402');
      expect(after.history, hasLength(before.history.length + 1));
      expect(after.history.last.description, contains('Ruang 306 → Ruang 402'));
      expect(after.status, before.status);
      expect(after.updatedAt, env.clock.now());
      expect((await load('s-mobile-today')).room, 'Ruang 402', reason: 'persisted');

      final nadia = (await env.notifications.forUser('a-nadia')).valueOrNull!;
      expect(nadia.single.sessionId, 's-mobile-today');
      expect(nadia.single.kind, NotificationKind.sessionChanged);
      expect((await env.notifications.forUser('a-hendra')).valueOrNull, isEmpty,
          reason: 'actor is not notified about own change');
    });

    test('editing an unconfirmed session keeps it Belum terkonfirmasi', () async {
      final r = await env.service
          .changeRoom(env.account('a-rina'), 's-basdat-today', 'Ruang 305');
      expect(r.valueOrNull!.statusLabel, 'Belum terkonfirmasi');
      final t = await env.service.changeTime(env.account('a-rina'), 's-basdat-today',
          DateTime(2026, 11, 23, 14), DateTime(2026, 11, 23, 16));
      expect(t.valueOrNull!.status, SessionStatus.belumTerkonfirmasi);
      expect(t.valueOrNull!.history, hasLength(3));
    });
  });

  test('cancel => Batal with history; cancelled session cannot be recorded', () async {
    final r = await env.service.cancel(env.account('a-rina'), 's-ai-today');
    expect(r.valueOrNull!.statusLabel, 'Batal');
    expect(r.valueOrNull!.history.last.description, 'Sesi dibatalkan');
    final again = await env.service.recordAttendance(env.account('a-rina'), 's-ai-today');
    expect(again.isSuccess, isFalse);
  });

  test('recordAttendance => Tercatat at current time', () async {
    final r = await env.service.recordAttendance(env.account('a-hendra'), 's-basdat-today');
    expect(r.valueOrNull!.statusLabel, 'Tercatat · Sinkron absensi 08.15');
  });

  test('changeTime rejects end before start', () async {
    final r = await env.service.changeTime(env.account('a-rina'), 's-ai-today',
        DateTime(2026, 11, 23, 12), DateTime(2026, 11, 23, 11));
    expect(r.isSuccess, isFalse);
    expect((await load('s-ai-today')).history, hasLength(1));
  });

  group('permissions', () {
    test('student cannot edit', () async {
      final r = await env.service
          .changeRoom(env.account('a-nadia'), 's-mobile-today', 'X');
      expect(r.isSuccess, isFalse);
    });

    test('lecturer cannot edit another lecturer\'s session', () async {
      final r = await env.service.cancel(env.account('a-rina'), 's-strukdat-today');
      expect(r.isSuccess, isFalse);
    });

    test('officer cannot edit outside scope', () async {
      final r = await env.service.cancel(env.account('a-hendra'), 's-pm-today');
      expect(r.isSuccess, isFalse);
      expect((await load('s-pm-today')).isCancelled, isFalse);
    });
  });

  group('reportEmptyRoom (P09)', () {
    test('does not change status, labels notification belum dikonfirmasi, idempotent',
        () async {
      await env.follows.follow('a-raka', 's-basdat-today');
      final before = await load('s-basdat-today');
      final r1 = await env.service.reportEmptyRoom(env.account('a-nadia'), 's-basdat-today');
      final r2 = await env.service.reportEmptyRoom(env.account('a-nadia'), 's-basdat-today');
      expect(r1.valueOrNull!.id, r2.valueOrNull!.id);
      expect((await env.reports.forSession('s-basdat-today')).valueOrNull, hasLength(1));

      final after = await load('s-basdat-today');
      expect(after.statusLabel, before.statusLabel);
      expect(after.history, hasLength(before.history.length));

      final raka = (await env.notifications.forUser('a-raka')).valueOrNull!;
      expect(raka.single.kind, NotificationKind.emptyRoomReport);
      expect(raka.single.title, contains('belum dikonfirmasi'));
    });

    test('only students can report', () async {
      final r = await env.service.reportEmptyRoom(env.account('a-rina'), 's-basdat-today');
      expect(r.isSuccess, isFalse);
    });
  });
}
