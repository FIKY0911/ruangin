import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/remote/api_client.dart';

const testBaseUrl = 'http://api.test/api';
final testNow = DateTime(2026, 11, 23, 8, 15);

/// In-memory stand-in for the Laravel API (backend/routes/api.php), served
/// through `MockClient`. Same JSON shapes and error format as the backend.
class FakeBackend {
  FakeBackend({DateTime? now}) : now = now ?? testNow {
    _seed();
  }

  final DateTime now;
  final requests = <http.Request>[];
  final users = <String, Map<String, dynamic>>{};
  final passwords = <String, String>{};
  final tokens = <String, String>{}; // token -> userId
  final lecturers = <String, Map<String, dynamic>>{};
  final sessions = <String, Map<String, dynamic>>{};
  final follows = <String, Set<String>>{}; // userId -> sessionIds
  final lecturerFollows = <String, Set<String>>{}; // userId -> lecturerIds

  /// Room catalog (backend `rooms`): building per room.
  final rooms = <String, String>{
    'Ruang 402': 'Gedung D',
    'Ruang 306': 'Gedung C',
    'Lab 2': 'Gedung C',
  };

  /// `GET /app-config`.
  bool simulatedData = true;
  int? retentionDays = 30;

  /// Active semester (backend `semesters`): 14 weeks, [now] in week 11.
  late final DateTime semesterStart = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - 1) - 70,
  );
  late final DateTime semesterEnd = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day + 14 * 7 - 1,
  );
  bool hasActiveSemester = true;
  final notifications = <Map<String, dynamic>>[];
  final reports = <Map<String, dynamic>>[];
  final seen = <String>{};

  /// Force the next request(s) to fail as if the server were unreachable.
  bool offline = false;
  int _seq = 0;

  late final MockClient client = MockClient(_handle);

  ApiClient api(KeyValueStore store) => ApiClient(
    httpClient: client,
    baseUrl: testBaseUrl,
    tokens: TokenStore(store),
  );

  DateTime _at(int dayOffset, int h, int m) =>
      DateTime(now.year, now.month, now.day + dayOffset, h, m);

  void _seed() {
    void user(
      String id,
      String name,
      String email,
      String role,
      String subtitle, {
      String? lecturerId,
      List<String> scope = const [],
      int points = 0,
    }) {
      users[id] = {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'roleLabel': role,
        'subtitle': subtitle,
        'lecturerId': lecturerId,
        'scopeProdi': scope,
        'points': points,
      };
      passwords[id] = 'ruangin123';
    }

    user(
      'u-nadia',
      'Nadia Putri',
      'nadia@demo.ruangin.id',
      'mahasiswa',
      'Mahasiswa Manajemen',
      points: 10,
    );
    user(
      'u-rina',
      'Dr. Rina Kusuma, M.Kom.',
      'rina@demo.ruangin.id',
      'dosen',
      'Dosen Sistem Informasi',
      lecturerId: 'l-rina',
    );
    user(
      'u-hendra',
      'Hendra Wijaya',
      'hendra@demo.ruangin.id',
      'petugas',
      'Petugas akademik FTI',
      scope: ['Teknik Informatika'],
    );

    lecturers['l-rina'] = {
      'id': 'l-rina',
      'name': 'Dr. Rina Kusuma, M.Kom.',
      'prodi': 'Sistem Informasi',
      'faculty': 'Fakultas Teknologi Informasi',
    };
    lecturers['l-budi'] = {
      'id': 'l-budi',
      'name': 'Dr. Budi Santoso',
      'prodi': 'Teknik Informatika',
      'faculty': 'Fakultas Teknologi Informasi',
    };

    void session(
      String id,
      String lecturerId,
      String course,
      String prodi,
      DateTime start,
      DateTime end,
      String room,
    ) {
      sessions[id] = {
        'id': id,
        'lecturerId': lecturerId,
        'courseName': course,
        'prodi': prodi,
        'start': start,
        'end': end,
        'room': room,
        'source': 'Jadwal prodi (data sintetis)',
        'updatedAt': _at(-1, 9, 0),
        'isCancelled': false,
        'attendance': null,
        'history': <Map<String, dynamic>>[],
        'version': 1,
      };
    }

    session(
      's-pm-today',
      'l-rina',
      'Pemrograman Mobile',
      'Teknik Informatika',
      _at(0, 7, 30),
      _at(0, 10, 0),
      'Ruang 402',
    );
    session(
      's-si-today',
      'l-rina',
      'Analisis Sistem',
      'Sistem Informasi',
      _at(0, 13, 0),
      _at(0, 14, 30),
      'Ruang 306',
    );
    session(
      's-basis-today',
      'l-budi',
      'Basis Data',
      'Teknik Informatika',
      _at(0, 10, 0),
      _at(0, 11, 40),
      'Lab 2',
    );
    session(
      's-pm-tomorrow',
      'l-rina',
      'Pemrograman Mobile',
      'Teknik Informatika',
      _at(1, 7, 30),
      _at(1, 10, 0),
      'Ruang 402',
    );
  }

  // ---- helpers ------------------------------------------------------------

  String _iso(DateTime d) => d.toIso8601String();

  Map<String, dynamic>? _user(http.Request r) {
    final auth = r.headers['Authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    final id = tokens[auth.substring(7)];
    return id == null ? null : users[id];
  }

  bool canEdit(Map<String, dynamic>? u, Map<String, dynamic> s) =>
      switch (u?['role']) {
        'dosen' => u!['lecturerId'] == s['lecturerId'],
        'petugas' => (u!['scopeProdi'] as List).contains(s['prodi']),
        _ => false,
      };

  Map<String, dynamic> reportJson(
    Map<String, dynamic> r, {
    bool withSession = false,
    Map<String, dynamic>? viewer,
  }) => {
    'id': r['id'],
    'sessionId': r['sessionId'],
    'reporterId': r['reporterId'],
    'createdAt': _iso(r['createdAt'] as DateTime),
    'status': r['status'],
    'statusLabel': r['status'],
    'resolvedAt': r['resolvedAt'] == null
        ? null
        : _iso(r['resolvedAt'] as DateTime),
    'pointsAwarded': r['pointsAwarded'],
    if (withSession)
      'session': sessionJson(
        sessions[r['sessionId']]!,
        viewer,
        withLecturer: true,
      ),
    if (withSession) 'reporterName': users[r['reporterId']]?['name'],
  };

  Map<String, dynamic> lecturerJson(
    Map<String, dynamic> l,
    Map<String, dynamic>? u,
  ) => {
    ...l,
    'isFollowed': lecturerFollows[u?['id']]?.contains(l['id']) ?? false,
  };

  String _mark(Map<String, dynamic> s) {
    if (s['isCancelled'] == true) return 'batal';
    if (s['attendance'] != null) return 'tercatat';
    if ((s['end'] as DateTime).isAfter(now)) return 'belumBerlangsung';
    return 'belumTerkonfirmasi';
  }

  Map<String, dynamic> _summary(List<String> marks) {
    int c(String m) => marks.where((x) => x == m).length;
    final counted = c('tercatat') + c('belumTerkonfirmasi');
    return {
      'total': marks.length,
      'tercatat': c('tercatat'),
      'belumTerkonfirmasi': c('belumTerkonfirmasi'),
      'batal': c('batal'),
      'belumBerlangsung': c('belumBerlangsung'),
      'counted': counted,
      'rate': counted == 0 ? null : c('tercatat') / counted,
    };
  }

  Map<String, dynamic> attendanceJson(
    Map<String, dynamic> l,
    Map<String, dynamic> u,
  ) {
    final end = DateTime(
      semesterEnd.year,
      semesterEnd.month,
      semesterEnd.day + 1,
    );
    final list =
        sessions.values
            .where(
              (s) =>
                  s['lecturerId'] == l['id'] &&
                  !(s['start'] as DateTime).isBefore(semesterStart) &&
                  (s['start'] as DateTime).isBefore(end),
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['start'] as DateTime).compareTo(b['start'] as DateTime),
          );
    final byCourse = <String, List<Map<String, dynamic>>>{};
    for (final s in list) {
      (byCourse['${s['courseName']}\n${s['prodi']}'] ??= []).add(s);
    }
    final keys = byCourse.keys.toList()..sort();
    return {
      'lecturer': lecturerJson(l, u),
      'semester': {
        'id': 'sem-test',
        'name': 'Semester Ganjil 2026/2027',
        'startsOn': isoDay(semesterStart),
        'endsOn': isoDay(semesterEnd),
      },
      'summary': _summary([for (final s in list) _mark(s)]),
      'courses': [
        for (final k in keys)
          {
            'courseName': byCourse[k]!.first['courseName'],
            'prodi': byCourse[k]!.first['prodi'],
            'summary': _summary([for (final s in byCourse[k]!) _mark(s)]),
            'meetings': [
              for (var i = 0; i < byCourse[k]!.length; i++)
                {
                  'number': i + 1,
                  'sessionId': byCourse[k]![i]['id'],
                  'start': _iso(byCourse[k]![i]['start'] as DateTime),
                  'end': _iso(byCourse[k]![i]['end'] as DateTime),
                  'room': byCourse[k]![i]['room'],
                  'building': rooms[byCourse[k]![i]['room']],
                  'status': _mark(byCourse[k]![i]),
                },
            ],
          },
      ],
    };
  }

  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> sessionJson(
    Map<String, dynamic> s,
    Map<String, dynamic>? u, {
    bool detail = false,
    bool withLecturer = false,
  }) {
    final att = s['attendance'] as Map<String, dynamic>?;
    final pending = reports
        .where((r) => r['sessionId'] == s['id'] && r['status'] == 'pending')
        .length;
    final mine = reports
        .where((r) => r['sessionId'] == s['id'] && r['reporterId'] == u?['id'])
        .firstOrNull;
    return {
      'id': s['id'],
      'lecturerId': s['lecturerId'],
      if (withLecturer || detail)
        'lecturer': lecturerJson(lecturers[s['lecturerId']]!, u),
      'courseName': s['courseName'],
      'prodi': s['prodi'],
      'start': _iso(s['start'] as DateTime),
      'end': _iso(s['end'] as DateTime),
      'room': s['room'],
      'building': rooms[s['room']],
      'source': s['source'],
      'updatedAt': _iso(s['updatedAt'] as DateTime),
      'isCancelled': s['isCancelled'],
      'attendance': att == null
          ? null
          : {
              'recordedAt': _iso(att['recordedAt'] as DateTime),
              'source': att['source'],
            },
      if (detail)
        'history': [
          for (final h in s['history'] as List<Map<String, dynamic>>)
            {
              'at': _iso(h['at'] as DateTime),
              'actor': h['actor'],
              'description': h['description'],
            },
        ],
      'status': s['isCancelled'] == true
          ? 'batal'
          : att != null
          ? 'tercatat'
          : 'belumTerkonfirmasi',
      'version': s['version'],
      'canEdit': canEdit(u, s),
      'isFollowed': follows[u?['id']]?.contains(s['id']) ?? false,
      'pendingReportCount': pending,
      if (detail) 'myReport': mine == null ? null : reportJson(mine),
    };
  }

  void notify(
    String userId,
    String sessionId,
    String kind,
    String title, [
    String body = '',
  ]) {
    notifications.add({
      'id': 'n-${++_seq}',
      'recipientId': userId,
      'sessionId': sessionId,
      'kind': kind,
      'title': title,
      'body': body,
      'createdAt': now.add(Duration(seconds: _seq)),
      'read': false,
    });
  }

  void _notifyFollowers(
    Map<String, dynamic> s,
    String exceptUserId,
    String kind,
    String title,
  ) {
    final ids = {
      for (final e in follows.entries)
        if (e.value.contains(s['id'])) e.key,
      for (final e in lecturerFollows.entries)
        if (e.value.contains(s['lecturerId'])) e.key,
    }..remove(exceptUserId);
    for (final id in ids) {
      notify(id, s['id'] as String, kind, title);
    }
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _error(
    int status,
    String code,
    String message, [
    Map<String, List<String>>? errors,
  ]) => _json({'message': message, 'code': code, 'errors': ?errors}, status);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _date(String? raw) => raw == null ? now : DateTime.parse(raw);

  // ---- routing ------------------------------------------------------------

  Future<http.Response> _handle(http.Request r) async {
    requests.add(r);
    if (offline) throw http.ClientException('Connection refused');
    final path = r.url.path.replaceFirst('/api', '');
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final body = r.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(r.body) as Map<String, dynamic>;
    final q = r.url.queryParameters;
    final m = r.method;

    if (r.headers['Accept'] != 'application/json') {
      return http.Response('<html>not json</html>', 500);
    }

    // Public auth routes.
    if (m == 'POST' && path == '/auth/register') {
      final email = (body['email'] as String).trim().toLowerCase();
      if (users.values.any((u) => u['email'] == email)) {
        return _error(422, 'emailTaken', 'Email sudah terdaftar.', {
          'email': ['Email sudah terdaftar.'],
        });
      }
      final id = 'u-${++_seq}';
      users[id] = {
        'id': id,
        'name': email.split('@').first,
        'email': email,
        'role': 'mahasiswa',
        'roleLabel': 'Mahasiswa',
        'subtitle': 'Mahasiswa',
        'lecturerId': null,
        'scopeProdi': <String>[],
        'points': 0,
      };
      passwords[id] = body['password'] as String;
      return _json({'data': users[id]}, 201);
    }
    if (m == 'POST' && path == '/auth/login') {
      final email = (body['email'] as String).trim().toLowerCase();
      final u = users.values.where((u) => u['email'] == email).firstOrNull;
      if (u == null) {
        return _error(
          401,
          'accountNotFound',
          'Akun tidak ditemukan. Periksa email atau daftar akun baru.',
          {
            'email': ['Akun tidak ditemukan.'],
          },
        );
      }
      if (passwords[u['id']] != body['password']) {
        return _error(401, 'wrongPassword', 'Password salah.', {
          'password': ['Password salah.'],
        });
      }
      final token = 'tok-${++_seq}';
      tokens[token] = u['id'] as String;
      return _json({'token': token, 'tokenType': 'Bearer', 'account': u});
    }

    final u = _user(r);
    if (u == null) {
      return _error(
        401,
        'unauthenticated',
        'Sesi login berakhir. Silakan masuk lagi.',
      );
    }
    final uid = u['id'] as String;

    if (path == '/auth/me') return _json({'data': u});
    if (path == '/auth/logout') {
      tokens.removeWhere((_, v) => v == uid);
      return http.Response('', 204);
    }

    if (m == 'GET' && path == '/app-config') {
      return _json({
        'data': {
          'simulatedData': simulatedData,
          'notificationRetentionDays': retentionDays,
        },
      });
    }

    if (m == 'GET' && path == '/search') {
      final query = (q['q'] ?? '').trim().toLowerCase();
      if (query.isEmpty) {
        return _error(422, 'invalidInput', 'Periksa kembali isian formulir.', {
          'q': ['Kata kunci wajib diisi.'],
        });
      }
      final from = DateTime(now.year, now.month, now.day);
      final to = DateTime(now.year, now.month, now.day + 7);
      final ls =
          lecturers.values
              .where((l) => (l['name'] as String).toLowerCase().contains(query))
              .toList()
            ..sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String),
            );
      final ss =
          sessions.values
              .where(
                (s) =>
                    !(s['start'] as DateTime).isBefore(from) &&
                    (s['start'] as DateTime).isBefore(to) &&
                    ((s['courseName'] as String).toLowerCase().contains(
                          query,
                        ) ||
                        (s['room'] as String).toLowerCase().contains(query)),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a['start'] as DateTime).compareTo(b['start'] as DateTime),
            );
      return _json({
        'query': q['q']!.trim(),
        'lecturers': [for (final l in ls) lecturerJson(l, u)],
        'sessions': [for (final s in ss) sessionJson(s, u, withLecturer: true)],
        'from': isoDay(from),
        'to': isoDay(to.subtract(const Duration(days: 1))),
      });
    }

    if (seg.first == 'lecturers' && seg.length == 3 && seg[2] == 'follow') {
      if (m == 'PUT') {
        if (lecturers[seg[1]] == null) {
          return _error(404, 'notFound', 'Data tidak ditemukan.');
        }
        (lecturerFollows[uid] ??= {}).add(seg[1]);
      } else if (m == 'DELETE') {
        lecturerFollows[uid]?.remove(seg[1]);
      }
      return _json({'lecturerId': seg[1], 'isFollowed': m == 'PUT'});
    }

    if (m == 'GET' && path == '/me/followed-lecturers') {
      final list =
          (lecturerFollows[uid] ?? {}).map((id) => lecturers[id]!).toList()
            ..sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String),
            );
      return _json({
        'data': [for (final l in list) lecturerJson(l, u)],
        'lecturerIds': [for (final l in list) l['id']],
      });
    }

    if (m == 'GET' && seg.first == 'lecturers') {
      if (seg.length == 3 && seg[2] == 'attendance') {
        final l = lecturers[seg[1]];
        if (l == null) return _error(404, 'notFound', 'Data tidak ditemukan.');
        if (!hasActiveSemester) {
          return _error(404, 'notFound', 'Belum ada semester aktif.');
        }
        return _json({'data': attendanceJson(l, u)});
      }
      if (seg.length == 1) {
        final query = (q['q'] ?? '').toLowerCase();
        final list =
            lecturers.values
                .where(
                  (l) => (l['name'] as String).toLowerCase().contains(query),
                )
                .toList()
              ..sort(
                (a, b) => (a['name'] as String).compareTo(b['name'] as String),
              );
        return _json({
          'data': [for (final l in list) lecturerJson(l, u)],
        });
      }
      final l = lecturers[seg[1]];
      if (l == null) return _error(404, 'notFound', 'Data tidak ditemukan.');
      if (seg.length == 2) return _json({'data': lecturerJson(l, u)});
      final date = _date(q['date']);
      final list =
          sessions.values
              .where(
                (s) =>
                    s['lecturerId'] == l['id'] &&
                    _sameDay(s['start'] as DateTime, date),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a['start'] as DateTime).compareTo(b['start'] as DateTime),
            );
      return _json({
        'data': [for (final s in list) sessionJson(s, u)],
        'lecturer': lecturerJson(l, u),
      });
    }

    if (m == 'GET' && path == '/sessions') {
      final date = _date(q['date']);
      final list =
          sessions.values
              .where((s) => _sameDay(s['start'] as DateTime, date))
              .where((s) => q['editable'] != '1' || canEdit(u, s))
              .toList()
            ..sort(
              (a, b) =>
                  (a['start'] as DateTime).compareTo(b['start'] as DateTime),
            );
      return _json({
        'data': [for (final s in list) sessionJson(s, u, withLecturer: true)],
      });
    }

    if (seg.first == 'sessions' && seg.length >= 2) {
      final s = sessions[seg[1]];
      if (s == null) return _error(404, 'notFound', 'Data tidak ditemukan.');
      final action = seg.length > 2 ? seg[2] : null;
      if (m == 'GET' && action == null) {
        return _json({'data': sessionJson(s, u, detail: true)});
      }
      if (action == 'follow') {
        if (m == 'PUT') (follows[uid] ??= {}).add(s['id'] as String);
        if (m == 'DELETE') follows[uid]?.remove(s['id']);
        return _json({'sessionId': s['id'], 'isFollowed': m == 'PUT'});
      }
      if (action == 'message-draft') {
        if (s['isCancelled'] == true) {
          return _error(
            422,
            'invalidState',
            'Sesi ini dibatalkan. Pilih sesi lain untuk menemui dosen.',
          );
        }
        final purpose = q['purpose'] ?? '[tuliskan keperluan Anda]';
        return _json({
          'sessionId': s['id'],
          'text':
              'Selamat pagi, Bapak/Ibu. Saya ${u['name']}. Saya ingin $purpose. '
              'Bolehkah saya menemui Bapak/Ibu setelah kelas di ${s['room']}?',
          'proposedTime': _iso(s['end'] as DateTime),
          'proposedPlace': s['room'],
          'note': 'Jadwal mengajar bukan jaminan dosen bisa ditemui.',
        });
      }
      if (m == 'POST' && action == 'reports') {
        if (u['role'] != 'mahasiswa') {
          return _error(
            403,
            'forbidden',
            'Hanya mahasiswa yang dapat melapor ruang kosong.',
          );
        }
        final existing = reports
            .where((x) => x['sessionId'] == s['id'] && x['reporterId'] == uid)
            .firstOrNull;
        if (existing != null) return _json({'data': reportJson(existing)});
        final rep = {
          'id': 'r-${++_seq}',
          'sessionId': s['id'],
          'reporterId': uid,
          'createdAt': now,
          'status': 'pending',
          'resolvedAt': null,
          'pointsAwarded': 0,
        };
        reports.add(rep);
        _notifyFollowers(
          s,
          uid,
          'emptyRoomReport',
          '${s['courseName']}: laporan ruang kosong (belum dikonfirmasi)',
        );
        return _json({'data': reportJson(rep)}, 201);
      }
      if (m == 'POST' &&
          ['time', 'room', 'cancel', 'attendance'].contains(action)) {
        if (!canEdit(u, s)) {
          return _error(
            403,
            'forbidden',
            'Anda tidak berhak mengubah sesi ini.',
          );
        }
        if (body['version'] != s['version']) {
          return _error(
            409,
            'staleVersion',
            'Sesi ini baru saja diubah orang lain. Muat ulang lalu coba lagi.',
          );
        }
        String desc;
        switch (action) {
          case 'room':
            desc = 'Ruang dipindah: ${s['room']} → ${body['room']}';
            s['room'] = body['room'];
          case 'time':
            s['start'] = DateTime.parse(body['start'] as String).toLocal();
            s['end'] = DateTime.parse(body['end'] as String).toLocal();
            desc = 'Jam diubah';
          case 'cancel':
            s['isCancelled'] = true;
            desc = 'Sesi dibatalkan';
          default:
            s['attendance'] = {'recordedAt': now, 'source': 'Dicatat manual'};
            desc = 'Kehadiran kelas dicatat';
        }
        s['version'] = (s['version'] as int) + 1;
        s['updatedAt'] = now;
        s['source'] = '${u['roleLabel']} · ${u['name']}';
        (s['history'] as List<Map<String, dynamic>>).add({
          'at': now,
          'actor': s['source'],
          'description': desc,
        });
        _notifyFollowers(s, uid, 'sessionChanged', '${s['courseName']}: $desc');
        return _json({'data': sessionJson(s, u, detail: true)});
      }
    }

    if (m == 'GET' && path == '/me/follows') {
      final list = (follows[uid] ?? {}).map((id) => sessions[id]!).toList()
        ..sort(
          (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
        );
      return _json({
        'data': [for (final s in list) sessionJson(s, u, withLecturer: true)],
        'sessionIds': [for (final s in list) s['id']],
      });
    }

    if (m == 'GET' && path == '/me/today') {
      final list =
          sessions.values
              .where(
                (s) =>
                    (follows[uid]?.contains(s['id']) ?? false) ||
                    (lecturerFollows[uid]?.contains(s['lecturerId']) ?? false),
              )
              .where((s) => _sameDay(s['start'] as DateTime, now))
              .toList()
            ..sort(
              (a, b) =>
                  (a['start'] as DateTime).compareTo(b['start'] as DateTime),
            );
      final next = list
          .where(
            (s) =>
                s['isCancelled'] != true && (s['end'] as DateTime).isAfter(now),
          )
          .firstOrNull;
      return _json({
        'data': [for (final s in list) sessionJson(s, u, withLecturer: true)],
        'date': now.toIso8601String().substring(0, 10),
        'nextSessionId': next?['id'],
        'unreadCount': _mine(uid).where((n) => n['read'] != true).length,
        'points': u['points'],
      });
    }

    if (path == '/me/notifications' && m == 'GET') {
      final list = _mine(uid)
          .where((n) => q['unread'] != '1' || n['read'] != true)
          .toList()
          .reversed;
      return _json({
        'data': [
          for (final n in list)
            {
              ...n,
              'createdAt': _iso(n['createdAt'] as DateTime),
              'isRead': n['read'],
            }..remove('read'),
        ],
        'unreadCount': _mine(uid).where((n) => n['read'] != true).length,
        'retentionDays': retentionDays,
      });
    }
    if (path == '/me/notifications/read-all') {
      var updated = 0;
      for (final n in _mine(uid)) {
        if (n['read'] != true) updated++;
        n['read'] = true;
      }
      return _json({'updated': updated});
    }
    if (path == '/me/notifications/seen') {
      seen.addAll((body['ids'] as List).cast<String>());
      return _json({'updated': (body['ids'] as List).length});
    }
    if (seg.first == 'notifications' && seg.length == 3 && seg[2] == 'read') {
      final n = _mine(uid).where((n) => n['id'] == seg[1]).firstOrNull;
      if (n == null) return _error(404, 'notFound', 'Data tidak ditemukan.');
      n['read'] = true;
      return _json({
        'data': {
          ...n,
          'createdAt': _iso(n['createdAt'] as DateTime),
          'isRead': true,
        }..remove('read'),
      });
    }

    if (seg.first == 'reports') {
      if (u['role'] == 'mahasiswa') {
        return _error(
          403,
          'forbidden',
          'Anda tidak berhak melakukan aksi ini.',
        );
      }
      if (m == 'GET') {
        final status = q['status'] ?? 'pending';
        final list = reports
            .where((x) => status == 'all' || x['status'] == status)
            .where((x) => canEdit(u, sessions[x['sessionId']]!))
            .toList()
            .reversed;
        return _json({
          'data': [
            for (final x in list) reportJson(x, withSession: true, viewer: u),
          ],
        });
      }
      final rep = reports.where((x) => x['id'] == seg[1]).firstOrNull;
      if (rep == null) return _error(404, 'notFound', 'Data tidak ditemukan.');
      if (rep['status'] != 'pending') {
        return _error(422, 'alreadyResolved', 'Laporan ini sudah ditinjau.');
      }
      final s = sessions[rep['sessionId']]!;
      if (seg[2] == 'confirm') {
        s['isCancelled'] = true;
        s['version'] = (s['version'] as int) + 1;
        for (final x in reports.where(
          (x) => x['sessionId'] == s['id'] && x['status'] == 'pending',
        )) {
          x['status'] = 'confirmed';
          x['resolvedAt'] = now;
          x['pointsAwarded'] = 10;
          users[x['reporterId']]!['points'] =
              (users[x['reporterId']]!['points'] as int) + 10;
          notify(
            x['reporterId'] as String,
            s['id'] as String,
            'reportResolved',
            'Laporan Anda dikonfirmasi · +10 poin',
          );
        }
      } else {
        rep['status'] = 'rejected';
        rep['resolvedAt'] = now;
        notify(
          rep['reporterId'] as String,
          s['id'] as String,
          'reportResolved',
          'Laporan Anda ditolak',
        );
      }
      return _json({'data': reportJson(rep, withSession: true, viewer: u)});
    }

    if (seg.first == 'demo') {
      if (u['role'] != 'petugas') {
        return _error(
          403,
          'forbidden',
          'Panel demo hanya untuk petugas akademik.',
        );
      }
      return switch (seg[1]) {
        'attendance-batch' => _json({'recorded': 1, 'results': []}),
        'early-warnings' => _json({'sent': 2}),
        _ => () {
          tokens.clear();
          return _json({'message': 'Data demo di-reset. Silakan masuk lagi.'});
        }(),
      };
    }

    return _error(404, 'notFound', 'Endpoint tidak ditemukan.');
  }

  Iterable<Map<String, dynamic>> _mine(String uid) =>
      notifications.where((n) => n['recipientId'] == uid);

  /// Signs [userId] in directly (bypassing /auth/login) and stores the token.
  Future<void> signInAs(String userId, KeyValueStore store) async {
    final token = 'tok-${++_seq}';
    tokens[token] = userId;
    final t = TokenStore(store);
    await t.saveToken(token);
    await t.saveAccount(users[userId]!);
  }

  Iterable<http.Request> calls(String method, String pathSuffix) => requests
      .where((r) => r.method == method && r.url.path.endsWith(pathSuffix));
}
