import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/app.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/core/demo_settings.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/domain/password_hasher.dart';

void main() {
  late InMemoryStore store;

  setUp(() => store = InMemoryStore());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RuanginApp(
      key: UniqueKey(),
      dependencies: buildDependencies(
        store: store,
        clock: FixedClock(DateTime(2026, 11, 23, 8)),
        demo: DemoSettings(latency: Duration.zero),
        hasher: Pbkdf2PasswordHasher(iterations: 1000),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.descendant(
      of: find.byKey(Key(key)), matching: find.byType(EditableText));

  testWidgets('welcome -> register -> login -> home -> logout; session persists',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Class awaits'), findsOneWidget);
    expect(find.text('Responsible, honest, trustworthy, and dedicated'), findsOneWidget);

    await tapKey(tester, 'welcome-signup');
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);

    // Validation errors.
    await tapKey(tester, 'register-submit');
    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Password wajib diisi.'), findsOneWidget);

    await tester.enterText(field('register-email'), 'andikacatvr@gmail.com');
    await tester.enterText(field('register-password'), 'rahasia123');
    await tester.enterText(field('register-confirm'), 'rahasia12');
    await tapKey(tester, 'register-submit');
    expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);

    await tester.enterText(field('register-confirm'), 'rahasia123');
    await tapKey(tester, 'register-submit');

    // Login opened with email prefilled + success message.
    expect(find.text('Enter your account'), findsOneWidget);
    expect(find.byKey(const Key('register-success')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'andikacatvr@gmail.com'), findsOneWidget);

    await tester.enterText(field('login-password'), 'salahsalah');
    await tapKey(tester, 'login-submit');
    expect(find.byKey(const Key('form-error')), findsOneWidget);
    expect(find.text('Password salah.'), findsWidgets);

    await tester.enterText(field('login-password'), 'rahasia123');
    await tapKey(tester, 'login-submit');
    expect(find.text('Halo, andikacatvr!'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'auth routes closed');

    await pumpApp(tester);
    expect(find.text('Halo, andikacatvr!'), findsOneWidget, reason: 'persisted');

    await tapKey(tester, 'logout-button');
    expect(find.text('Class awaits'), findsOneWidget);
    await pumpApp(tester);
    expect(find.text('Class awaits'), findsOneWidget);
  });

  testWidgets('login: not found error, demo account, links switch screens',
      (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'welcome-login');
    expect(find.text('Enter your account'), findsOneWidget);

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
  });

  testWidgets('unavailable actions show "Belum tersedia di demo"', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'welcome-login');
    for (final key in ['forgot-password', 'apple-button', 'google-button']) {
      await tapKey(tester, key);
      expect(find.text('Belum tersedia di demo'), findsOneWidget, reason: key);
      ScaffoldMessengerState messenger =
          tester.state(find.byType(ScaffoldMessenger));
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    await tapKey(tester, 'go-register');
    await tapKey(tester, 'apple-button');
    expect(find.text('Belum tersedia di demo'), findsOneWidget);
  });
}
