import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/core/demo_settings.dart';
import 'package:ruangin/core/result.dart';
import 'package:ruangin/data/fixtures/seed_data.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/models/account.dart';
import 'package:ruangin/data/repositories/local_repositories.dart';
import 'package:ruangin/domain/auth_service.dart';
import 'package:ruangin/domain/password_hasher.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthService makeService(KeyValueStore store) {
  final clock = FixedClock(DateTime(2026, 11, 23, 8));
  return AuthService(
    repo: LocalAuthRepository(
        SeedData.parse(clock.now()), store, DemoSettings(latency: Duration.zero)),
    hasher: Pbkdf2PasswordHasher(iterations: 1000),
    clock: clock,
  );
}

const _valid = RegisterInput(
  email: 'Sari@Kampus.ac.id',
  password: 'rahasia123',
  confirmPassword: 'rahasia123',
);

AuthFailure _fail(Result<Object?> r) => (r as Failure).failure as AuthFailure;

void main() {
  late InMemoryStore store;
  late AuthService service;

  setUp(() {
    store = InMemoryStore();
    service = makeService(store);
  });

  group('register', () {
    test('creates a mahasiswa account with a hashed password', () async {
      final r = await service.register(_valid);
      final account = r.valueOrNull!;
      expect(account.role, UserRole.mahasiswa);
      expect(account.email, 'sari@kampus.ac.id');
      expect(account.name, 'sari', reason: 'name derived from email');
      final raw = store.getString(StoreKeys.users)!;
      expect(raw, contains('sari@kampus.ac.id'));
      expect(raw, isNot(contains('rahasia123')), reason: 'no plain text password');
    });

    test('ids stay unique even with a fixed clock', () async {
      final a = await service.register(_valid);
      final b = await service.register(const RegisterInput(
          email: 'lain@kampus.ac.id',
          password: 'rahasia123',
          confirmPassword: 'rahasia123'));
      expect(a.valueOrNull!.id, isNot(b.valueOrNull!.id));
    });

    test('does not sign in automatically', () async {
      await service.register(_valid);
      expect(await service.restoreSession(), isNull);
    });

    test('rejects invalid input with field errors', () async {
      final r = await service.register(const RegisterInput( email: 'bukan-email', password: '123', confirmPassword: '1'));
      final f = _fail(r);
      expect(f.code, AuthErrorCode.invalidInput);
      expect(f.fieldErrors.keys, unorderedEquals(AuthField.values));
      expect(store.getString(StoreKeys.users), isNull);
    });

    test('rejects an email that is already registered (case-insensitive)', () async {
      await service.register(_valid);
      final f = _fail(await service.register(const RegisterInput(
          email: ' SARI@kampus.AC.ID',
          password: 'rahasia999',
          confirmPassword: 'rahasia999')));
      expect(f.code, AuthErrorCode.emailTaken);
      expect(f.fieldErrors[AuthField.email], 'Email sudah terdaftar.');
    });

    test('rejects a seeded demo email', () async {
      final f = _fail(await service.register(const RegisterInput(
          email: 'nadia@demo.ruangin.id',
          password: 'rahasia123',
          confirmPassword: 'rahasia123')));
      expect(f.code, AuthErrorCode.emailTaken);
    });
  });

  group('login', () {
    test('registered user can log in; session persists across restarts', () async {
      await service.register(_valid);
      final r = await service.login('sari@kampus.ac.id', 'rahasia123');
      expect(r.valueOrNull!.email, 'sari@kampus.ac.id');

      final restarted = makeService(store);
      expect((await restarted.restoreSession())?.email, 'sari@kampus.ac.id');
    });

    test('seed demo account logs in with its role from seed', () async {
      final r = await service.login('Rina@Demo.Ruangin.id', 'ruangin123');
      expect(r.valueOrNull!.role, UserRole.dosen);
    });

    test('unknown email => akun tidak ditemukan', () async {
      final f = _fail(await service.login('nobody@kampus.ac.id', 'rahasia123'));
      expect(f.code, AuthErrorCode.accountNotFound);
      expect(f.message, contains('Akun tidak ditemukan'));
      expect(await service.restoreSession(), isNull);
    });

    test('wrong password => password salah', () async {
      final f = _fail(await service.login('nadia@demo.ruangin.id', 'salahsalah'));
      expect(f.code, AuthErrorCode.wrongPassword);
      expect(f.message, 'Password salah.');
      expect(await service.restoreSession(), isNull);
    });

    test('empty fields are validation errors, no lookup', () async {
      final f = _fail(await service.login('', ''));
      expect(f.code, AuthErrorCode.invalidInput);
      expect(f.fieldErrors.keys,
          unorderedEquals([AuthField.email, AuthField.password]));
    });

    test('storage failure maps to a storage error', () async {
      final failing = AuthService(
        repo: LocalAuthRepository(SeedData.parse(DateTime(2026)), store,
            DemoSettings(latency: Duration.zero)..simulateFailure = true),
        hasher: Pbkdf2PasswordHasher(iterations: 1000),
        clock: const SystemClock(),
      );
      final f = _fail(await failing.login('nadia@demo.ruangin.id', 'ruangin123'));
      expect(f.code, AuthErrorCode.storage);
    });
  });

  test('logout clears the persisted session', () async {
    await service.login('nadia@demo.ruangin.id', 'ruangin123');
    await service.logout();
    expect(await makeService(store).restoreSession(), isNull);
  });

  test('session persists through real shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefsStore = SharedPreferencesStore(await SharedPreferences.getInstance());
    await makeService(prefsStore).login('hendra@demo.ruangin.id', 'ruangin123');
    final again = SharedPreferencesStore(await SharedPreferences.getInstance());
    expect((await makeService(again).restoreSession())?.role, UserRole.petugas);
  });
}
