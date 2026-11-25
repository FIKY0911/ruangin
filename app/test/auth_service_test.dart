import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/core/result.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/models/account.dart';
import 'package:ruangin/data/remote/api_client.dart';
import 'package:ruangin/data/repositories/api_repositories.dart';
import 'package:ruangin/domain/auth_service.dart';

import 'fake_backend.dart';

AuthService makeService(FakeBackend backend, KeyValueStore store) =>
    AuthService(repo: ApiAuthRepository(backend.api(store)));

const _valid = RegisterInput(
  email: 'Sari@Kampus.ac.id',
  password: 'rahasia123',
  confirmPassword: 'rahasia123',
);

AuthFailure _fail(Result<Object?> r) => (r as Failure).failure as AuthFailure;

void main() {
  late FakeBackend backend;
  late InMemoryStore store;
  late AuthService service;

  setUp(() {
    backend = FakeBackend();
    store = InMemoryStore();
    service = makeService(backend, store);
  });

  group('register', () {
    test(
      'creates a mahasiswa account on the server without signing in',
      () async {
        final account = (await service.register(_valid)).valueOrNull!;
        expect(account.role, UserRole.mahasiswa);
        expect(account.email, 'sari@kampus.ac.id');
        expect(account.name, 'sari');
        expect(TokenStore(store).token, isNull, reason: 'register != login');
        final body = backend.calls('POST', '/auth/register').single.body;
        expect(body, contains('"confirmPassword":"rahasia123"'));
        expect(body, contains('sari@kampus.ac.id'), reason: 'email normalised');
      },
    );

    test('validates locally first (no request)', () async {
      final r = await service.register(
        const RegisterInput(
          email: 'bukan-email',
          password: 'pendek',
          confirmPassword: 'beda',
        ),
      );
      final f = _fail(r);
      expect(f.code, AuthErrorCode.invalidInput);
      expect(f.fieldErrors.keys, containsAll(AuthField.values));
      expect(backend.requests, isEmpty);
    });

    test('duplicate email maps the server error to the email field', () async {
      await service.register(_valid);
      final f = _fail(await service.register(_valid));
      expect(f.code, AuthErrorCode.emailTaken);
      expect(f.fieldErrors[AuthField.email], 'Email sudah terdaftar.');
    });
  });

  group('login', () {
    test('stores the bearer token; role comes from the server', () async {
      final a = (await service.login(
        ' RINA@demo.ruangin.id ',
        'ruangin123',
      )).valueOrNull!;
      expect(a.role, UserRole.dosen);
      expect(a.lecturerId, 'l-rina');
      expect(TokenStore(store).token, isNotNull);
    });

    test('wrong password and unknown account map to field errors', () async {
      var f = _fail(await service.login('nadia@demo.ruangin.id', 'salahsalah'));
      expect(f.code, AuthErrorCode.wrongPassword);
      expect(f.fieldErrors[AuthField.password], 'Password salah.');
      expect(f.message, 'Password salah.');

      f = _fail(await service.login('siapa@kampus.ac.id', 'ruangin123'));
      expect(f.code, AuthErrorCode.accountNotFound);
      expect(f.fieldErrors[AuthField.email], 'Akun tidak ditemukan.');
    });

    test('unreachable server is reported with its message', () async {
      backend.offline = true;
      final f = _fail(
        await service.login('nadia@demo.ruangin.id', 'ruangin123'),
      );
      expect(f.code, AuthErrorCode.server);
      expect(f.message, contains('Tidak bisa terhubung'));
    });
  });

  group('session', () {
    test('restore validates the token with /auth/me', () async {
      await service.login('nadia@demo.ruangin.id', 'ruangin123');
      final restored = await makeService(backend, store).restoreSession();
      expect(restored?.name, 'Nadia Putri');
      expect(restored?.points, 10);
      expect(backend.calls('GET', '/auth/me'), isNotEmpty);
    });

    test('restore with a revoked token signs out', () async {
      await service.login('nadia@demo.ruangin.id', 'ruangin123');
      backend.tokens.clear();
      expect(await makeService(backend, store).restoreSession(), isNull);
      expect(TokenStore(store).token, isNull);
    });

    test('restore offline falls back to the cached account', () async {
      await service.login('hendra@demo.ruangin.id', 'ruangin123');
      backend.offline = true;
      final a = await makeService(backend, store).restoreSession();
      expect(a?.role, UserRole.petugas);
    });

    test('logout revokes the token on the server and forgets it', () async {
      await service.login('nadia@demo.ruangin.id', 'ruangin123');
      await service.logout();
      expect(backend.calls('POST', '/auth/logout'), hasLength(1));
      expect(TokenStore(store).token, isNull);
      expect(await makeService(backend, store).restoreSession(), isNull);
    });
  });
}
