import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/brand.dart';
import 'core/clock.dart';
import 'core/demo_settings.dart';
import 'data/fixtures/seed_data.dart';
import 'data/local/key_value_store.dart';
import 'data/repositories/local_repositories.dart';
import 'domain/auth_service.dart';
import 'domain/password_hasher.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/auth/welcome_screen.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Composition root for M1 (auth only). To plug in a backend later, swap the
/// Local* classes for remote implementations of the same interfaces — the UI
/// is unchanged.
///
/// The schedule feature (search, timeline, session detail, follow,
/// notifications, empty-room reports) is PARKED for M2: its providers live in
/// [buildScheduleDependencies] (lib/schedule_dependencies.dart) and are not
/// registered here, so nothing from it is instantiated at startup.
List<SingleChildWidget> buildDependencies({
  required KeyValueStore store,
  required Clock clock,
  required DemoSettings demo,
  PasswordHasher? hasher,
}) {
  final seed = SeedData.parse(clock.now());
  return [
    Provider<AuthService>.value(
      value: AuthService(
        repo: LocalAuthRepository(seed, store, demo),
        hasher: hasher ?? Pbkdf2PasswordHasher(),
        clock: clock,
      ),
    ),
    ChangeNotifierProvider<AuthController>(
      create: (c) => AuthController(c.read<AuthService>())..restore(),
    ),
  ];
}

class RuanginApp extends StatelessWidget {
  const RuanginApp({super.key, required this.dependencies});

  final List<SingleChildWidget> dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: dependencies,
      child: MaterialApp(
        title: 'Ruangin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isRestoring) {
      return Scaffold(
        body: Center(child: Image.asset(BrandAssets.icon, width: 96)),
      );
    }
    return auth.isSignedIn ? const HomeScreen() : const WelcomeScreen();
  }
}
