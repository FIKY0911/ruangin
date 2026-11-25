import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/models/app_notification.dart';
import 'package:ruangin/data/models/empty_room_report.dart';
import 'package:ruangin/data/models/session.dart';
import 'package:ruangin/data/remote/api_client.dart';

void main() {
  late InMemoryStore store;
  late List<http.Request> seen;

  ApiClient client(http.Response Function(http.Request) handler) {
    seen = [];
    return ApiClient(
      httpClient: MockClient((r) async {
        seen.add(r);
        return handler(r);
      }),
      baseUrl: 'http://api.test/api/',
      tokens: TokenStore(store),
    );
  }

  http.Response json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() => store = InMemoryStore());

  test(
    'sends Accept, bearer token, JSON body and query to the base URL',
    () async {
      await TokenStore(store).saveToken('abc');
      final api = client((_) => json({'ok': true}, 200));
      await api.post('/sessions/s-1/room', body: {'version': 3, 'room': 'R 1'});
      await api.get('/lecturers', query: {'q': 'rina', 'skip': null});

      expect(seen[0].url.toString(), 'http://api.test/api/sessions/s-1/room');
      expect(seen[0].headers['Accept'], 'application/json');
      expect(seen[0].headers['Authorization'], 'Bearer abc');
      expect(jsonDecode(seen[0].body), {'version': 3, 'room': 'R 1'});
      expect(seen[1].url.toString(), 'http://api.test/api/lecturers?q=rina');
    },
  );

  test('no Authorization header without a token; 204 returns null', () async {
    final api = client((_) => http.Response('', 204));
    expect(await api.post('/auth/logout'), isNull);
    expect(seen.single.headers.containsKey('Authorization'), isFalse);
  });

  test(
    'maps {message, code, errors} to ApiFailure with field errors',
    () async {
      final api = client(
        (_) => json({
          'message': 'Periksa kembali isian formulir.',
          'code': 'invalidInput',
          'errors': {
            'room': ['Ruang tidak boleh kosong.', 'x'],
          },
        }, 422),
      );
      final f = await api
          .get('/x')
          .then<ApiFailure?>(
            (_) => null,
            onError: (Object e) => e as ApiFailure,
          );
      expect(f!.statusCode, 422);
      expect(f.code, 'invalidInput');
      expect(f.message, 'Periksa kembali isian formulir.');
      expect(f.fieldErrors, {'room': 'Ruang tidak boleh kosong.'});
    },
  );

  test('409 is a stale version', () async {
    final api = client(
      (_) =>
          json({'message': 'Sesi sudah diubah.', 'code': 'staleVersion'}, 409),
    );
    await expectLater(
      api.post('/sessions/s/room', body: {}),
      throwsA(
        isA<ApiFailure>()
            .having((f) => f.isStaleVersion, 'stale', isTrue)
            .having((f) => f.message, 'message', 'Sesi sudah diubah.'),
      ),
    );
  });

  test('401 unauthenticated clears the token and notifies once', () async {
    await TokenStore(store).saveToken('old');
    var expired = 0;
    final api = client(
      (_) => json({
        'message': 'Sesi login berakhir.',
        'code': 'unauthenticated',
      }, 401),
    )..onUnauthenticated = () => expired++;
    await expectLater(api.get('/auth/me'), throwsA(isA<ApiFailure>()));
    expect(expired, 1);
    expect(TokenStore(store).token, isNull);
  });

  test('401 on login (wrong password) does not trigger sign-out', () async {
    var expired = 0;
    final api = client(
      (_) => json({'message': 'Password salah.', 'code': 'wrongPassword'}, 401),
    )..onUnauthenticated = () => expired++;
    await expectLater(
      api.post('/auth/login', body: {}),
      throwsA(isA<ApiFailure>().having((f) => f.code, 'code', 'wrongPassword')),
    );
    expect(expired, 0);
  });

  test('network error and non-JSON 500 become readable failures', () async {
    final offline = ApiClient(
      httpClient: MockClient(
        (_) async => throw http.ClientException('refused'),
      ),
      baseUrl: 'http://api.test/api',
      tokens: TokenStore(store),
    );
    await expectLater(
      offline.get('/x'),
      throwsA(
        isA<ApiFailure>()
            .having((f) => f.isNetwork, 'network', isTrue)
            .having(
              (f) => f.message,
              'message',
              contains('Tidak bisa terhubung'),
            ),
      ),
    );

    final api = client((_) => http.Response('<html>boom</html>', 500));
    await expectLater(
      api.get('/x'),
      throwsA(
        isA<ApiFailure>().having((f) => f.message, 'message', contains('500')),
      ),
    );
  });

  group('models', () {
    test('Session dates with +07:00 are the same instant, shown local', () {
      final s = Session.fromJson({
        'id': 's-1',
        'lecturerId': 'l-1',
        'courseName': 'Basis Data',
        'prodi': 'TI',
        'start': '2026-11-23T07:30:00+07:00',
        'end': '2026-11-23T10:00:00+07:00',
        'room': 'R 1',
        'source': 'x',
        'updatedAt': '2026-11-22T09:00:00+07:00',
        'isCancelled': false,
        'attendance': {
          'recordedAt': '2026-11-23T07:34:00+07:00',
          'source': 'Sinkron',
        },
        'version': 4,
        'canEdit': true,
        'isFollowed': true,
        'pendingReportCount': 2,
        'myReport': {
          'id': 'r-1',
          'sessionId': 's-1',
          'reporterId': 7,
          'createdAt': '2026-11-23T07:40:00+07:00',
          'status': 'confirmed',
          'pointsAwarded': 10,
        },
        'lecturer': {
          'id': 'l-1',
          'name': 'Dr. A',
          'prodi': 'TI',
          'faculty': 'F',
        },
      });
      expect(s.start.isUtc, isFalse, reason: '.toLocal() applied');
      expect(s.start.toUtc(), DateTime.utc(2026, 11, 23, 0, 30));
      expect(s.status, SessionStatus.tercatat);
      expect(s.version, 4);
      expect(s.canEdit && s.isFollowed, isTrue);
      expect(s.pendingReportCount, 2);
      expect(s.myReport!.status, ReportStatus.confirmed);
      expect(s.myReport!.reporterId, '7');
      expect(s.lecturer!.name, 'Dr. A');
    });

    test('NotificationKind knows the new kinds and tolerates unknown ones', () {
      expect(
        NotificationKind.parse('earlyWarning'),
        NotificationKind.earlyWarning,
      );
      expect(
        NotificationKind.parse('reportResolved'),
        NotificationKind.reportResolved,
      );
      expect(
        NotificationKind.parse('somethingNew'),
        NotificationKind.sessionChanged,
      );
    });
  });
}
