import 'dart:convert';

import '../../core/clock.dart';
import '../models/account.dart';
import '../models/lecturer.dart';
import '../models/password_hash.dart';
import '../models/session.dart';

/// SYNTHETIC demo data (PRD §8). Every name, room and schedule here is made
/// up. Session dates are relative to "today" (`dayOffset`) so the demo always
/// has data on the day it is shown.
///
/// Demo accounts all use the password `ruangin123`; only its PBKDF2-SHA256
/// hash (salted, 10 000 iterations) is stored here, never the plain text.
///
/// Demo scenario coverage:
/// 1. Nadia (Mahasiswa Manajemen) searches the TI lecturer "Rina".
/// 2. Rina's class ends 10.00 in Ruang 306 today (session `s-mobile-today`).
/// 3. Petugas Hendra (scope TI + SI) moves it to Ruang 402.
/// 4. Nadia opens the notification and sees the new room.
/// 5. `s-basdat-today` has no attendance record -> "Belum terkonfirmasi".
const String seedJson = r'''
{
  "lecturers": [
    {"id": "l-rina",   "name": "Dr. Rina Kartika, M.Kom.",   "prodi": "Teknik Informatika", "faculty": "Fakultas Teknologi Informasi"},
    {"id": "l-andi",   "name": "Andi Pratama, M.T.",         "prodi": "Teknik Informatika", "faculty": "Fakultas Teknologi Informasi"},
    {"id": "l-dewi",   "name": "Dewi Lestari, M.Kom.",       "prodi": "Sistem Informasi",   "faculty": "Fakultas Teknologi Informasi"},
    {"id": "l-budi",   "name": "Budi Santoso, S.E., M.M.",   "prodi": "Manajemen",          "faculty": "Fakultas Ekonomi dan Bisnis"},
    {"id": "l-siti",   "name": "Siti Rahmawati, S.E., M.Ak.","prodi": "Akuntansi",          "faculty": "Fakultas Ekonomi dan Bisnis"},
    {"id": "l-rinaldi","name": "Ahmad Rinaldi, M.T.",        "prodi": "Teknik Elektro",     "faculty": "Fakultas Teknik"}
  ],
  "accounts": [
    {"id": "a-nadia", "email": "nadia@demo.ruangin.id", "password": {"salt": "VIkAqpAhDTA+Y9ro/s7BPA==", "hash": "IC/OSETRIQaIE4hDWdmH3E4FgvpUIOGz0GLS7q0PP7k=", "iterations": 10000},
      "name": "Nadia Putri",      "role": "mahasiswa", "subtitle": "Mahasiswa Manajemen"},
    {"id": "a-raka", "email": "raka@demo.ruangin.id", "password": {"salt": "Li8VTQ6GMPMoSMk43q5eYA==", "hash": "hmO+ufxCvzMc4Ri7MkG4PEgmQsxC2F2YL8La9Atz/aE=", "iterations": 10000},
       "name": "Raka Wijaya",      "role": "mahasiswa", "subtitle": "Mahasiswa Akuntansi"},
    {"id": "a-rina", "email": "rina@demo.ruangin.id", "password": {"salt": "56Nrb9Ar/52zAH6liagWtw==", "hash": "IDey8EKcwweEthK8TWlileHjLzH+PCWz7PDwevP5Rj8=", "iterations": 10000},
       "name": "Dr. Rina Kartika", "role": "dosen",     "subtitle": "Dosen Teknik Informatika", "lecturerId": "l-rina"},
    {"id": "a-hendra", "email": "hendra@demo.ruangin.id", "password": {"salt": "JeACbcnwuP26TCC9Vte+eA==", "hash": "FdNO8lgMJwGNMDGdw7/MjaOpR8Mp/CU4Wu8RF2B3QfI=", "iterations": 10000},
     "name": "Hendra Gunawan",   "role": "petugas",   "subtitle": "Petugas akademik FTI", "scopeProdi": ["Teknik Informatika", "Sistem Informasi"]}
  ],
  "sessions": [
    {"id": "s-mobile-today", "lecturerId": "l-rina", "courseName": "Pemrograman Mobile", "prodi": "Teknik Informatika",
     "dayOffset": 0, "start": "07:30", "end": "10:00", "room": "Ruang 306",
     "attendanceAt": "07:34"},
    {"id": "s-basdat-today", "lecturerId": "l-rina", "courseName": "Basis Data Lanjut", "prodi": "Sistem Informasi",
     "dayOffset": 0, "start": "13:00", "end": "15:30", "room": "Ruang 201"},
    {"id": "s-ai-today", "lecturerId": "l-rina", "courseName": "Kecerdasan Buatan", "prodi": "Teknik Informatika",
     "dayOffset": 0, "start": "10:30", "end": "12:00", "room": "Lab Komputer 2"},
    {"id": "s-mobile-tomorrow", "lecturerId": "l-rina", "courseName": "Pemrograman Mobile", "prodi": "Teknik Informatika",
     "dayOffset": 1, "start": "07:30", "end": "10:00", "room": "Ruang 306"},
    {"id": "s-sim-yesterday", "lecturerId": "l-rina", "courseName": "Sistem Informasi Manajemen", "prodi": "Manajemen",
     "dayOffset": -1, "start": "09:00", "end": "11:00", "room": "Ruang 105", "attendanceAt": "09:03"},
    {"id": "s-jarkom-today", "lecturerId": "l-andi", "courseName": "Jaringan Komputer", "prodi": "Teknik Informatika",
     "dayOffset": 0, "start": "08:00", "end": "10:30", "room": "Ruang 404", "cancelled": true,
     "cancelNote": "Dibatalkan petugas: dosen dinas luar (sintetis)"},
    {"id": "s-strukdat-today", "lecturerId": "l-andi", "courseName": "Struktur Data", "prodi": "Teknik Informatika",
     "dayOffset": 0, "start": "13:00", "end": "14:40", "room": "Ruang 306"},
    {"id": "s-apb-today", "lecturerId": "l-dewi", "courseName": "Analisis Proses Bisnis", "prodi": "Sistem Informasi",
     "dayOffset": 0, "start": "09:00", "end": "11:30", "room": "Ruang 210", "attendanceAt": "09:06"},
    {"id": "s-pm-today", "lecturerId": "l-budi", "courseName": "Pengantar Manajemen", "prodi": "Manajemen",
     "dayOffset": 0, "start": "08:00", "end": "09:40", "room": "Ruang 101"},
    {"id": "s-akb-tomorrow", "lecturerId": "l-siti", "courseName": "Akuntansi Biaya", "prodi": "Akuntansi",
     "dayOffset": 1, "start": "10:00", "end": "12:30", "room": "Ruang 103"},
    {"id": "s-elda-later", "lecturerId": "l-rinaldi", "courseName": "Elektronika Dasar", "prodi": "Teknik Elektro",
     "dayOffset": 2, "start": "08:00", "end": "10:30", "room": "Lab Elektro 1"}
  ]
}
''';

/// Parsed seed, with relative dates resolved against [today].
class SeedData {
  SeedData._(this.lecturers, this.accounts, this.credentials, this.sessions);

  final List<Lecturer> lecturers;
  final List<Account> accounts;

  /// accountId -> password hash of the seeded demo accounts.
  final Map<String, PasswordHash> credentials;
  final List<Session> sessions;

  static const scheduleSource = 'Jadwal prodi (data sintetis)';
  static const attendanceSource = 'Sinkron absensi (simulasi)';

  factory SeedData.parse(DateTime today, {String raw = seedJson}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final day0 = dateOnly(today);

    DateTime at(int offset, String hhmm) {
      final parts = hhmm.split(':');
      return DateTime(day0.year, day0.month, day0.day + offset,
          int.parse(parts[0]), int.parse(parts[1]));
    }

    final sessions = (json['sessions'] as List<dynamic>).map((raw) {
      final s = raw as Map<String, dynamic>;
      final offset = s['dayOffset'] as int;
      final created = at(offset - 7, '06:00');
      final history = <ChangeEntry>[
        ChangeEntry(
          at: created,
          actor: 'Sistem',
          description: 'Jadwal diimpor dari data prodi (sintetis)',
        ),
      ];
      AttendanceRecord? attendance;
      var updatedAt = created;
      var source = scheduleSource;
      if (s['attendanceAt'] case final String time) {
        attendance =
            AttendanceRecord(recordedAt: at(offset, time), source: attendanceSource);
        updatedAt = attendance.recordedAt;
        source = attendanceSource;
        history.add(ChangeEntry(
          at: updatedAt,
          actor: 'Sinkron absensi',
          description: 'Kehadiran kelas tercatat di sistem absensi',
        ));
      }
      final cancelled = s['cancelled'] as bool? ?? false;
      if (cancelled) {
        updatedAt = at(offset, '06:30');
        source = 'Petugas akademik (sintetis)';
        history.add(ChangeEntry(
          at: updatedAt,
          actor: 'Petugas akademik',
          description: s['cancelNote'] as String? ?? 'Sesi dibatalkan',
        ));
      }
      return Session(
        id: s['id'] as String,
        lecturerId: s['lecturerId'] as String,
        courseName: s['courseName'] as String,
        prodi: s['prodi'] as String,
        start: at(offset, s['start'] as String),
        end: at(offset, s['end'] as String),
        room: s['room'] as String,
        source: source,
        updatedAt: updatedAt,
        isCancelled: cancelled,
        attendance: attendance,
        history: List.unmodifiable(history),
      );
    }).toList(growable: false);

    final accountsJson =
        (json['accounts'] as List<dynamic>).cast<Map<String, dynamic>>();
    return SeedData._(
      List.unmodifiable((json['lecturers'] as List<dynamic>)
          .map((e) => Lecturer.fromJson(e as Map<String, dynamic>))),
      List.unmodifiable(accountsJson.map(Account.fromJson)),
      Map.unmodifiable({
        for (final a in accountsJson)
          a['id'] as String:
              PasswordHash.fromJson(a['password'] as Map<String, dynamic>),
      }),
      sessions,
    );
  }
}
