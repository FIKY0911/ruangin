import 'package:ruangin/data/models/account.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/core/demo_settings.dart';
import 'package:ruangin/data/fixtures/seed_data.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/repositories/local_repositories.dart';
import 'package:ruangin/domain/session_service.dart';

final today = DateTime(2026, 11, 23, 8, 15);

class TestEnv {
  TestEnv({KeyValueStore? store})
      : store = store ?? InMemoryStore(),
        clock = FixedClock(today),
        demo = DemoSettings(latency: Duration.zero) {
    seed = SeedData.parse(clock.now());
    lecturers = LocalLecturerRepository(seed, demo);
    sessions = LocalSessionRepository(seed, this.store, demo);
    follows = LocalFollowRepository(this.store);
    notifications = LocalNotificationRepository(this.store, demo);
    reports = LocalReportRepository(this.store, demo);
    service = SessionService(
      sessions: sessions,
      follows: follows,
      notifications: notifications,
      reports: reports,
      clock: clock,
    );
  }

  final KeyValueStore store;
  final FixedClock clock;
  final DemoSettings demo;
  late final SeedData seed;
  late final LocalLecturerRepository lecturers;
  late final LocalSessionRepository sessions;
  late final LocalFollowRepository follows;
  late final LocalNotificationRepository notifications;
  late final LocalReportRepository reports;
  late final SessionService service;

  Account account(String id) => seed.accounts.firstWhere((a) => a.id == id);
}
