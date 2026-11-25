import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/local/key_value_store.dart';

import 'app_harness.dart';
import 'fake_backend.dart';

void main() {
  late FakeBackend backend;
  late InMemoryStore store;

  setUp(() {
    backend = FakeBackend();
    store = InMemoryStore();
  });

  testWidgets(
    'welcome -> register -> login -> Beranda -> logout; token persists',
    (tester) async {
      await pumpApp(tester, backend, store);
      expect(find.text('Class awaits'), findsOneWidget);

      await tapKey(tester, 'welcome-signup');
      expect(find.text('Register'), findsOneWidget);

      await tapKey(tester, 'register-submit');
      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(backend.requests, isEmpty, reason: 'validated locally');

      await tester.enterText(field('register-email'), 'andikacatvr@gmail.com');
      await tester.enterText(field('register-password'), 'rahasia123');
      await tester.enterText(field('register-confirm'), 'rahasia12');
      await tapKey(tester, 'register-submit');
      expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);

      await tester.enterText(field('register-confirm'), 'rahasia123');
      await tapKey(tester, 'register-submit');
      expect(backend.calls('POST', '/auth/register'), hasLength(1));

      expect(find.text('Enter your account'), findsOneWidget);
      expect(find.byKey(const Key('register-success')), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'andikacatvr@gmail.com'),
        findsOneWidget,
      );

      await tester.enterText(field('login-password'), 'salahsalah');
      await tapKey(tester, 'login-submit');
      expect(find.byKey(const Key('form-error')), findsOneWidget);
      expect(
        find.text('Password salah.'),
        findsWidgets,
        reason: 'server message',
      );

      await tester.enterText(field('login-password'), 'rahasia123');
      await tapKey(tester, 'login-submit');
      expect(find.text('Halo, andikacatvr!'), findsOneWidget);
      expect(find.text('Sesi hari ini'), findsOneWidget);
      expect(
        find.byType(BackButton),
        findsNothing,
        reason: 'auth routes closed',
      );

      await pumpApp(tester, backend, store);
      expect(
        find.text('Halo, andikacatvr!'),
        findsOneWidget,
        reason: 'persisted',
      );

      await tapKey(tester, 'nav-profile');
      await tapKey(tester, 'logout-button');
      expect(find.text('Class awaits'), findsOneWidget);
      expect(backend.calls('POST', '/auth/logout'), hasLength(1));
      await pumpApp(tester, backend, store);
      expect(find.text('Class awaits'), findsOneWidget);
    },
  );

  testWidgets('login: account not found, demo account, links switch screens', (
    tester,
  ) async {
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'welcome-login');
    await tapKey(tester, 'go-register');
    expect(find.text('Sign up'), findsWidgets);
    await tapKey(tester, 'go-login');
    expect(find.text('Enter your account'), findsOneWidget);

    await tester.enterText(field('login-email'), 'tidakada@kampus.ac.id');
    await tester.enterText(field('login-password'), 'apaaja123');
    await tapKey(tester, 'login-submit');
    expect(find.textContaining('Akun tidak ditemukan'), findsWidgets);

    await tester.enterText(field('login-email'), 'rina@demo.ruangin.id');
    await tester.enterText(field('login-password'), 'ruangin123');
    await tapKey(tester, 'login-submit');
    expect(find.text('Halo, rina!'), findsOneWidget);
    expect(find.text('Sesi yang bisa Anda kelola'), findsOneWidget);
  });

  testWidgets('server unreachable on login shows the connection error', (
    tester,
  ) async {
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'welcome-login');
    backend.offline = true;
    await tester.enterText(field('login-email'), 'nadia@demo.ruangin.id');
    await tester.enterText(field('login-password'), 'ruangin123');
    await tapKey(tester, 'login-submit');
    expect(
      find.textContaining('Tidak bisa terhubung ke server'),
      findsOneWidget,
    );
  });

  testWidgets('revoked token (401) sends the user back to Welcome', (
    tester,
  ) async {
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(find.text('Halo, nadia!'), findsOneWidget);

    backend.tokens.clear();
    await tapKey(tester, 'nav-schedule');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Class awaits'), findsOneWidget);
    expect(
      find.text('Sesi login berakhir. Silakan masuk lagi.'),
      findsOneWidget,
    );
  });

  testWidgets('unavailable actions show "Belum tersedia di demo"', (
    tester,
  ) async {
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'welcome-login');
    for (final key in ['forgot-password', 'apple-button', 'google-button']) {
      await tapKey(tester, key);
      expect(find.text('Belum tersedia di demo'), findsOneWidget, reason: key);
      ScaffoldMessengerState messenger = tester.state(
        find.byType(ScaffoldMessenger),
      );
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });
}
