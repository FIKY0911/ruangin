import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/clock.dart';
import 'core/demo_settings.dart';
import 'data/fixtures/seed_data.dart';
import 'data/local/key_value_store.dart';
import 'data/repositories/local_repositories.dart';
import 'data/repositories/repositories.dart';
import 'domain/session_service.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/notifications/notification_center.dart';
import 'presentation/session/follow_controller.dart';

/// PARKED FOR M2 — not called anywhere in M1.
///
/// Providers for the schedule feature (lecturer search, timeline, session
/// detail/edit, follow, in-app notifications, empty-room reports). M1 ships
/// auth only, so these are intentionally NOT registered in
/// `buildDependencies` (lib/app.dart) and are never instantiated at startup.
/// When M2 wires the schedule screens into navigation, append this list to
/// the app's providers (it must come after the [AuthController] provider).
List<SingleChildWidget> buildScheduleDependencies({
  required KeyValueStore store,
  required Clock clock,
  required DemoSettings demo,
}) {
  final seed = SeedData.parse(clock.now());
  final sessions = LocalSessionRepository(seed, store, demo);
  final follows = LocalFollowRepository(store);
  final notifications = LocalNotificationRepository(store, demo);
  final reports = LocalReportRepository(store, demo);
  return [
    Provider<KeyValueStore>.value(value: store),
    Provider<Clock>.value(value: clock),
    ChangeNotifierProvider<DemoSettings>.value(value: demo),
    Provider<LecturerRepository>.value(value: LocalLecturerRepository(seed, demo)),
    Provider<SessionRepository>.value(value: sessions),
    Provider<FollowRepository>.value(value: follows),
    Provider<NotificationRepository>.value(value: notifications),
    Provider<ReportRepository>.value(value: reports),
    Provider<SessionService>.value(
      value: SessionService(
        sessions: sessions,
        follows: follows,
        notifications: notifications,
        reports: reports,
        clock: clock,
      ),
    ),
    ChangeNotifierProvider<FollowController>(
      create: (c) =>
          FollowController(c.read<FollowRepository>(), c.read<AuthController>()),
    ),
    ChangeNotifierProvider<NotificationCenter>(
      create: (c) => NotificationCenter(
          c.read<NotificationRepository>(), c.read<AuthController>()),
    ),
  ];
}
