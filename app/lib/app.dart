import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/api_config.dart';
import 'core/brand.dart';
import 'core/clock.dart';
import 'data/local/key_value_store.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/api_repositories.dart';
import 'data/repositories/repositories.dart';
import 'domain/auth_service.dart';
import 'presentation/app_config_controller.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/auth/welcome_screen.dart';
import 'presentation/home_shell.dart';
import 'presentation/notifications/notification_center.dart';
import 'presentation/session/follow_controller.dart';
import 'presentation/theme/app_theme.dart';

/// Composition root. Every repository talks to the Laravel API at [baseUrl]
/// (default [apiBaseUrl], overridable with `--dart-define=API_BASE_URL=...`).
/// Tests pass a `MockClient` as [httpClient].
List<SingleChildWidget> buildDependencies({
  required KeyValueStore store,
  required http.Client httpClient,
  String baseUrl = apiBaseUrl,
  Clock clock = const SystemClock(),
  Duration? notificationPoll = const Duration(seconds: 30),
}) {
  final api = ApiClient(
    httpClient: httpClient,
    baseUrl: baseUrl,
    tokens: TokenStore(store),
  );
  final notifications = ApiNotificationRepository(api);
  final authService = AuthService(repo: ApiAuthRepository(api));
  return [
    Provider<Clock>.value(value: clock),
    Provider<ApiClient>.value(value: api),
    Provider<AuthService>.value(value: authService),
    ChangeNotifierProvider<AuthController>(
      create: (_) {
        final auth = AuthController(authService);
        api.onUnauthenticated = auth.onSessionExpired;
        return auth..restore();
      },
    ),
    Provider<LecturerRepository>.value(value: ApiLecturerRepository(api)),
    Provider<SearchRepository>.value(value: ApiSearchRepository(api)),
    Provider<AppConfigRepository>.value(value: ApiAppConfigRepository(api)),
    Provider<SessionRepository>.value(
      value: ApiSessionRepository(api, onChanged: notifications.notifyChanged),
    ),
    Provider<FollowRepository>.value(value: ApiFollowRepository(api)),
    Provider<NotificationRepository>.value(value: notifications),
    Provider<ReportRepository>.value(
      value: ApiReportRepository(api, onChanged: notifications.notifyChanged),
    ),
    Provider<DemoRepository>.value(value: ApiDemoRepository(api)),
    Provider<TestRunRepository>.value(value: ApiTestRunRepository(api)),
    ChangeNotifierProvider<FollowController>(
      create: (c) => FollowController(
        c.read<FollowRepository>(),
        c.read<AuthController>(),
      ),
    ),
    ChangeNotifierProvider<AppConfigController>(
      lazy: false,
      create: (c) => AppConfigController(
        c.read<AppConfigRepository>(),
        c.read<AuthController>(),
      ),
    ),
    ChangeNotifierProvider<NotificationCenter>(
      create: (c) => NotificationCenter(
        c.read<NotificationRepository>(),
        c.read<AuthController>(),
        pollInterval: notificationPoll,
      ),
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
    if (!auth.isSignedIn) {
      final reason = auth.takeSignedOutReason();
      if (reason != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(reason)));
        });
      }
      return const WelcomeScreen();
    }
    return const HomeShell();
  }
}
