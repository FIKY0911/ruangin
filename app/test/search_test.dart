import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/models/lecturer.dart';
import 'package:ruangin/data/repositories/local_repositories.dart';

import 'helpers.dart';

void main() {
  const lecturers = [
    Lecturer(id: '1', name: 'Dr. Rina Kartika', prodi: 'Teknik Informatika', faculty: 'F'),
    Lecturer(id: '2', name: 'Ahmad Rinaldi', prodi: 'Teknik Elektro', faculty: 'F'),
    Lecturer(id: '3', name: 'Budi Santoso', prodi: 'Manajemen', faculty: 'F'),
  ];

  group('filterLecturers (P01)', () {
    test('matches a partial name regardless of case', () {
      final ids = filterLecturers(lecturers, 'RIN').map((l) => l.id);
      expect(ids, unorderedEquals(['1', '2']));
      expect(filterLecturers(lecturers, 'kArTiKa').single.id, '1');
    });

    test('matches substrings in the middle of a name and trims spaces', () {
      expect(filterLecturers(lecturers, '  santo ').single.id, '3');
    });

    test('returns empty for no match and everything for an empty query', () {
      expect(filterLecturers(lecturers, 'zzz'), isEmpty);
      expect(filterLecturers(lecturers, ''), hasLength(3));
    });
  });

  test('LocalLecturerRepository.search exposes the home prodi', () async {
    final env = TestEnv();
    final result = await env.lecturers.search('rina');
    final list = result.valueOrNull!;
    expect(list.map((l) => l.id), containsAll(['l-rina', 'l-rinaldi']));
    expect(list.firstWhere((l) => l.id == 'l-rina').prodi, 'Teknik Informatika');
  });

  test('search maps a simulated failure to Failure', () async {
    final env = TestEnv()..demo.simulateFailure = true;
    final result = await env.lecturers.search('rina');
    expect(result.isSuccess, isFalse);
  });
}
