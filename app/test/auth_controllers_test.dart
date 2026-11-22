import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/domain/auth_service.dart';
import 'package:ruangin/presentation/auth/auth_controller.dart';
import 'package:ruangin/presentation/auth/auth_form_controllers.dart';

import 'auth_service_test.dart' show makeService;

void main() {
  late AuthService service;
  late AuthController auth;

  setUp(() async {
    service = makeService(InMemoryStore());
    auth = AuthController(service);
    await auth.restore();
  });

  test('LoginController: loading during submit, success signs in', () async {
    final c = LoginController(service, auth)
      ..setEmail('nadia@demo.ruangin.id')
      ..setPassword('ruangin123');
    final states = <bool>[];
    c.addListener(() => states.add(c.isSubmitting));
    expect(await c.submit(), isTrue);
    expect(states.first, isTrue, reason: 'loading state shown');
    expect(c.isSubmitting, isFalse);
    expect(auth.account?.name, 'Nadia Putri');
  });

  test('LoginController: wrong password shows field + banner error', () async {
    final c = LoginController(service, auth)
      ..setEmail('nadia@demo.ruangin.id')
      ..setPassword('salahsalah');
    expect(await c.submit(), isFalse);
    expect(c.errorFor(AuthField.password), 'Password salah.');
    expect(c.errorMessage, 'Password salah.');
    expect(auth.isSignedIn, isFalse);
    c.setPassword('x');
    expect(c.errorFor(AuthField.password), isNull, reason: 'cleared on edit');
  });

  test('LoginController: validation errors only per field', () async {
    final c = LoginController(service, auth);
    await c.submit();
    expect(c.errorFor(AuthField.email), 'Email wajib diisi.');
    expect(c.errorMessage, isNull);
  });

  test('RegisterController: success returns account; duplicate shows error', () async {
    RegisterController form() => RegisterController(service)
      ..setEmail('sari@kampus.ac.id')
      ..setPassword('rahasia123')
      ..setConfirmPassword('rahasia123');
    expect((await form().submit())?.email, 'sari@kampus.ac.id');
    final dup = form();
    expect(await dup.submit(), isNull);
    expect(dup.errorFor(AuthField.email), 'Email sudah terdaftar.');
  });

  test('AuthController.logout clears account', () async {
    await LoginController(service, auth)
        .let((c) => c..setEmail('raka@demo.ruangin.id')..setPassword('ruangin123'))
        .submit();
    expect(auth.isSignedIn, isTrue);
    await auth.logout();
    expect(auth.isSignedIn, isFalse);
    final fresh = AuthController(service);
    await fresh.restore();
    expect(fresh.isSignedIn, isFalse);
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
