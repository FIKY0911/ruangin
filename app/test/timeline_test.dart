import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/models/session.dart';
import 'package:ruangin/data/repositories/local_repositories.dart';

import 'helpers.dart';
import 'package:ruangin/domain/session_status.dart';

Session _s(String id, String lecturer, String prodi, DateTime start) => Session(
      id: id,
      lecturerId: lecturer,
      courseName: id,
      prodi: prodi,
      start: start,
      end: start.add(const Duration(hours: 1)),
      room: 'R',
      source: 'x',
      updatedAt: start,
    );

void main() {
  group('buildTimeline (P02)', () {
    final d = DateTime(2026, 11, 23);
    final input = [
      _s('c', 'L1', 'Sistem Informasi', d.add(const Duration(hours: 13))),
      _s('a', 'L1', 'Teknik Informatika', d.add(const Duration(hours: 7))),
      _s('other-lecturer', 'L2', 'Teknik Informatika', d.add(const Duration(hours: 8))),
      _s('b', 'L1', 'Manajemen', d.add(const Duration(hours: 10))),
      _s('tomorrow', 'L1', 'Teknik Informatika', d.add(const Duration(days: 1, hours: 6))),
    ];

    test('merges all prodi for the lecturer and sorts by start time', () {
      final t = buildTimeline(input, 'L1', d);
      expect(t.map((s) => s.id), ['a', 'b', 'c']);
      expect(t.map((s) => s.prodi).toSet(), hasLength(3));
    });

    test('excludes other dates and other lecturers', () {
      final t = buildTimeline(input, 'L1', d.add(const Duration(days: 1)));
      expect(t.map((s) => s.id), ['tomorrow']);
      expect(buildTimeline(input, 'L3', d), isEmpty);
    });
  });

  test('seed: Rina today spans TI + SI, ordered, ends 10.00 in Ruang 306', () async {
    final env = TestEnv();
    final t = (await env.sessions.timeline('l-rina', today)).valueOrNull!;
    expect(t.map((s) => s.id), ['s-mobile-today', 's-ai-today', 's-basdat-today']);
    expect(t.map((s) => s.prodi).toSet(), {'Teknik Informatika', 'Sistem Informasi'});
    final first = t.first;
    expect((first.end.hour, first.end.minute), (10, 0));
    expect(first.room, 'Ruang 306');
    expect(t.last.statusLabel, 'Belum terkonfirmasi');
  });
}
